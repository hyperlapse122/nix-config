---
title: Configure NixOS network send buffer sysctls - Plan
type: feat
date: 2026-10-26
topic: nixos-wmem-sysctls
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Configure NixOS network send buffer sysctls - Plan

## Goal Capsule

- **Objective:** Every NixOS host boots with a 4 MiB (`4194304`-byte) default and maximum kernel socket send buffer without manual runtime `sysctl` tuning.
- **Means:** Declare `net.core.wmem_default` and `net.core.wmem_max` in `modules/nixos/system/base.nix` and assert the rendered `/etc/sysctl.d/60-nixos.conf` lines in `tests/kernel-sysctl.nix` (KTD1, KTD2).
- **Authority:** Issue #353, then Product Contract R-IDs, then Planning Contract KTD-IDs.
- **Execution profile:** Lightweight; single atomic unit.
- **Stop conditions:** Stop if any NixOS host configuration fails evaluation or experiences a sysctl priority or merge conflict.
- **Finish and ship:** `ce-work` implements and returns to LFG, which simplifies, reviews, opens the pull request, and watches CI.

## Product Contract

### Summary

Declare `net.core.wmem_default = 4194304` and `net.core.wmem_max = 4194304` in `modules/nixos/system/base.nix` for all NixOS hosts.
Extend `tests/kernel-sysctl.nix` so the flake check verifies both lines in the built `/etc/sysctl.d/60-nixos.conf` across every production and bootstrap NixOS configuration.

### Problem Frame

NixOS hosts in this repository currently leave `net.core.wmem_default` unset and `net.core.wmem_max` at nixpkgs's `null` submodule default, omitting both from `/etc/sysctl.d/60-nixos.conf` and falling back to stock kernel send buffer limits at boot.
High-throughput network workloads and manual host tuning otherwise diverge from the declarative system configuration unless both parameters are pinned in the shared NixOS base module.

### Requirements

- R1. Every NixOS configuration yielded by `tests/lib/configurations.nix`, production and bootstrap alike, renders `net.core.wmem_default=4194304` as a whole line in `/etc/sysctl.d/60-nixos.conf`.
- R2. Every NixOS configuration yielded by `tests/lib/configurations.nix`, production and bootstrap alike, renders `net.core.wmem_max=4194304` as a whole line in `/etc/sysctl.d/60-nixos.conf`.
- R3. Existing sysctl entries declared in `modules/nixos/system/base.nix` (`fs.inotify.max_user_watches=524288`, `fs.inotify.max_user_instances=524288`, `net.ipv4.ip_forward=1`, and `net.ipv6.conf.all.forwarding=1`) remain intact in `/etc/sysctl.d/60-nixos.conf`.
- R4. `tests/kernel-sysctl.nix` fails when any NixOS configuration omits or alters any of the expected lines from R1-R3 or omits `/etc/sysctl.d/60-nixos.conf` from its built `/etc` tree.

### Scope Boundaries

- Non-NixOS Linux (`modules/system-manager/`) and macOS (`modules/darwin/`) host layers are out of scope; neither layer manages kernel sysctl files in this repository.
- Receive socket buffer limits (`net.core.rmem_default`, `net.core.rmem_max`) and protocol-specific socket buffer vectors (`net.ipv4.tcp_wmem`, `net.ipv4.udp_wmem_min`) remain untouched.
- Live kernel `sysctl` state on physical hardware is verified separately after a user-run rebuild rather than during automated checks, per `docs/verification.md`.

### Sources

- Issue: <https://github.com/hyperlapse122/nix-config/issues/353>
- Shared NixOS sysctl declarations: `modules/nixos/system/base.nix`
- Existing sysctl repository check: `tests/kernel-sysctl.nix` and `tests/lib/configurations.nix`
- Upstream option schema: nixpkgs `nixos/modules/config/sysctl.nix` (`boot.kernel.sysctl` submodule defining `net.core.wmem_max` as `nullOr highestValueType` and freeform `sysctlOption` for `net.core.wmem_default`)
- Check non-vacuity rule: `.compound-engineering/artifacts/solutions/best-practices/declared-line-identical-to-distribution-default-makes-verbatim-check-vacuous.md`

## Planning Contract

### Key Technical Decisions

- KTD1. **Declare both `wmem` keys as unsigned integer `4194304` at plain priority in `modules/nixos/system/base.nix`.** `modules/nixos/profile.nix` imports `base.nix` into every NixOS production and bootstrap host. In nixpkgs `nixos/modules/config/sysctl.nix`, `net.core.wmem_max` uses `nullOr highestValueType`, which requires an unsigned integer and resolves multiple definitions with `lib.max`, while `net.core.wmem_default` uses the freeform `sysctlOption` type. No other NixOS module in the evaluated host closure defines either key, and Linux's `wmem_default` sysctl handler (`proc_dointvec_minmax` bounded only below by `min_sndbuf`) accepts `net.core.wmem_default=4194304` appearing lexically before `net.core.wmem_max=4194304` in `60-nixos.conf`.
- KTD2. **Extend `expectedLines` in `tests/kernel-sysctl.nix` rather than creating a separate check.** `tests/kernel-sysctl.nix` already sits in `hostClosureChecks` (the `hosts` check shard), iterates `configurations.entries` behind `configurations.guard`, and matches whole lines (`grep -Fxq`) against `${entry.config.system.build.etc}/etc/sysctl.d/60-nixos.conf`. Neither systemd's `50-default.conf` nor nixpkgs `sysctl.nix` ships `net.core.wmem_default` or `net.core.wmem_max` by default, so deleting or altering either declaration in `base.nix` turns `kernel-sysctl` red for its own reason.

### Assumptions

- Restricting the change to NixOS hosts matches the `feat(nixos):` title, the issue's explicit target of `modules/nixos/system/base.nix` and `tests/kernel-sysctl.nix`, and the absence of sysctl management in `modules/system-manager/`.
- Leaving `net.core.rmem_default` and `net.core.rmem_max` unset matches Issue #353's explicit scope of send buffer parameters only.

## Implementation Units

### U1. Declare send buffer sysctls and extend the sysctl repository check

- **Goal:** Render `net.core.wmem_default` and `net.core.wmem_max` at `4194304` across all NixOS configurations and guard both rendered lines in `tests/kernel-sysctl.nix`.
- **Requirements:** R1, R2, R3, R4. KTD1, KTD2.
- **Dependencies:** None.
- **Files:** `modules/nixos/system/base.nix`, `tests/kernel-sysctl.nix`.
- **Approach:**
  1. Add `"net.core.wmem_default"` and `"net.core.wmem_max"` set to integer `4194304` in `boot.kernel.sysctl` inside `modules/nixos/system/base.nix` per KTD1.
  2. Add `"net.core.wmem_default=4194304"` and `"net.core.wmem_max=4194304"` to `expectedLines` in `tests/kernel-sysctl.nix` per KTD2, and update the file's header comment so its summary of verified sysctl groups includes the network send buffer sizes alongside inotify limits and IP forwarding.
- **Patterns to follow:** Existing `boot.kernel.sysctl` attribute set in `modules/nixos/system/base.nix`; `expectedLines` whole-line grep assertions and header comment style in `tests/kernel-sysctl.nix`; scratch-copy mutation discipline in `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`.
- **Test scenarios:**
  - Happy path: every NixOS production and bootstrap configuration yielded by `tests/lib/configurations.nix` renders all six expected lines in `/etc/sysctl.d/60-nixos.conf`, and `kernel-sysctl` succeeds.
  - Error path (deleted declaration): removing `net.core.wmem_default` or `net.core.wmem_max` from `modules/nixos/system/base.nix` fails `kernel-sysctl` inside its builder naming the missing line on every NixOS configuration.
  - Error path (wrong value / prefix-substring): changing `net.core.wmem_default` or `net.core.wmem_max` to a different integer such as `41943040` or `212992` fails the whole-line `grep -Fxq` assertion in `kernel-sysctl` on every NixOS configuration.
- **Verification:** The `kernel-sysctl` check and NixOS host toplevels build cleanly, formatting passes, and mutation rounds in a `.git`-free scratch copy confirm `kernel-sysctl` fails with its own diagnostic when the new `wmem` declarations are removed or altered.

## Verification Contract

| Gate | Command | Purpose |
| --- | --- | --- |
| Sysctl repository check | `nix build --no-link .#checks.x86_64-linux.kernel-sysctl` | Proves `/etc/sysctl.d/60-nixos.conf` renders all six sysctl lines across every NixOS production and bootstrap configuration |
| Flake evaluation | `nix flake check --no-build` | Proves all flake outputs and checks evaluate cleanly |
| Host toplevels | `for host in $(nix eval --raw .#nixosConfigurations --apply 'c: toString (builtins.attrNames c)'); do nix build --no-link ".#nixosConfigurations.$host.config.system.build.toplevel"; done` | Proves every NixOS production and bootstrap system builds with the updated sysctls |
| Formatting and whitespace | `git diff --check && nix fmt -- --ci` | Proves Nix formatting and clean diff hygiene |
| Markdown lint | `mise run lint-staged-markdown` | Proves plan and any changed Markdown files pass `markdownlint-cli2` |

## Definition of Done

- `modules/nixos/system/base.nix` declares `net.core.wmem_default = 4194304` and `net.core.wmem_max = 4194304` under `boot.kernel.sysctl`.
- `tests/kernel-sysctl.nix` asserts both `net.core.wmem_default=4194304` and `net.core.wmem_max=4194304` across all NixOS configurations and documents the added coverage in its header comment.
- Mutation rounds in a `.git`-free scratch copy verify that deleting or altering the new declarations causes `kernel-sysctl` to fail for its own reason, and no scratch or experiment changes remain in the working tree.
- Local verification gates (`kernel-sysctl`, `nix flake check --no-build`, NixOS host builds, `git diff --check`, `nix fmt -- --ci`, and Markdown lint) pass before push, and current-head CI completes cleanly on the pull request.
