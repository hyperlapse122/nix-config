---
title: Disable OMP TUI Mouse Tracking - Plan
type: feat
date: 2026-10-26
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Disable OMP TUI Mouse Tracking - Plan

## Goal Capsule

- **Objective:** Host terminal mouse selection, scrolling, and gestures pass through unobstructed during OMP CLI sessions instead of being captured by OMP, and that setting persists across Home Manager and NixOS activations on every host kind.
- **Means:** Set `tui.mouse` to `false` inside `my.omp.documents."config.yml"` in `home/h82/agents/omp.nix` and align the OMP settings and NixOS activation checks (KTD1, KTD2).
- **Authority hierarchy:** Product Contract requirements govern behavior; Key Technical Decisions govern mechanism within those requirements; `AGENTS.md` and `docs/verification.md` govern testing and shipping.
- **Stop conditions:** `omp-config-reconcile` rejects the rendered configuration, the pinned `omp` binary does not resolve `tui.mouse` to `false`, or required repository checks fail without an in-scope fix.
- **Execution profile:** Lightweight configuration and repository check update (`code`).
- **Completion and shipping owner:** `ce-work` implements and verifies locally; `lfg` runs simplification, code review, commit and PR creation, and CI readiness tracking.

## Product Contract

### Summary

Set `tui.mouse` to `false` in the common OMP `config.yml` declaration in `home/h82/agents/omp.nix`, and update the OMP settings and NixOS VM activation checks to enforce disabled mouse tracking across NixOS, non-NixOS Linux, and macOS configurations.

### Problem Frame

`home/h82/agents/omp.nix` currently declares `tui.mouse = true` in the managed `~/.omp/agent/config.yml` document. Every Home Manager activation or NixOS system switch restores TUI mouse capture, intercepting host terminal text selection and scroll gestures even after a user disables `tui.mouse` locally at runtime.

### Requirements

- R1. `home/h82/agents/omp.nix` declares `tui.mouse = false` inside `my.omp.documents."config.yml"` while leaving every other declared key in `config.yml`, `models.yml`, and `mcp.json` unchanged.
- R2. Running materialized `ompSettings` activation overwrites drifted `tui.mouse: true` state in `~/.omp/agent/config.yml` with `false`, and `omp config get tui.mouse` resolves to `false` across host fixtures.
- R3. NixOS `switch-to-configuration switch` in `tests/omp-activation.nix` expects and verifies `tui.mouse` as `False` in the restored `~/.omp/agent/config.yml` across unchanged-generation activation.

### Scope Boundaries

- Leave `home/h82/t3code.nix` ACP startup overlays, model catalog snapshots, `scripts/omp-config-reconcile`, named OMP profiles (`~/.omp/profiles/*`), and project overrides (`.omp/config.yml`) untouched.
- Considered and not built: exposing a separate `my.omp.tui.mouse` option, because `home/h82/agents/omp.nix` declares all static OMP UI defaults inline in `my.omp.documents."config.yml"` with uniform behavior across hosts; revisit only if a host trait needs distinct `tui.mouse` values.

## Planning Contract

### Key Technical Decisions

- KTD1. **Set `tui.mouse` explicitly to `false` rather than omitting `mouse`.** Removing `mouse` from `my.omp.documents."config.yml"` leaves `tui.mouse` unset in `~/.omp/agent/config.yml`, which falls back to OMP's built-in `true` default instead of disabling mouse capture. Keeping `tui.mouse = false` in the declared set enforces disabled mouse capture across activations and OMP upgrades.
- KTD2. **Extend existing `omp-settings` and `omp-activation` checks rather than adding a new check derivation.** Extending `Activation.test_materialized_home_steps_restore_and_propagate_failures` in `tests/omp_settings_applied.py` exercises both YAML reconciliation and `omp config get tui.mouse` across NixOS, non-NixOS Linux, and Darwin fixtures in `omp-settings`, while updating `expected["tui"]["mouse"]` in `tests/omp-activation.nix` maintains coverage of the NixOS system activation hook.

### Assumptions

- Every other UI, TUI, theme, display, terminal, memory, startup, and model-role key declared in `home/h82/agents/omp.nix` stays at its current value.
- Project-level `.omp/config.yml` files and explicit `--profile` directories keep their existing runtime precedence over `~/.omp/agent/config.yml`.

## Implementation Units

### U1. Disable `tui.mouse` in common OMP configuration and update checks

- **Goal:** Declare `tui.mouse = false` in `home/h82/agents/omp.nix` and update both OMP check suites to guard the disabled setting.
- **Requirements:** R1, R2, R3
- **Dependencies:** None
- **Files:** `home/h82/agents/omp.nix`, `tests/omp_settings_applied.py`, `tests/omp-activation.nix`
- **Approach:**
  1. Change `mouse = true;` to `mouse = false;` inside `tui` in `home/h82/agents/omp.nix` per KTD1.
  2. Seed `tui: {mouse: true}` in the pre-activation drift fixture of `Activation.test_materialized_home_steps_restore_and_propagate_failures` in `tests/omp_settings_applied.py`, assert `value["tui"]["mouse"]` is `False`, and add `("tui.mouse", "false")` to the `omp config get` verification tuple per KTD2.
  3. Change `"mouse": True` to `"mouse": False` inside `verify()` in `tests/omp-activation.nix` per KTD2.
- **Execution note:** Confirm assertion liveness with two mutation rounds in an isolated scratch copy (`rsync -a --exclude .git` plus `git -C <copy> init -q`, keeping cwd in the main checkout per `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`): one setting `mouse = true;` and one deleting `mouse = false;` in `home/h82/agents/omp.nix`.
- **Patterns to follow:** Boolean declarations in `home/h82/agents/omp.nix`; `self.assertIs(...)` and the `omp config get` tuple in `tests/omp_settings_applied.py`; `expected["tui"]` in `tests/omp-activation.nix`.
- **Test scenarios:**
  - Materialized `ompSettings` activation overwrites `tui: {mouse: true}` in `~/.omp/agent/config.yml` with `tui.mouse: false` on every host fixture, and `omp config get tui.mouse` prints `false`.
  - NixOS `switch-to-configuration switch` in `omp-activation` restores `~/.omp/agent/config.yml` with `tui.mouse` equal to `False` when the Home Manager generation is unchanged while keeping `agent.db` intact.
  - Isolated mutation rounds changing `mouse` back to `true` or removing `mouse` from `home/h82/agents/omp.nix` both fail `omp-settings` inside `tests/omp_settings_applied.py` rather than failing Nix evaluation.
- **Verification:** `omp-settings` and `omp-activation` pass on `x86_64-linux`, and both scratch-copy mutation rounds turn `omp-settings` red for the `tui.mouse` assertions.

## Verification Contract

| Check | Command | Unit | Done signal |
| --- | --- | --- | --- |
| OMP settings & CLI resolution | `nix build --no-link .#checks.x86_64-linux.omp-settings` | U1 | Exits 0; materialized activations restore `tui.mouse: false` and `omp config get tui.mouse` outputs `false` |
| OMP NixOS VM activation | `nix build --no-link .#vmChecks.omp-activation` | U1 | Exits 0; NixOS VM restores `tui.mouse: false` across unchanged-generation switch |
| Check liveness (mutation rounds) | Isolated scratch-copy builds of `path:<copy>#checks.x86_64-linux.omp-settings` with `mouse = true` and `mouse` omitted | U1 | Both builds fail inside `omp_settings_applied.py` on the `tui.mouse` assertion |
| Flake evaluation | `nix flake check --no-build` | U1 | Exits 0 across all declared outputs |
| Formatting, whitespace & Markdown | `git diff --check && nix fmt -- --ci && npx markdownlint-cli2 <changed-md>` | U1 | Exits 0 with no diff, formatting, or Markdown lint errors |

## Definition of Done

- `home/h82/agents/omp.nix` sets `tui.mouse = false` with no unintended changes to other declared OMP keys.
- `tests/omp_settings_applied.py` and `tests/omp-activation.nix` guard `tui.mouse = false`, proven live by isolated `true` and deleted-key mutation rounds.
- Local formatting (`nix fmt -- --ci`), diff hygiene (`git diff --check`), Markdown lint, `nix flake check --no-build`, `omp-settings`, and `omp-activation` pass on `x86_64-linux`, with unavailable Darwin and ARM native builds reported as pending CI evidence per `docs/verification.md`.
- Temporary scratch copies and any experimental dead-end edits are removed before commit.
