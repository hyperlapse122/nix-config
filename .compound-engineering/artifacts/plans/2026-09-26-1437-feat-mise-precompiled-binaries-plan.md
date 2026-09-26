---
title: mise precompiled binaries - Plan
type: feat
date: 2026-09-26
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# mise precompiled binaries - Plan

## Goal Capsule

- **Objective:** On both machines, `mise install` of a runtime such as Python or Ruby downloads a prebuilt binary instead of compiling from source, and that choice survives a fresh home directory because the flake declares it.
- **Means:** Declare `all_compile = false` through Home Manager's `programs.mise.globalConfig.settings`, rendered as a `conf.d` fragment beside the mutable `config.toml` (KTD1, KTD2). Guard it with a flake check that asks the packaged `mise` where the setting comes from (KTD3).
- **Authority:** The user's request, then this plan's R-IDs, then KTDs.
- **Execution profile:** Lightweight. Two units.
- **Stop conditions:** Stop if Home Manager would collide with the existing `~/.config/mise/config.toml`, or if any host build fails.

## Product Contract

### Summary

Home Manager writes `all_compile = false` into `~/.config/mise/conf.d/50-home-manager.toml` for `h82` on every host. `~/.config/mise/config.toml` stays a mutable, user-owned file, so `mise use --global` keeps working. A flake check fails when the declared setting disappears or changes.

### Problem Frame

`programs.mise` in `home/h82/shell/shell.nix` enables mise with shell integration but declares no settings. Prebuilt runtime binaries are dynamically linked against a generic FHS loader, which NixOS runs only because `modules/nixos/system/nix-ld.nix` enables nix-ld on both hosts. The setting that tells mise to use those binaries currently lives only in a hand-edited `~/.config/mise/config.toml` on this machine. A new install or a reset home directory loses it, and mise then falls back to its NixOS default of compiling from source.

### Requirements

- R1. On every host configuration, `h82`'s effective mise settings include `all_compile = false`, sourced from a file Home Manager renders.
- R2. `~/.config/mise/config.toml` remains unmanaged and writable, so activation does not collide with the existing hand-edited file and `mise use --global` can still write to it.
- R3. A flake check fails when the declared setting is removed, set to `true`, or no longer rendered to a location mise reads.

### Key Decisions

- **Declare `all_compile = false` in the flake.** (session-settled: user-directed — chosen over leaving mise's default compile behavior undeclared: nix-ld is enabled on both hosts, so prebuilt dynamically linked binaries run.) Governs R1.

### Scope Boundaries

- No per-language settings such as `python.compile` or `ruby.compile`. `all_compile` covers every language.
- No global tool pins in `globalConfig.tools`. Tool versions stay in per-project `mise.toml` files.
- No change to the nix-ld library set in `modules/nixos/system/nix-ld.nix`. A runtime that needs an extra shared library is a follow-up.
- Removing the now-redundant `all_compile = false` line from the hand-edited `~/.config/mise/config.toml` is a manual step on the machine, not part of the build.

### Sources

- Home Manager's `modules/programs/mise.nix` writes `globalConfig` to `mise/config.toml`, or to `mise/conf.d/50-home-manager.toml` when `enableMutableConfig = true`. With that option on, an activation step creates an empty `config.toml` only when none exists. Its option docs warn that disabling it later turns the mutable file into a Home Manager collision.
- mise 2026.8.6 reports each setting with its source file in `mise settings ls`. On this machine it currently lists `all_compile false ~/.config/mise/config.toml`, a hand-edited regular file.
- On NixOS, mise 2026.8.6 sets `all_compile = true` automatically when no config sets it, so an undeclared setting compiles runtimes from source. With no mise config under a throwaway `HOME` on this host, `mise settings get all_compile` prints `true`. The binary's own message says to enable nix-ld to use precompiled binaries. The Nix build sandbox may not look like NixOS to mise, so a check comparing only the value can pass there whether or not the declaration exists; see `.compound-engineering/artifacts/solutions/best-practices/converged-fixture-state-defeats-nix-check-mutation-testing.md`.
- mise reads `~/.config/mise/config.toml` after `conf.d/*.toml`, and a value in `config.toml` wins.

## Planning Contract

### Key Technical Decisions

- KTD1. **Use `programs.mise.globalConfig.settings.all_compile = false` in `home/h82/shell/shell.nix`.** `programs.mise.settings` is a renamed alias of the same option. Writing the canonical path avoids a rename warning. Governs R1.
- KTD2. **Set `programs.mise.enableMutableConfig = true`.** Without it, Home Manager links `~/.config/mise/config.toml`, and activation fails on the existing hand-edited regular file because this flake sets no `home-manager.backupFileExtension`. The `conf.d` fragment also leaves `mise use --global` able to write `config.toml`. Governs R2.
- KTD3. **Check provenance, not the value.** Because the sandbox may not see mise's NixOS default, the check installs the rendered fragment under a sandboxed `HOME` and asserts that the packaged `mise` reports `all_compile` as `false` with the fragment as its source. It also asserts that Home Manager does not manage `mise/config.toml`. Follow `tests/ghq.nix`: every lookup carries an `or` fallback, per `.compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md`. Governs R3.

### Assumptions

- The user edits `~/.config/mise/config.toml` by hand or with `mise use --global`, so keeping it mutable costs nothing.
- A value for `all_compile` in the mutable `config.toml` overrides the declared fragment, and the flake check cannot see that file. R1 holds on a host only while `config.toml` does not set `all_compile`.

## Implementation Units

### U1. Declare the mise setting

- **Goal:** Render `all_compile = false` to the Home Manager `conf.d` fragment.
- **Requirements:** R1, R2. KTD1, KTD2.
- **Dependencies:** none.
- **Files:** `home/h82/shell/shell.nix`.
- **Approach:** Extend the existing `programs.mise` block. Keep a short comment explaining that the setting relies on nix-ld.
- **Test expectation:** covered by U2.

### U2. Add the mise settings flake check

- **Goal:** Fail the build when the declared setting stops reaching mise.
- **Requirements:** R3. KTD3.
- **Dependencies:** U1.
- **Files:** `tests/mise-settings.nix` (new), `flake.nix`.
- **Patterns to follow:** `tests/ghq.nix` for per-host subshells, a failures file, and a sandboxed `HOME`.
- **Test scenarios:**
  - Happy path: on the ThinkPad and MS-7D91 production configurations, `mise settings ls` under a sandboxed `HOME` with the rendered fragment at `$XDG_CONFIG_HOME/mise/conf.d/50-home-manager.toml` reports `all_compile` as `false` from that fragment.
  - Error path: deleting `globalConfig.settings.all_compile` fails the check, because no fragment is rendered.
  - Error path: setting `all_compile = true` fails the check on the value.
  - Error path: setting `enableMutableConfig = false` fails the check, because Home Manager then manages `mise/config.toml` and no fragment exists.
- **Verification:** Each mutation above turns `nix build .#checks.x86_64-linux.mise-settings` red, and the unmodified tree builds green.

## Verification Contract

| Gate | Command |
| --- | --- |
| Formatting | `nix fmt -- --ci` |
| New check | `nix build --no-link .#checks.x86_64-linux.mise-settings` |
| All checks | `nix flake check` |
| Host builds | `nix build --no-link .#nixosConfigurations.<host>.config.system.build.toplevel` for all four hosts |

After a user-run rebuild and removal of the hand-edited `all_compile` line from `~/.config/mise/config.toml`, `mise settings ls` listing `all_compile` from `~/.config/mise/conf.d/50-home-manager.toml` confirms the change on hardware. Report that separately from build evidence.

## Definition of Done

- U1 and U2 are implemented and every gate above passes.
- The mutation scenarios in U2 were each run and observed to fail the check, then reverted.
- No experimental or abandoned code remains in the diff.
