---
title: Immutable Mise Config - Plan
type: fix
date: 2026-10-07
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Immutable Mise Config - Plan

## Goal Capsule

- **Objective:** Evaluating or rebuilding any host no longer prints the `programs.mise.enableMutableConfig` rename warning, and h82's global mise configuration is a read-only file Nix owns, so `mise use --global` cannot drift it away from the flake.
- **Means:** Drop the deprecated option so Home Manager's default `mutableSettings = false` renders `mise/config.toml`, and force that link over the empty writable file the previous generation left behind (KTD1, KTD2).
- **Authority:** Product Contract requirements win on behavior; KTDs win on mechanism.
- **Stop conditions:** Stop if the pinned Home Manager's `programs.mise` module no longer defaults `mutableSettings` to `false` or no longer writes `globalConfig` to `mise/config.toml` when it is off.
- **Execution profile:** Configuration change; the proof is the inverted `mise-settings` check, mutation-tested, plus the host builds.
- **Finish and ship:** `ce-work` implements and verifies locally; the calling pipeline ships.

## Product Contract

### Summary

Stop setting `programs.mise.enableMutableConfig`, make `mise/config.toml` the Nix-managed global config, and turn the `mise-settings` check around so it guards the immutable layout.

### Problem Frame

Home Manager renamed `programs.mise.enableMutableConfig` to `programs.mise.mutableSettings`, so every evaluation of the h82 profile now warns. `home/h82/shell/shell.nix` sets the old name to `true`, which renders settings into `mise/conf.d/50-home-manager.toml` and leaves `mise/config.toml` as a writable file for `mise use --global`. The user wants the global config immutable instead. On this host, `~/.config/mise/config.toml` is an empty regular file the previous activation created, and the Home Manager module documents that switching the option off with a non-empty `globalConfig` makes that file a link collision.

### Requirements

- R1. No configuration sets `programs.mise.enableMutableConfig`, and evaluating the h82 Home Manager profile emits no warning about `programs.mise`.
- R2. Home Manager manages `mise/config.toml` as a link to a store file that carries `settings.all_compile = false`, and renders no `mise/conf.d/50-home-manager.toml`, on production and bootstrap configurations alike.
- R3. Activation on a host whose `~/.config/mise/config.toml` is a regular file (the state the previous generation left) replaces it instead of aborting on a collision.
- R4. Packaged mise still reports `all_compile = false`, now sourced from `mise/config.toml`.
- R5. The `mise-settings` check fails when R1, R2, or R4 regresses, including the mutable layout coming back.

### Key Decisions

- KD1. **The global mise config is immutable.** (session-settled: user-directed — chosen over renaming to `mutableSettings = true` and keeping `config.toml` writable: the user asked for an immutable mise config.) Governs R2, R3, R4.
- KD2. **The deprecated option is no longer set.** (session-settled: user-directed — chosen over leaving the old name in place: the user asked to resolve the warning.) Governs R1.

### Scope Boundaries

- `mise use --global` and other global writes now fail against the read-only file; that is the requested behavior, not a regression to work around.
- Project-level `mise.toml` and `.tool-versions` files are untouched.
- `packages/mise.nix` and the pinned release stay as they are.
- Considered and not built: a backup of the existing `config.toml` before forcing over it. On this host the file is empty, and any content a user added with `mise use --global` is exactly the drift the request removes; a host with real hand-edited global tools would change the call.

## Planning Contract

### Key Technical Decisions

- KTD1. **Rely on the module default rather than set `mutableSettings = false`.** (session-settled: user-directed — chosen over keeping the deprecated option: the user asked to resolve the warning.) The pinned module defaults `mutableSettings` to `false`, so deleting the line both removes the warning and selects `mise/config.toml`. Setting `false` explicitly would only restate the default; the check pins the behavior instead. Governs R1, R2.
- KTD2. **Force the `mise/config.toml` link, under the module's own condition.** Set `force = true` on `xdg.configFile."mise/config.toml"` beside `programs.mise`, gated with `lib.mkIf` on `xdg.configFile` itself by the same condition under which the module declares that file (`!mutableSettings && globalConfig != { }`). An unconditional `force` leaves an entry with no `source` whenever the module does not declare the file, and reading it throws at evaluation; a `mkIf` on the inner `force` value still creates the entry and fails the same way. Without the force, Home Manager's link check aborts the whole activation on hosts that ran the previous generation, because the old activation `touch`ed a regular `config.toml` (R3). This follows the `force = true` idiom in `home/h82/desktop/kde/autostart.nix`, which the repo prefers over `home-manager.backupFileExtension`. Governs R3.
- KTD3. **Invert the existing check instead of adding one.** `tests/mise-settings.nix` already proves the setting through the packaged mise. Flip it to require `mise/config.toml` in the materialized `home-files` output, forbid the `conf.d` fragment there, run it over every Home Manager user environment (`userEntries`), install that file at `$XDG_CONFIG_HOME/mise/config.toml`, and expect that path as the setting's source. Add a warnings assertion over the h82 Home Manager `warnings` list so the deprecated name cannot return with either value. Governs R5.

### Assumptions

- The previous generation's `conf.d/50-home-manager.toml` link is removed by Home Manager's normal old-generation cleanup, since the new generation no longer declares it.

## Implementation Units

### U1. Make the mise global config immutable

- **Goal:** Remove the deprecated option and let Home Manager own `mise/config.toml`.
- **Requirements:** R1, R2, R3; KD1, KD2; KTD1, KTD2.
- **Dependencies:** none.
- **Files:** `home/h82/shell/shell.nix`.
- **Approach:**
  1. Delete `enableMutableConfig = true;` and its comment about keeping `config.toml` writable.
  2. Force the `mise/config.toml` link under the module's condition (KTD2), with a short comment that the previous generation left a writable `config.toml` that would otherwise collide.
- **Patterns to follow:** `home/h82/desktop/kde/autostart.nix` (`force = true` with its reason).
- **Test scenarios:** covered by U2.
- **Verification:** evaluating a host's h82 profile prints no `programs.mise` warning; every host builds.

### U2. Turn the mise-settings check around

- **Goal:** Guard the immutable layout and the absent warning (R5).
- **Requirements:** R1, R2, R4, R5; KTD3.
- **Dependencies:** U1.
- **Files:** `tests/mise-settings.nix`.
- **Approach:**
  1. Iterate `configurations.userEntries` behind `configurations.userGuard` instead of `entries`/`guard`, so non-NixOS fixture hosts are covered, as `tests/session-variables.nix` does.
  2. Read the materialized `home-files` output (guarded with `entry.user ? home-files`), not option attributes: require `.config/mise/config.toml` to exist there and `.config/mise/conf.d/50-home-manager.toml` to be absent. Read `force` from the `home.file` entry whose resolved `target` is `.config/mise/config.toml` and require it to be `true`.
  3. Install the materialized `config.toml` at `$XDG_CONFIG_HOME/mise/config.toml` in the sandbox and require `all_compile` to be `false` from that path.
  4. Pass the h82 `warnings` list into the builder and fail when any entry mentions `programs.mise`. Keep `or` fallbacks on every lookup.
  5. Rewrite the header comment to describe the immutable layout.
- **Test scenarios:**
  - Every Home Manager user environment (NixOS and non-NixOS fixture hosts, bootstrap included) materializes `mise/config.toml`, has no `conf.d/50-home-manager.toml`, and forces the link.
  - The packaged mise with that file installed reports `all_compile` as `false`, sourced from `$XDG_CONFIG_HOME/mise/config.toml`.
  - The h82 `warnings` list holds no `programs.mise` entry.
  - `bin/mise` still resolves to the pinned upstream release.
- **Execution note:** Mutation-test the check per the repo's mutation-testing solutions: restoring `enableMutableConfig = true`, setting `enableMutableConfig = false`, setting `mutableSettings = true`, dropping `force`, dropping `all_compile`, and setting `enable = false` on the `mise/config.toml` entry must each make it fail at build time, not at evaluation.
- **Verification:** `mise-settings` passes on the change and fails under each mutation.

## Verification Contract

| Gate | Command |
| --- | --- |
| Format | `nix fmt -- --ci` |
| Flake checks | `nix flake check` |
| Mise check | `nix build --no-link .#checks.x86_64-linux.mise-settings` |
| Host builds | every output under `nixosConfigurations`, `homeConfigurations`, and `systemConfigs`, production and bootstrap, per `AGENTS.md` |

VM checks do not cover this change; build them only if the pipeline's shipping gate requires the full `AGENTS.md` list.

## Definition of Done

- U1 and U2 land; `enableMutableConfig` appears nowhere in `home/`, `modules/`, `lib/`, or `tests/` except as the check's warning pattern.
- `mise-settings` passes and every listed mutation fails it.
- No leftover experimental code in the diff.
