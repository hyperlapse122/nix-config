---
title: Remove the Retired ThinkPad Recipient from SOPS Files - Plan
type: fix
date: 2026-10-22
topic: retire-thinkpad-sops-recipient
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Remove the Retired ThinkPad Recipient from SOPS Files - Plan

## Goal Capsule

- **Objective:** The secret files at HEAD are no longer encrypted to the retired ThinkPad's age identity, and the repository fails a check if any secret file ever again lists a recipient its `.sops.yaml` rule does not name. The identity still reads the unchanged values through git history until they are rotated at their providers, which this change does not do.
- **Means:** re-key and rotate the data key of the three stale files with `sops`, then add one flake check that compares every encrypted file's recipients with its rule (KTD1, KTD2).
- **Authority:** this plan's Product Contract owns behavior; KTDs own mechanism. Issue #296 is the origin.
- **Execution profile:** one branch, one pull request. The re-key needs the YubiKey; the agent runs it without printing any decrypted value.
- **Stop conditions:** stop and report when the card is missing or its PIN is rejected, or when a new mutant of the check cannot be made to fail with its expected message.

---

## Product Contract

Product Contract preservation: new contract (ce-plan-bootstrap).

### Summary

`secrets/tokens.yaml`, `secrets/wifi.yaml`, and `secrets/tailscale.yaml` are still encrypted to the ThinkPad's recipient `age12wg7w2uex5nc8tdrgynv3an9ywkmd937fmqunk9jldvtd65l9y8s87hmnv`. Re-key each to the recipients `.sops.yaml` names and replace its data key, then add a check that compares the recipients of every encrypted file under `secrets/` with the rule that governs it.

### Problem Frame

Commit `e857618` removed the ThinkPad host and its recipient from `.sops.yaml` but never re-encrypted the files. A copy of the ThinkPad identity, such as a leftover `/var/lib/sops-nix/key.txt` on its old disk, still decrypts these three files, including values added after the host was retired, such as `exa_api_key`. No check noticed: `linux-host-secrets` covers only the recipients of non-NixOS and macOS hosts, and `bootstrap-recipients` checks the opposite direction, that every bootstrap recipient appears in `.sops.yaml`.

### Requirements

- R1. None of `secrets/tokens.yaml`, `secrets/wifi.yaml`, or `secrets/tailscale.yaml` lists the ThinkPad recipient, and each is encrypted to exactly the recipients its `.sops.yaml` rule names.
- R2. Each of the three files has a new data key, so ciphertext produced after this change shares no data key with the history that the ThinkPad identity could read.
- R3. The decrypted values of the three files are unchanged and are never printed, passed as arguments, or written to a file outside SOPS.
- R4. A flake check fails when any `secrets/**/*.yaml` is encrypted to a recipient its `.sops.yaml` rule does not name, or omits one the rule names.
- R5. The check also fails when a `secrets/**/*.yaml` matches no rule, carries no SOPS metadata, lists any key group other than age (`pgp`, `kms`, `gcp_kms`, `azure_kv`, `hc_vault`, `key_groups`), or is governed by a rule written as `key_groups`, and when it finds no encrypted file at all. The walk covers `*.yaml`, `*.yml` and `*.json` files under `secrets/`, skips dot-files, and tolerates spaces after the commas of a rule's age list.
- R6. The decommission procedure in `docs/provisioning.md` names, per host kind, every shared file that can list a retired host, and the secrets documentation names the new check.

### Key Decisions

- **Provider-side rotation is out of this change.** The Wi-Fi PSKs, the Tailscale key, and the tokens in `tokens.yaml` keep their current values; only their ciphertext is re-encrypted. (session-settled: user-directed — chosen over rotating the values at each provider: the user said to skip rotating the values and only re-encrypt.) Governs R2, R3.

### Scope Boundaries

- Re-keying alone does not revoke access to old ciphertext: git history keeps it, and an identity that could read an earlier commit still reads those values. The user accepted this residual by skipping provider rotation. The pull request body records it.
- Not built: re-keying `printers.yaml` or either `ssh.yaml`. They already match their rules.
- Not built: a check that proves each recipient's identity can decrypt. `bootstrap-recipients` and the VM checks already cover who must decrypt.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **The check compares the file against its rule, not the repository against a host list.** For every `secrets/**/*.yaml`, take the recipients stored in the file (`.sops.age[].recipient`) and require them to equal the recipients of the first `.sops.yaml` creation rule whose `path_regex` matches the file's repository-relative path, which is how `sops` picks a rule. This closes the drift in both directions and needs no knowledge of hosts, so it survives hosts being added or removed and passes `host-name-guard`. The lookup takes the first matching rule only, unlike `rule_recipients` in `tests/linux-host-secrets.sh`, which gathers every match. Governs R4, R5.
- KTD2. **Follow the existing split between a shell script and a Nix wrapper.** `tests/linux-host-secrets.sh` plus `tests/linux-host-secrets.nix` already read recipients with `yq`, run over `self`, then over fixture trees built with `age-keygen` and `sops --encrypt` so each rule is proven to fail. The new check mirrors that shape and is registered next to it in `flake.nix`; shard placement is automatic (`tests/check-shards.nix` assigns it to a light shard). Governs R4, R5.
- KTD3. **Re-key with the documented command pair, in order.** `sops updatekeys -y <file>` moves the recipients to the rule's list; `sops rotate -i <file>` then replaces the data key. `sops set` is not involved, so values stay as they are. The key command in `docs/provisioning.md` supplies the identities. Governs R1, R2, R3.
- KTD4. **Test first, then re-key.** The new check run against the unmodified tree is the red baseline; it must name the ThinkPad recipient in all three files. After the re-key it must pass on the real tree. Execution note: this ordering proves the check catches the issue it was written for. Governs R1, R4.

### Risks

- Between U1 and U2 the new check is red on the real tree by design, so the branch is pushed only after U2 and the two share a push; no intermediate state reaches CI.
- A pinentry prompt or a card problem during the re-key stops it halfway. `updatekeys` and `rotate` act on one file at a time and each leaves a valid file, so rerun the failed file's command; do not commit a partly re-keyed tree.
- A mutation that only breaks evaluation proves nothing about a check. Read where each mutant fails and require the check's own message, as the repository learnings on [mutation testing](../solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md) and [evaluation-only mutants](../solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md) require.
- A fixture where file and rule start equal cannot tell a correct check from a broken one; every mutant changes exactly one of them ([converged fixture state](../solutions/best-practices/converged-fixture-state-defeats-nix-check-mutation-testing.md)).

---

## Implementation Units

### U1. Add the `sops-recipients` check

**Goal:** A check that fails on any recipient drift between an encrypted file and its rule.

**Requirements:** R4, R5

**Dependencies:** none

**Files:**

- `tests/sops-recipients.sh` (new)
- `tests/sops-recipients.nix` (new)
- `flake.nix` (register next to `linux-host-secrets`)

**Approach:**

- The script takes the repository root, walks `secrets/` for `*.yaml` at any depth, and for each file compares the sorted recipient set stored in the file with that of the matching rule, reporting every mismatch by file name and recipient before exiting non-zero.
- A file matching no rule, a file without a `sops` block, a file with a non-age key group, and a walk that finds no file each fail with their own message. The rule lookup stops at the first match.
- The Nix wrapper runs the script over `self`, then over fixture trees with fake keys. Each tree encrypts every file to its rule's recipients, except for the single mutation under test.

**Patterns to follow:** `tests/linux-host-secrets.sh` and `tests/linux-host-secrets.nix` (yq reads, `make_tree`, `expect_failure` asserting the failure reason); `tests/lib/directories.nix` is not needed.

**Execution note:** Write the check first and run it on the unmodified tree to see it fail on the three files before U2.

**Test scenarios:**

- A well-formed tree passes, including a nested `secrets/hosts/<name>/ssh.yaml`.
- A file encrypted to its rule's recipients plus one extra recipient fails with a message naming the file and the extra recipient (the issue's case, shown at the top level).
- The same extra recipient in a nested file fails, so the walk is recursive.
- A file missing a recipient its rule names fails.
- A file whose `sops` block gains a `pgp` key group while its age recipients still match fails.
- A tree whose `.sops.yaml` has two overlapping rules, with the file encrypted to the second rule's recipients, fails because the first rule wins.
- A `secrets/*.yaml` that matches no rule fails.
- A `secrets/*.yaml` with no `sops` block fails.
- A tree with no encrypted file fails.
- Covers R4: the real repository, before U2, fails naming the ThinkPad recipient in `secrets/tokens.yaml`, `secrets/wifi.yaml`, and `secrets/tailscale.yaml`.

**Verification:** the check builds green on the re-keyed repository (after U2) and each mutant fails with its expected reason, read from the builder log.

### U2. Re-key and rotate the three files

**Goal:** Remove the ThinkPad recipient and replace the data key without changing any value.

**Requirements:** R1, R2, R3

**Dependencies:** U1 (the red baseline)

**Files:**

- `secrets/tokens.yaml`
- `secrets/wifi.yaml`
- `secrets/tailscale.yaml`

**Approach:**

1. Set `SOPS_AGE_KEY_CMD` from the repository root as `docs/provisioning.md` gives it, decrypting every `secrets/bootstrap/*/age-key.asc` with `gpg --batch --no-tty --decrypt`.
2. For each of the three files, run `sops updatekeys -y`, then `sops rotate -i`.
3. Unset the key command.
4. Read back only the recipient lists, never values, with `yq '.sops.age[].recipient'`.

**Patterns to follow:** the commands and ordering in `docs/provisioning.md`, "Compromise or decommission of a non-NixOS host", steps 2-3 without the value rotation.

**Test scenarios:**

- Test expectation: none beyond U1's check -- this unit changes ciphertext only. Its proof is the check from U1 passing on the real tree and the recipient lists read back equal each file's `.sops.yaml` rule, and none lists `age12wg7w2uex5nc8tdrgynv3an9ywkmd937fmqunk9jldvtd65l9y8s87hmnv`.

**Verification:** decryptability is shown by `updatekeys` and `rotate` exiting 0 for every file, since each decrypts the data key with a bootstrap identity; both exit statuses are recorded per file. The data-key replacement is shown by `git diff`: every encrypted value in each file changed ciphertext, which `updatekeys` alone does not do. The rest of the diff is `sops` metadata. `linux-host-secrets` and `bootstrap-recipients` passing shows only freedom from recipient drift.

### U3. Update the documentation

**Goal:** The decommission procedure and the secrets documentation match what this change establishes.

**Requirements:** R6

**Dependencies:** U1, U2

**Files:**

- `docs/provisioning.md`
- `docs/recovery.md`
- `secrets/README.md`

**Approach:**

- The decommission procedure covers non-NixOS and macOS hosts, which `linux-host-secrets` keeps out of `wifi.yaml` and `tailscale.yaml`, while the retired ThinkPad was a NixOS host. Extend the procedure's scope to a retired NixOS host and key step 2 on host kind: a non-NixOS or macOS host re-keys `secrets/tokens.yaml`; a NixOS host re-keys `secrets/tokens.yaml`, `secrets/wifi.yaml`, and `secrets/tailscale.yaml`, each with `sops updatekeys -y` then `sops rotate -i`.
- For a NixOS host, step 3 and the closing "revokes nothing" paragraph also name the Wi-Fi PSKs and the Tailscale key as values to rotate at their providers. This is guidance for the procedure; this change skips it by the session-settled Key Decision.
- Point the retired-desktop sentence in `docs/recovery.md` at the per-host-kind step.
- Name the `sops-recipients` check in `secrets/README.md` as the guard that fails when a file and its rule disagree, next to the existing description of `bootstrap-recipients` or the decommission link, and bring its `.sops.yaml` example in line with the live file if it has drifted.
- Keep the English-only documentation rule and exact command text.

**Test scenarios:** Test expectation: none -- documentation only; `markdownlint-cli2` runs in the pre-commit hook.

**Verification:** both files lint clean and every command in the edited step matches the one U2 ran.

---

## Verification Contract

| Gate | Command | Applies to |
| --- | --- | --- |
| New check green | `nix build --no-link .#checks.x86_64-linux.sops-recipients` | U1, U2 |
| Neighbouring secret checks | `nix build --no-link .#checks.x86_64-linux.linux-host-secrets .#checks.x86_64-linux.bootstrap-recipients` | U2 |
| Formatting | `nix fmt -- --ci` | U1 |
| Whole flake | `nix flake check` | all |
| Markdown | `mise run lint-staged-markdown` (pre-commit hook) | U3 |
| Recipients read back | `yq '.sops.age[].recipient' secrets/<file>.yaml` for each of the three files; no decrypted value is printed | U2 |

The VM tests and host builds in `AGENTS.md` are not affected: no module or option changes. Hardware verification does not apply.

## Definition of Done

- The new check passes on the repository and fails each of its mutants for the stated reason.
- The three files no longer list the ThinkPad recipient, every encrypted value in them changed ciphertext, and both commands exited 0 for each; no decrypted value appeared in output, arguments, or files outside SOPS.
- `nix flake check` and `nix fmt -- --ci` pass.
- The documentation matches the commands run.
- The pull request body states that provider-side rotation was skipped at the user's direction and that git history still holds the old ciphertext. No scratch fixture or abandoned experiment remains in the diff.
