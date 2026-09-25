---
title: Declarative Repository Clones - Plan
type: feat
date: 2026-09-25
topic: declarative-repo-clones
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# Declarative Repository Clones - Plan

## Goal Capsule

- **Objective:** On either host, every repository the developer works on is already cloned at a predictable path under `~/src` after a rebuild, without typing a clone command, and without the repository list being readable in the public nix-config repository.
- **Means:** A system oneshot unit runs a packaged `repo-clones` helper that clones a sops-encrypted list with `ghq` rooted at `~/src` (KTD1, KTD3).
- **Product authority:** The Product Contract owns behavior. The Planning Contract owns the mechanism within it. Scope is cloning only; remote, branch, per-repository Git config, and `mise` setup are not active scope.
- **Execution profile:** Nix module, bash helper, shell test, and NixOS VM test. Four host builds and `nix flake check` prove it. Real private clones on hardware are verified separately.
- **Stop conditions:** Stop and report if a design would require a plaintext repository list in the repository or Nix store, if a failed clone would fail `nixos-rebuild switch`, or if a sync path would modify an existing directory.
- **Open blockers:** None.

---

## Product Contract

### Summary

The developer declares their working repositories as an encrypted list of HTTPS URLs.
A rebuild clones each declared repository that is missing into `~/src/<host>/<owner>/<repo>`.
A manual command runs the same step to retry clones that failed during a rebuild.

### Problem Frame

After a reinstall, `~/프로젝트` is empty and nothing in the flake knows which repositories the developer works on, so each one is cloned again by hand.
The flake already provisions everything else a clone needs: Git credential helpers for GitHub and GitLab backed by sops-decrypted `gh` and `glab` tokens.
The nix-config repository is public, so the list of private and company repositories cannot be written into it in plaintext.

### Key Decisions

- **Clone only; never touch an existing path.** Keeps the step non-destructive and small. Governs R5, R6, R7. (session-settled: user-directed — chosen over also reconciling remotes, per-repository Git config, and running `mise install`: reduced scope to cloning only)
- **The whole list is encrypted.** Every entry may name a private or company repository. Governs R1. (session-settled: user-directed — chosen over a plaintext list or a plaintext/encrypted split: every entry must stay private)
- **Clone paths mirror the URL under `~/src`.** Governs R4. (session-settled: user-directed — chosen over `~/프로젝트` and per-repository custom paths: the user asked for full `host/owner/repo` paths under `~/src`)
- **Rebuild clones automatically, and a manual command retries.** Home Manager activation does not re-run while its generation is unchanged, so a rebuild alone cannot retry a failed clone. Governs R9, R10. (session-settled: user-directed — chosen over warning-only and a login-time retry service)
- **HTTPS only.** Rebuild-time clones are non-interactive, and the 1Password SSH agent is unavailable there, while the `gh`/`glab` credential helpers work without prompts. Governs R2, R11. (session-settled: user-approved — the SSH-agent limitation was shown and the user chose to assume HTTPS only)
- **Use `ghq` instead of a custom clone helper.** With cloning as the only behavior, `ghq get` rooted at `~/src` already produces the required path layout. Governs R4, R5. (session-settled: user-approved — chosen over a custom sync helper and over `garden`: scope shrank to cloning, which `ghq` covers)
- **Both hosts share one list.** Both machines are the developer's workstations; nothing in the dialogue asked for per-host lists. Governs R3.

### Requirements

**Declaration**

- R1. The developer declares repositories in a sops-encrypted list; no entry, name, or URL from it appears in plaintext in the public repository or in any build output that can be evaluated without the decryption key.
- R2. Each entry is an HTTPS clone URL; a non-HTTPS entry is skipped with a warning that identifies the entry, and the remaining entries still sync.
- R3. The ThinkPad X1 Carbon Gen 11 and MS-7D91 hosts use the same list.

**Placement**

- R4. Each repository is cloned to `~/src/<host>/<path>`, where `<host>/<path>` is the URL's host and repository path without the `.git` suffix (for example `~/src/github.com/hyperlapse122/nix-config`), and the clone is owned by user `h82`.

**Sync behavior**

- R5. Sync clones every declared repository whose target path does not exist.
- R6. When the target path already exists, sync leaves it untouched: no fetch, no remote change, no checkout, no config change.
- R7. Removing an entry from the list never deletes or modifies its existing clone.
- R8. A failed clone (network, authentication, unreachable repository) does not stop other entries, does not fail the rebuild, and leaves no partial directory at its target path; sync finishes with a summary naming each failed entry without printing tokens.

**Triggers**

- R9. A rebuild that changes the declared list runs sync, including a rebuild where the list is the only change.
- R10. A manual command runs the same sync on demand; running it repeatedly is safe and clones only what is still missing.

**Authentication**

- R11. Clones authenticate through the existing `gh` and `glab` credentials and never wait for interactive input; missing credentials surface as a failed entry under R8.

### Acceptance Examples

- AE1. **Covers R4, R5.**
  - **Given:** `https://github.com/hyperlapse122/nix-config.git` is declared and `~/src/github.com/hyperlapse122/nix-config` does not exist.
  - **When:** A rebuild that changes the list runs.
  - **Then:** The repository is cloned at that path, owned by `h82`.
- AE2. **Covers R6.**
  - **Given:** A declared repository's target path exists with uncommitted changes, a different remote URL, and a checked-out feature branch.
  - **When:** Sync runs.
  - **Then:** The working tree, remotes, branch, and refs are unchanged.
- AE3. **Covers R8, R10, R11.**
  - **Given:** The host is offline, or the `gh` token has not been published yet.
  - **When:** A rebuild adds a new entry.
  - **Then:** The rebuild succeeds, the summary names the failed entry, and no directory exists at its target path. After the network or token is available, the manual command clones it.
- AE4. **Covers R9.**
  - **Given:** The only change since the previous rebuild is a new entry in the encrypted list.
  - **When:** A rebuild runs.
  - **Then:** The new repository is cloned.
- AE5. **Covers R2.**
  - **Given:** The list contains `git@github.com:owner/repo.git` alongside valid HTTPS entries.
  - **When:** Sync runs.
  - **Then:** The SSH entry is skipped with a warning, and the HTTPS entries are cloned.
- AE6. **Covers R7.**
  - **Given:** A previously cloned repository's entry is removed from the list.
  - **When:** A rebuild runs.
  - **Then:** Its clone under `~/src` remains as it was.

### Scope Boundaries

- Reconciling remotes, upstream/fork remotes, or branch tracking on any clone.
- Per-repository Git config (identity, signing key).
- Running `mise trust` or `mise install`, or any other per-repository bootstrap command.
- Fetching, pulling, or otherwise updating existing clones.
- SSH clone URLs.
- Deleting or archiving clones of repositories removed from the list.
- Moving the existing `~/nix-config` checkout under `~/src`.

### Dependencies / Assumptions

- The `gh` and `glab` credentials published from `secrets/tokens.yaml` are the only credentials clones use; a repository reachable only with other credentials fails under R8.
- On a fresh install, the first successful clone depends on the age identity and published CLI tokens described in `docs/provisioning.md`; before that, clones fail under R8 and the manual command recovers them.

### Sources / Research

- `home/h82/dev/git.nix`: `gh` and `glab` credential helpers for `github.com`, `gist.github.com`, `gitlab.com`, and `git.jpi.app`.
- `home/h82/security/ssh.nix`: SSH uses `IdentityAgent ~/.1password/agent.sock`, which is unavailable to non-interactive rebuild-time work.
- `modules/nixos/system/secrets.nix`: system-level sops wiring for `secrets/tokens.yaml`; `modules/nixos/wifi.nix` and `modules/nixos/services/tailscale.nix` each wire their own sops file, the pattern a repository list would follow.
- `scripts/publish-cli-auth`: publishes `gh` and `glab` configuration as `h82` from `/run/secrets/cli-auth/*`.
- `.compound-engineering/artifacts/solutions/best-practices/home-manager-activation-does-not-run-on-every-rebuild.md`: Home Manager activation re-runs only when the generation changes.
- `ghq` 1.10.1 is available in the pinned nixpkgs; nothing in the repository clones repositories today.
- `.compound-engineering/artifacts/solutions/best-practices/systemd-notify-unit-timeout-still-satisfies-ordering.md`: ordering after a unit does not prove that unit succeeded, so the helper checks its own inputs.

Product Contract preservation: Product Contract unchanged; the Deferred to Planning questions are answered by KTD1 through KTD6 and removed.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **A system oneshot unit without `RemainAfterExit`, wanted by `multi-user.target`, runs the clone step.** `switch-to-configuration` starts every inactive unit wanted by an active target on each switch. The unit therefore runs on every `nixos-rebuild switch` and at boot, which covers R9 whether or not the Home Manager generation changed. This is the pattern `tailscale-advertise-routes` and `sops-install-secrets` already rely on (`modules/nixos/services/tailscale.nix`, `modules/nixos/system/secrets.nix`). Rejected alternatives:
  - A Home Manager activation entry. It does not re-run when only the secret changes.
  - sops-nix `restartUnits`. Under `useSystemdActivation` it uses `try-restart`, which skips an inactive or failed unit. The unit would need `RemainAfterExit=true` and could never be allowed to fail.
  Running on every switch is cheap because existing paths are skipped (R6). Governs R9.
- KTD2. **The unit runs as `User=h82`, orders after the credential and network inputs, and always exits 0 once the helper starts.**
  - `User=h82` gives git a `HOME` where the Home Manager git config and the published `gh`/`glab` configs live.
  - The unit orders `after` and `wants` `network-online.target`, and orders `after` `sops-install-secrets.service` and `home-manager-h82.service`.
  - Ordering does not prove those units succeeded, so the helper checks that the list is readable. A missing list is reported and ends with exit 0.
  - Per-entry failures also end with exit 0. A failed unit would fail the switch.
  Governs R8, R11.
- KTD3. **A bash helper `scripts/repo-clones`, packaged by `packages/repo-clones.nix` with `@GIT@` and `@GHQ@` substituted, owns validation and cleanup, and delegates the clone to `ghq get`.** The helper is the manual command (R10) and the unit's `ExecStart`, so both paths share one behavior. It sets these itself so it does not depend on caller environment:
  - `GHQ_ROOT` to `$HOME/src`.
  - `PATH` with the directory of `@GIT@` prepended. `ghq` runs `git` from `PATH`, and a NixOS service's default `PATH` has no git.
  - `GIT_TERMINAL_PROMPT=0` and an empty `GIT_ASKPASS`, so a host without a credential helper fails instead of hanging.
  - `GIT_ALLOW_PROTOCOL=https`, so git refuses every other transport, including submodule URLs, and never starts `ssh` or the 1Password agent.
  - `GIT_HTTP_LOW_SPEED_LIMIT`/`GIT_HTTP_LOW_SPEED_TIME`, so a stalled transfer fails instead of blocking the switch.
  The helper calls `ghq get --no-recursive`. Cloning stays clone-only, and a submodule the unit cannot fetch does not make the whole repository fail and be removed on every run. Initializing submodules is left to the developer.
  It refuses to run as root. The list path defaults to the sops secret path and can be overridden by an argument for tests. Follows the `nr` packaging pattern (`packages/nix-tools.nix`). Governs R2, R4, R5, R6, R8, R10, R11. (session-settled: user-approved — `ghq` chosen over a custom clone helper and over `garden`: clone-only scope matches `ghq`'s host/path layout)
- KTD4. **The helper validates every entry before calling `ghq`, and removes only a target it saw absent before the attempt.**
  - An entry must match `https://<host>/<path>`. `ghq` also accepts `owner/repo`, `git@`, and `ssh://` forms, so the filter cannot be left to it.
  - An entry with userinfo (`scheme://user:token@host/...`, whatever its scheme) is skipped. Its warning omits the userinfo, because echoing it would print a credential.
  - The helper derives the target path the same way `ghq` does: host plus path, with the `.git` suffix removed. An existing target, including a symlink, is skipped.
  - After a failed `ghq get`, the helper deletes the target only if it recorded the target as absent before the attempt. Whether `ghq` 1.10.1 cleans up by itself is unverified, so the helper does not rely on it.
  - Blank lines and `#` comment lines are ignored.
  Governs R2, R4, R6, R8.
- KTD5. **The list is `secrets/repos.yaml` with one key, `repos`, holding a block-scalar string of one URL per line.** It is exposed as sops secret `repo-clones/list`, with `owner = "h82"` and `mode = "0400"`. sops-nix extracts one string per key, so a YAML sequence would not decrypt to a usable file. The file gets its own `.sops.yaml` creation rule. The module follows the Tailscale shape:
  - a nullable `sopsFile` option with a `pathExists` default;
  - its own age key source;
  - `enable = !config.my.bootstrap` on both hosts.
  A missing file degrades to no unit instead of failing the build. Governs R1, R3.
- KTD6. **Interactive `ghq` uses the same root.** Home Manager adds `pkgs.ghq` and sets git config `ghq.root = "~/src"` in `home/h82/dev/git.nix`. A hand-run `ghq get` then lands where the unit clones. The helper still sets `GHQ_ROOT` itself (KTD3), so a check on the helper cannot pass because of this config. Governs R4.

### High-Level Technical Design

```mermaid
flowchart TB
  A[nixos-rebuild switch or boot] --> B[sops-install-secrets: decrypt repo-clones/list, owner h82]
  B --> C[repo-clones.service, User=h82, oneshot]
  M[manual: repo-clones] --> D
  C --> D[repo-clones helper]
  D --> E{list readable?}
  E -->|no| X[report missing list, exit 0]
  E -->|yes| F[for each line]
  F --> G{https, no userinfo?}
  G -->|no| W[warn, count as skipped]
  G -->|yes| H{target exists?}
  H -->|yes| S[skip untouched]
  H -->|no| I[ghq get]
  I -->|ok| K[cloned]
  I -->|fail| L[remove target created by this attempt, count as failed]
  W & S & K & L --> F
  F -->|done| Z[summary: cloned, skipped, failed entries; exit 0]
```

### Assumptions

- Running the unit on every switch and at boot, not only when the list changes, satisfies R9. It adds only one local existence check per entry.
- Host paths of failed entries may appear in the local journal. R1 limits plaintext exposure to the public repository and build outputs, and the journal is local. Tokens never appear because userinfo entries are not echoed and git credential helpers do not print tokens.
- The first rebuild after the list is added may wait for the initial clones to finish before the switch completes. That is acceptable for a developer workstation.
- The real `secrets/repos.yaml` is created by the developer after merge, following `docs/provisioning.md`. The repository ships without it, and hosts build with no unit until it exists.

### Risks & Dependencies

- `ghq` 1.10.1 URL-to-path mapping must match KTD4's derivation. The VM test asserts the actual clone path, so a mismatch fails the check instead of producing duplicate trees.
- A private repository on a host outside `github.com`, `gist.github.com`, `gitlab.com`, and `git.jpi.app` has no credential helper and fails under R8. That is expected behavior, not a bug.

---

## Implementation Units

### U1. Clone helper and package

**Goal:** A `repo-clones` command that clones missing HTTPS entries from a list file into `$HOME/src`, per KTD3 and KTD4.

**Requirements:** R2, R4, R5, R6, R7, R8, R10, R11.

**Dependencies:** None.

**Files:**
- `scripts/repo-clones` (new)
- `packages/repo-clones.nix` (new)
- `tests/repo-clones.sh` (new)
- `flake.nix` (register the `repo-clones` shell check)

**Approach:**
1. A bash script with `@GIT@` and `@GHQ@` placeholders, following `scripts/nr`.
2. Read the list path from its first argument, defaulting to `/run/secrets/repo-clones/list`.
3. Refuse root. Set the environment named in KTD3.
4. Validate and clone each entry per KTD4.
5. Print one line per failed or skipped entry with its host path only, then a summary count.
6. Exit 0 after processing. A non-zero exit is reserved for invocation errors such as running as root.

**Patterns to follow:** `scripts/nr` and `packages/nix-tools.nix` for substitution, `tests/nr.sh` for rendering placeholders in a shell test, and `flake.nix` `nr` check registration.

**Test scenarios** (the shell test renders `@GHQ@` to a fake `ghq` that clones from local fixtures or fails on demand):
- Covers AE1. A missing HTTPS entry is cloned at `$HOME/src/<host>/<path>` with `.git` stripped.
- Covers AE2. An existing target with an uncommitted file, a different remote, and another branch is unchanged byte-for-byte, and the fake `ghq` is never called for it.
- Covers AE5. An `git@host:owner/repo.git` entry and an `ssh://` entry are skipped with a warning, and the HTTPS entries around them are cloned.
- Entries `https://user:FAKE_TOKEN@host/o/r` and `http://user:FAKE_TOKEN@host/o/r` are skipped, and `FAKE_TOKEN` appears nowhere in stdout or stderr.
- With a `PATH` that has no git, the fake `ghq` still resolves a working `git` from `PATH`, which proves the helper prepends `@GIT@`'s directory.
- The fake `ghq` records its arguments and environment. Every call includes `--no-recursive`, and `GIT_ALLOW_PROTOCOL` is `https`.
- Covers AE3. The entries are ordered good, failing, good. The failing fake `ghq` creates the target directory before exiting non-zero. The target is gone afterwards, both good entries are cloned, the summary names the failed entry, and the exit status is 0.
- A target path that is a symlink is treated as existing and left in place.
- Blank lines and `#` comments are ignored.
- A missing or unreadable list file prints a message and exits 0.
- Running the helper twice clones nothing new on the second run (R10).
- Running as root exits non-zero before touching anything. The uid check reads an overridable value so the sandboxed test can exercise it.

**Verification:** The shell check passes, and each scenario fails when its guarded line is removed from the helper (mutation check per the repository's check-writing learnings).

### U2. NixOS module, secret, and host wiring

**Goal:** Decrypt the list for `h82` and run the helper on every switch and boot, per KTD1, KTD2, and KTD5.

**Requirements:** R1, R3, R8, R9, R11.

**Dependencies:** U1.

**Files:**
- `modules/nixos/services/repo-clones.nix` (new)
- `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`
- `hosts/MS-7D91/default.nix`
- `.sops.yaml` (add the `secrets/repos\.yaml$` rule with both host recipients)

**Approach:**
1. Add options `my.repoClones.enable` and a nullable `my.repoClones.sopsFile` defaulting to `secrets/repos.yaml` when it exists.
2. When enabled, add the `repo-clones` package to `environment.systemPackages` whether or not the list exists, so the manual command is always present.
3. When enabled and the file exists, declare sops secret `repo-clones/list` (`key = "repos"`, `owner = "h82"`, `mode = "0400"`) with the module's own age key source, as in `modules/nixos/services/tailscale.nix`.
4. Declare `systemd.services.repo-clones`: `Type=oneshot`, no `RemainAfterExit`, `User=h82`, `wantedBy = [ "multi-user.target" ]`, with the ordering from KTD2. Its `ExecStart` is the packaged helper with the secret path.
5. Import the module on both hosts and set `my.repoClones.enable = !config.my.bootstrap`.

**Patterns to follow:** `modules/nixos/services/tailscale.nix` for the option shape, sops wiring, and bootstrap gating; `modules/nixos/system/secrets.nix` for user-owned secrets.

**Test scenarios:** Covered by U3's VM test and host assertions.

**Verification:** All four host configurations build. Production hosts carry `repo-clones` in the system path, and bootstrap hosts carry neither the package nor the unit.

### U3. VM and host checks

**Goal:** Prove the unit, secret permissions, and rebuild behavior end to end with fake secrets.

**Requirements:** R1, R3, R5, R6, R8, R9, R11.

**Dependencies:** U1, U2.

**Files:**
- `tests/repo-clones.nix` (new)
- `flake.nix` (register the VM test and a host-assertion check)

**Approach:**
1. Follow `tests/auth-provisioning.nix` and `tests/tailscale-provisioning.nix`. Generate a fake age key and encrypt fixture lists in a `runCommand`.
2. Add a server node that serves bare repositories over HTTPS through `git http-backend` with a test certificate the client trusts. Pin each bare repo's `HEAD` to `refs/heads/main` per `.compound-engineering/artifacts/solutions/best-practices/unset-defaultbranch-leaves-bare-repo-head-dangling-for-second-clone.md`.
3. The client node imports sops-nix and the module and switches between specialisations or rebuilt configurations whose only difference is the encrypted list contents.
4. The host assertion reads the built system path, not option values: production hosts contain `bin/repo-clones`, and bootstrap hosts contain no `repo-clones` unit or package.

**Test scenarios:**
- Covers AE1. After the first switch, `/home/h82/src/<server-host>/<path>` exists and is owned by `h82`.
- Covers AE4. A switch whose only change is a new list entry clones the new repository.
- Covers AE2. A pre-existing target that differs from the remote is unchanged after a switch.
- Covers AE3. With an unreachable entry between two good ones, `switch-to-configuration switch` exits 0, `repo-clones.service` is not in a failed state, no directory remains at the failed target, and both good entries are cloned. After the server is made reachable, running `repo-clones` as `h82` clones the entry.
- Covers AE6. Removing an entry and switching leaves its clone in place.
- A served repository whose `.gitmodules` names an `ssh://` URL still clones through the unit, with its submodule left uninitialized and no `ssh` process started.
- The decrypted list is readable by `h82` through the real path, not only by owner and mode.
- A node with `sopsFile = null` builds, switches, and has no `repo-clones` unit.
- Neither the fixture URLs nor `FAKE_TOKEN` appear in any file of the system closure, checked with `nix-store -qR` as in `tests/wifi-provisioning.nix`.

**Verification:** Both checks pass under `nix flake check`. Each scenario fails when its guarded behavior is removed, for example when `RemainAfterExit=true` is added or the cleanup is disabled.

### U4. Interactive ghq root

**Goal:** A hand-run `ghq get` uses `~/src`, per KTD6.

**Requirements:** R4.

**Dependencies:** None.

**Files:**
- `home/h82/dev/git.nix`
- `tests/git-trim.nix` or a new small check registered in `flake.nix`, asserting the rendered git config

**Approach:** Add `pkgs.ghq` to `home.packages` and `ghq.root = "~/src"` to `programs.git.settings`.

**Test scenarios:**
- The rendered `git/config` for `h82` on both production hosts sets `ghq.root` to `~/src`, read from the materialized file.

**Verification:** The assertion fails when the setting is removed.

### U5. Documentation

**Goal:** The developer can create the list, understand when clones run, and retry by hand.

**Requirements:** R1, R8, R10.

**Dependencies:** U2.

**Files:**
- `secrets/README.md`: `repos.yaml` rule and schema, and the missing `tailscale.yaml` mention next to it.
- `docs/provisioning.md`: create `secrets/repos.yaml` from a private temporary directory, what the rebuild does, the `repo-clones` retry command, and that removal never deletes.
- `docs/verification.md`: the new repository checks, plus a hardware item for the first real private clone on each host, kept separate from VM evidence.
- `AGENTS.md`: mention the repo-clones service in the `modules/nixos/` structure line.

**Approach:** Follow the existing sections' voice and command formatting.

**Test expectation:** none -- documentation only.

**Verification:** Markdown lint in CI passes, and every command named in the docs exists in the built system.

---

## Verification Contract

| Gate | Command | Proves |
|---|---|---|
| Format | `nix fmt -- --ci` | Nix formatting |
| Checks | `nix flake check` | U1 shell test, U3 VM and host checks, U4 config assertion, and existing checks |
| ThinkPad build | `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel` | Production host evaluates with the module |
| ThinkPad bootstrap | `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel` | Bootstrap stays unaffected |
| Desktop build | `nix build --no-link .#nixosConfigurations.MS-7D91.config.system.build.toplevel` | Production host evaluates with the module |
| Desktop bootstrap | `nix build --no-link .#nixosConfigurations.MS-7D91-bootstrap.config.system.build.toplevel` | Bootstrap stays unaffected |

VM checks need `/dev/kvm`. Do not run `nixos-rebuild switch` on the developer's host as validation. Hardware verification of real private clones is reported separately per `docs/verification.md`.

---

## Definition of Done

- U1 through U5 are implemented, and every Verification Contract gate passes.
- Each new check assertion was mutation-tested: removing the behavior it guards turns the check red.
- No plaintext repository URL or token fixture is present in the repository or the built closure beyond the test fixtures' fake values.
- `secrets/repos.yaml` is not committed with real content; the docs explain how to create it.
- No abandoned experimental code, debug output, or unused helpers remain in the diff.
