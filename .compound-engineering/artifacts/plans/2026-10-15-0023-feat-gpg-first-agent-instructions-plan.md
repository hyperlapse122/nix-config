---
title: GPG-first agent instructions - Plan
type: feat
date: 2026-10-15
topic: gpg-first-agent-instructions
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

## Goal Capsule

- **Objective:** User `h82` no longer gets asked to run GPG or SOPS commands that a coding agent could run itself, and new encryption setups that agents create use the user's OpenPGP key instead of new age keys.
- **Means:** Add a GPG section to the shared agent instructions template, pin it in the `agent-instructions` check, and replace every documented sudo SOPS route in this repository with one that decrypts the bootstrap identities through GPG (KTD1, KTD2, KTD3, KTD4).
- **Product Authority:** User `h82`. The session-settled decisions in Key Decisions bind; a change to them stops the run.
- **Stop conditions:** Stop when a change would migrate this repository's SOPS files to PGP recipients, relax the rule against exposing decrypted values, or require editing a file outside the ones named in Implementation Units.
- **Execution profile:** Documentation and one Nix check; no host generation changes beyond the rendered instruction files.
- **Finish and ship:** `lfg` implements, reviews, and opens the pull request.

## Product Contract

### Summary

The shared agent instructions gain a GPG section: GPG and the OpenPGP card are always available, agents run GPG and SOPS work themselves without exposing plaintext, and new encryption setups prefer the card key over age. This repository's `AGENTS.md`, `docs/adding-a-host.md`, and `docs/provisioning.md` gain a SOPS route that an agent can run on any host without sudo.

### Problem Frame

The user's GPG key lives on an OpenPGP card (YubiKey) that is always connected, and the `pinentry-card` wrapper caches the card PIN in the desktop keyring (Keychain on macOS). Agents still treat GPG as something only the user can operate, so they stop and ask the user to run SOPS re-encryption and similar work. In this repository every documented re-encryption and edit route also uses `sudo cat /var/lib/sops-nix/key.txt`, which an agent cannot run because it cannot type a sudo password, and which does not exist on non-NixOS or macOS hosts.

### Key Decisions

- **Prefer GPG for new encryption choices.** (session-settled: user-directed — chosen over leaving the choice open or creating new age keys: the user's GPG key is always available and age keys add key material to manage.) Governs R1.
- **Keep age where a project already uses it.** (session-settled: user-approved — chosen over migrating this repository's SOPS files to PGP recipients: hosts decrypt unattended at boot and apply with the age identity, which a card cannot do.) Governs R1, R2.
- **Agents run GPG work themselves.** (session-settled: user-approved — chosen over asking the user to run GPG or SOPS commands: that hand-off is the problem being fixed.) Governs R3, R4.
- **Existing secret-handling rules stay.** (session-settled: user-approved — chosen over relaxing them: the change widens who runs commands, not what may be exposed.) Governs R5.
- **The SOPS route in this repository decrypts bootstrap identities with GPG.** (session-settled: user-approved — chosen over the `sudo cat /var/lib/sops-nix/key.txt` route: agents cannot type a sudo password.) Governs R6, R7.

### Requirements

- R1. The shared instructions tell agents that when a new SOPS setup or new secret file has no existing encryption method, they use the user's OpenPGP card key, fingerprint `621512777E6933FEB4458FDC4945855D4F283F05`, as the user's recipient instead of creating an age key, and also add the machine's own recipient when a machine or service must decrypt the file without the card.
- R2. The shared instructions tell agents to keep the existing method in a project that already encrypts with age or another method.
- R3. The shared instructions state that the GPG key is on an OpenPGP card that is always connected and that its PIN is usually cached, and tell agents to run GPG signing, decryption, and encryption, and work that goes through GPG such as SOPS re-encryption and editing, themselves instead of asking the user to run them.
- R4. The shared instructions tell agents that when a pinentry dialog appears they still run the command and let the dialog reach the user, and that they stop and report only when the PIN is rejected, the prompt times out, or the card is missing.
- R5. The shared instructions tell agents never to print decrypted values, pass them as command arguments, or read decrypted files with file tools: decrypted output goes straight into the command that consumes it.
- R6. The shared instructions tell agents that card administration and key management (card-edit admin commands, PIN changes, key generation, secret-key export, and trust changes) stay with the user.
- R7. `AGENTS.md` documents how an agent re-encrypts or edits a SOPS file in this repository: `SOPS_AGE_KEY_CMD` decrypts every `secrets/bootstrap/*/age-key.asc` with `gpg`, `sops updatekeys -y` re-encrypts, and `sops set --value-stdin` changes one value; `sops edit` and `sops decrypt` to the terminal are not used. Its statement of what the YubiKey is for covers this decryption.
- R8. `docs/adding-a-host.md` and `docs/provisioning.md` show the same GPG route wherever they now use `sudo cat /var/lib/sops-nix/key.txt`, and no longer require a NixOS machine for re-encryption.
- R9. The rendered instruction file of every harness carries the R1 to R6 sentences under one `# GPG and encryption` heading, and the `agent-instructions` check fails when the heading is missing or any sentence is dropped, negated, contradicted by an added sentence in that section, or moved into one harness's branch.

### Scope Boundaries

- This repository's `.sops.yaml` keeps its age recipients; no SOPS file is re-encrypted by this work.
- `secrets/README.md` keeps its recovery pipeline unchanged; it already uses the GPG route.
- The gpg-agent and pinentry configuration in `home/h82/security/gpg.nix` does not change.

### Sources / Research

- `home/h82/agents/instructions/instructions.md.tmpl` and `home/h82/agents/instructions/default.nix`: one gomplate template rendered for Claude Code, Codex, and Antigravity; shared sections sit outside the `.harness.id` branch.
- `tests/agent-instructions.nix`: pins each shared rule as literal sentences matched where a sentence starts (`requireSentences`), and pins a whole section with `onlyPinnedSentences`, which also fails when the heading is missing. Registered in `flake.nix` as `agent-instructions`.
- `secrets/README.md`: each `secrets/bootstrap/<host>/age-key.asc` is that host's age identity encrypted to the encryption subkey of `keys/signing.asc`, so the one card decrypts every host's identity.
- `.sops.yaml`: `secrets/wifi.yaml`, `secrets/tailscale.yaml`, `secrets/printers.yaml`, and `secrets/hosts/MS-7D91/ssh.yaml` list only the MS-7D91 recipient, so no single other host's identity opens every file.
- `sudo cat /var/lib/sops-nix/key.txt` appears in `docs/adding-a-host.md` (the `.sops.yaml` re-encryption block and the `tokens.yaml`-only block, which says to run it on a NixOS machine) and `docs/provisioning.md` (the decommission block and the Tokscale token edit).
- `sops` 3.13.3 in nixpkgs supports `SOPS_AGE_KEY_CMD` and `sops set --value-stdin`, which reads the value from stdin to keep it out of process listings.
- `home/h82/security/gpg.nix` imports the active card key `621512777E6933FEB4458FDC4945855D4F283F05` and the retired key `A7F1956CD1A035A139BC7ABFCC740A29852C0E95` under the same UID; only the first is on the cards.
- `AGENTS.md` `## Security and lifecycle constraints` says "YubiKey use is for initial recovery and Git signing".
- Learnings: `.compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md` and `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`.

## Planning Contract

### Key Technical Decisions

- KTD1. Add a new top-level `# GPG and encryption` section to the shared part of the template, after the `# Tool use` sections and before `# Model routing`, outside the `.harness.id` branch so every harness renders it.
- KTD2. Pin the section in `tests/agent-instructions.nix` with a `gpgSentences` list checked by `requireSentences`, and guard the section with `onlyPinnedSentences` on `# GPG and encryption` with the pattern `.`, so every sentence in it must be pinned. No new check is registered; `agent-instructions` already runs in its shard.
- KTD3. The repository SOPS route decrypts every `secrets/bootstrap/*/age-key.asc` in one `SOPS_AGE_KEY_CMD`, in the form `sh -c 'for f in secrets/bootstrap/*/age-key.asc; do gpg --batch --no-tty --decrypt -- "$f"; done'`, run from the repository root. One card opens every identity, so the union covers every `.sops.yaml` rule on any host, and no host name has to be resolved.
- KTD4. Agents change a value with `sops set --value-stdin <file> '["key"]'`, fed from a pipe or a mode-0600 file, never with `sops edit`, which opens an interactive editor, nor with a value in argv. In `AGENTS.md` the route is a short paragraph in `## Security and lifecycle constraints`, next to the age-identity sentences, with the YubiKey sentence widened; the full command blocks live in the docs.

### Assumptions

- `gpg --batch --no-tty --decrypt` reaches the user's gpg-agent and pinentry from an agent shell, as `scripts/recover-age-identity` already relies on.
- `sops` accepts several age identities from `SOPS_AGE_KEY_CMD` output, one per line, as an age identity file does.

## Implementation Units

### U1. Add the GPG section to the shared instructions template

- **Goal:** Every harness's rendered instructions carry R1 to R6.
- **Requirements:** R1, R2, R3, R4, R5, R6.
- **Dependencies:** none.
- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`.
- **Approach:** Add `# GPG and encryption` per KTD1, in the template's existing register: an opening sentence on the card and cached PIN, then one bullet each for running GPG work directly, the pinentry case, the stop-and-report cases, the exposure rule, the card-administration boundary, the GPG-first choice with the fingerprint and machine recipients, and keeping a project's existing method. Keep each sentence starting a line or following a list marker, so the check can pin it.
- **Test scenarios:** covered by U2.
- **Verification:** the rendered file for each harness contains the section once.

### U2. Pin the GPG section in the agent-instructions check

- **Goal:** R9.
- **Requirements:** R9.
- **Dependencies:** U1.
- **Files:** `tests/agent-instructions.nix`.
- **Approach:** Per KTD2. Add a `gpgSentences` list with the exact U1 sentences, call `requireSentences` with a message such as "lacks the GPG rule:", call `onlyPinnedSentences` for the section, and add a bullet to the header comment that lists what the list guards.
- **Test scenarios:**
  - The check passes on the U1 template.
  - Mutation: deleting one pinned sentence fails the check, naming that sentence.
  - Mutation: prefixing a pinned sentence with "Do not " fails the check.
  - Mutation: appending a contradicting bullet ("Ask the user to run SOPS commands.") to the section fails the check.
  - Mutation: renaming the heading fails the check.
  - Mutation: moving the section inside the Claude Code branch fails the check for Codex and Antigravity.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.agent-instructions` passes, and each mutation, run in a scratch copy per the copied-worktree learning, fails.

### U3. Document the agent-runnable SOPS route

- **Goal:** An agent in this repository can re-encrypt or edit a SOPS file on any host without sudo, without a user hand-off, and without exposing plaintext.
- **Requirements:** R7, R8.
- **Dependencies:** none.
- **Files:** `AGENTS.md`, `docs/adding-a-host.md`, `docs/provisioning.md`.
- **Approach:** Per KTD3 and KTD4. Replace all four `sudo cat` routes: both blocks in `docs/adding-a-host.md` (dropping "on a NixOS machine" from the `tokens.yaml`-only block) and the decommission and Tokscale blocks in `docs/provisioning.md`, where the Tokscale edit becomes `sops set --value-stdin`. Add one sentence where the route is introduced saying a card PIN prompt may appear. In `AGENTS.md`, add the route paragraph and widen "YubiKey use is for initial recovery and Git signing" to include decrypting bootstrap identities for SOPS work.
- **Test scenarios:**
  - Running the KTD3 `SOPS_AGE_KEY_CMD` with `sops decrypt secrets/wifi.yaml > /dev/null` exits 0 on this host, proving that the union opens a file whose rule lists only MS-7D91 and that sops reads several identities; output goes to `/dev/null`, never the terminal.
  - Markdown lint passes on the three files.
- **Verification:** `grep -rn 'sudo cat /var/lib/sops-nix/key.txt' docs AGENTS.md` returns nothing, and the test scenarios pass.

## Verification Contract

- `nix fmt -- --ci`
- `nix build --no-link .#checks.x86_64-linux.agent-instructions`
- `nix flake check`
- Build every `nixosConfigurations` output per `AGENTS.md` "Build and development commands", because the rendered instruction files are part of every Home Manager generation. `homeConfigurations` and `systemConfigs` are empty today, and the `darwinConfigurations` outputs build only in CI's `build-darwin` job.
- U2's mutation runs and U3's decrypt-to-`/dev/null` run.
- `mise run lint-staged-markdown` on the staged Markdown.

## Definition of Done

- U1 to U3 are done and their verification passes.
- Every harness's rendered instruction file carries the GPG section, and the check guards it.
- No documented SOPS route in the repository uses sudo.
- No `.sops.yaml` rule or encrypted file changed.
- No dead-end or experimental edits remain in the diff.
