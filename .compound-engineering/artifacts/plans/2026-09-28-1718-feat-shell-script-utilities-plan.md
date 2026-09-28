---
title: Shell Script Utilities - Plan
type: feat
date: 2026-09-28
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Shell Script Utilities - Plan

## Goal Capsule

- **Objective:** On every host, user `h82` can run common shell-scripting utilities such as `jq`, `yq`, `rg`, and `fd` from a login shell without a `nix shell` detour, and the flake fails if any of them leaves the user profile.
- **Means:** A focused Home Manager module `home/h82/shell/utilities.nix` adds the packages (KTD1, KTD2), guarded by a flake check that runs each binary from `home.path` (KTD3).
- **Authority:** This plan, then `AGENTS.md`, then existing `tests/ghq.nix` and `flake.nix` check conventions.
- **Stop conditions:** Stop if a package fails to evaluate or build on any `nixosConfigurations` output, or if two packages collide in `home.path`.
- **Execution profile:** Configuration plus one flake check. No hardware installation and no `nixos-rebuild switch`.
- **Finishes the work:** `ce-work` implements and verifies with the fast Nix commands and the builds of every `nixosConfigurations` output.

## Product Contract

### Summary

Install a curated set of command-line utilities for shell scripting through Home Manager for `h82`, and guard the set with a flake check.

### Problem Frame

Scripts and one-off pipelines on these machines routinely need JSON/YAML processing, fast search, and archive handling. The system profile carries only the NixOS base set (`curl`, `rsync`, `gawk`, `gnused`, `less`, `xz`, `zstd`), and the user profile carries none of `jq`, `yq`, `ripgrep`, `fd`, `fzf`, `bat`, `tree`, `file`, `zip`, `unzip`, `wget`, `shellcheck`, `shfmt`, or `moreutils`. Each use today costs a `nix shell` invocation, and agents running in these sessions hit the same gap.

### Requirements

- R1. `jq` is in the `h82` user profile on every `nixosConfigurations` output, bootstrap included.
- R2. The same profile carries these utilities, by executable: `yq` (yq-go), `rg`, `fd`, `fzf`, `bat`, `tree`, `file`, `zip`, `unzip`, `wget`, `shellcheck`, `shfmt`, and `sponge` (moreutils).
- R3. A flake check fails, with a message naming the tool and configuration, when any R1/R2 executable is missing from `home.path` or does not run.

### Scope Boundaries

- Shell integrations (fzf key bindings, `bat` as `MANPAGER`, `ls`/`cat` aliases) are excluded; the utilities are installed as plain commands so existing zsh/prezto behavior is unchanged.
- Tools already in the system profile (`curl`, `rsync`, `gawk`, `gnused`, `less`, `xz`, `zstd`, `strace`) are not duplicated.
- Interactive monitors (`htop`, `btop`) and `eza` are excluded as not script-oriented.
- Moving system packages from `modules/nixos/system/base.nix` into Home Manager is excluded.

## Planning Contract

### Key Technical Decisions

- KTD1. Put the packages in a new module `home/h82/shell/utilities.nix`, imported from `home/h82/shell/default.nix`, rather than extending the mixed list in `home/h82/default.nix`. This matches the one-concern-per-module rule in `AGENTS.md` and the recent `home/h82/dev/*.nix` toolchain modules. Home Manager rather than `environment.systemPackages` follows the request, which named `home/h82/`.
- KTD2. Use nixpkgs `yq-go` for `yq`: it is the actively maintained Go implementation that handles YAML, JSON, and TOML with a jq-like syntax. The Python `yq` wrapper is rejected because it drags a second jq-shaped CLI and a Python closure into the profile.
- KTD3. Guard with `tests/shell-utilities.nix`, modeled on `tests/ghq.nix`: iterate `tests/lib/configurations.nix` entries (so bootstrap outputs are covered and no host is named), read `entry.user.home.path or ""` so a removal fails in the builder rather than at evaluation, and keep the expected executable list in the test, not imported from the module, so deleting a package from the module is caught. Each tool gets a behavioral smoke rather than an existence test alone, because an existence check passes for a wrapper that cannot run (see `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`).

### Assumptions

- The utility set in R2 is an agent-chosen default for "commonly-used shell script utilities"; the user can add or remove entries after review.
- `moreutils` ships `parallel`, which would collide with GNU `parallel`; neither `parallel` package is in the profile today, so no collision exists.
- Duplicates between `home.packages` and system packages resolve to the same store path under `home-manager.useGlobalPkgs = true`, so none are expected to collide; `ce-work` confirms by building every output.

## Implementation Units

### U1. Add the utilities module

- **Goal:** R1, R2.
- **Requirements:** KTD1, KTD2.
- **Files:** `home/h82/shell/utilities.nix` (new), `home/h82/shell/default.nix`.
- **Approach:** A `{ pkgs, ... }` module setting `home.packages = with pkgs; [ ... ]` alphabetized: `bat`, `fd`, `file`, `fzf`, `jq`, `moreutils`, `ripgrep`, `shellcheck`, `shfmt`, `tree`, `unzip`, `wget`, `yq-go`, `zip`. Add `./utilities.nix` to the `imports` list in `home/h82/shell/default.nix`.
- **Test Scenarios:** Covered by U2.
- **Verification:** Every `nixosConfigurations` output builds.

### U2. Add the `shell-utilities` flake check

- **Goal:** R3.
- **Requirements:** KTD3.
- **Files:** `tests/shell-utilities.nix` (new), `flake.nix` (register `shell-utilities` beside `ghq` and `git-trim`).
- **Approach:** Per configuration entry, in a subshell that appends failures to a file (the `tests/ghq.nix` shape, with `configurations.guard` first), assert `$homePath/bin/<exe>` is executable and run a smoke that exercises the tool:
  - `jq`: `echo '{"a":1}' | jq .a` prints `1`.
  - `yq`: `echo 'a: 1' | yq .a` prints `1`.
  - `rg`: finds a known line in a temp file; `fd`: finds a known temp file by name.
  - `fzf --filter`, `bat --plain`, `tree`, `file`, `zip`+`unzip` round-trip, `shellcheck` on a clean script, `shfmt -d` on a formatted script, `sponge` writing stdin to a file.
  - `wget --version` exits zero (no network in the builder).
  Every tool name and configuration name appears in its failure message.
- **Test Scenarios:**
  - All packages present: the check builds.
  - One package removed from `home/h82/shell/utilities.nix` (e.g. `jq`): the check fails in the builder with `<config>: jq is not in home.path` for every configuration, not with an evaluation error.
  - Module import removed from `home/h82/shell/default.nix`: every tool fails for every configuration.
  - `jq` swapped in `home/h82/shell/utilities.nix` for a stub that exists and runs but prints nothing (`pkgs.writeShellScriptBin "jq" "exit 0"`): the check fails with the jq smoke message (e.g. `<config>: jq .a printed '', expected '1'`), not `jq is not in home.path`, proving the smoke catches a binary that exists but does not work.
- **Verification:** `nix build .#checks.x86_64-linux.shell-utilities`, plus the mutations above run in a scratch copy per `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`, then reverted.

## Verification Contract

- `nix fmt -- --ci`
- `nix flake check`
- Build every `nixosConfigurations` output, production and bootstrap, with the loop in `AGENTS.md`.
- Mutation evidence for U2 per `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`.

## Definition of Done

- `home/h82/shell/utilities.nix` exists and is imported, and `shell-utilities` is registered in `flake.nix`.
- All Verification Contract commands pass.
- The check was shown to fail for a removed package, a removed import, and a stubbed `jq` that exists but does not work; the mutations are reverted.
- No leftover experimental edits in the diff.
