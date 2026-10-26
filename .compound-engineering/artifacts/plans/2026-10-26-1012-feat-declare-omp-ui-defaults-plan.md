---
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Unified Plan: Declare Current OMP UI/TUI/Theme Settings as Nix Defaults

## Goal Capsule

- **Objective**: Ensure that the user's active OMP agent UI, TUI, and theme settings configured in `~/.omp/agent/config.yml` are declared as the default baseline in Nix configuration (`home/h82/agents/omp.nix`), so rebuilds and new activations consistently preserve and establish this user interface configuration across managed environments.
- **Means**: Update the default `config.yml` attrset rendered in `home/h82/agents/omp.nix` to include the specific UI, TUI, and display keys from `~/.omp/agent/config.yml`. (KTD1)
- **Authority Hierarchy**: The user's explicit scope selection in this session (`config.yml` UI/TUI/theme settings only; `memory.backend` and `autolearn.enabled` remain disabled) overrides unprompted wider changes to models or providers.
- **Stop Conditions**: Stop if the reconciler tests (`tests/omp-settings.nix`) fail, if `nix flake check` reports errors, or if `omp-config-reconcile` refuses the declared schema.
- **Execution Profile**: Standard code modification and verification.
- **Ship Target**: Pushed branch with open PR and CI green.

## Product Contract

### Summary

The user has established an active set of TUI, UI, and theme preferences in OMP (`~/.omp/agent/config.yml`). Currently, `home/h82/agents/omp.nix` provides a minimal default `config.yml` that only declares system/model roles, skills, and memory/startup flags, leaving TUI/theme preferences to be populated solely at runtime. This plan adds those preferences to Nix declarative defaults so that any new or reconciled setup has these settings by default.

### Problem Frame

When initializing new hosts, activating a fresh user generation, or running in an environment where `~/.omp/agent/config.yml` is populated from declared defaults, the UI appearance (Nerd Font symbol preset, band-shaped composer, titanium dark theme, kittens shimmer, scrollback settings, etc.) reverts to OMP's out-of-the-box defaults rather than the user's preferred environment setup.

### Key Decisions

- **Scope confined to config.yml UI/TUI/theme settings** (session-settled: user-directed — chosen over wider OMP re-architecture: only config.yml UI/TUI/theme keys are added to defaults). Governs R1.
- **Keep memory.backend off and autolearn.enabled false** (session-settled: user-approved — user confirmed memory must remain disabled). Governs R2.

### Requirements

- **R1**: `home/h82/agents/omp.nix` MUST include the following default properties in `my.omp.documents."config.yml"`:
  - `symbolPreset = "nerd"`
  - `composer.shape = "band"`
  - `theme.dark = "titanium"`
  - `theme.light = "light"`
  - `setupVersion = 2`
  - `tui.resizeScrollback = "rebuild"`
  - `tui.completeScrollback = true`
  - `tui.textSizing = true`
  - `tui.codexResetFireworks = true`
  - `tui.mouse = true`
  - `tui.imeSafeCursor = true`
  - `terminal.showProgress = true`
  - `display.subagentLivePreview = true`
  - `display.shimmer = "kitt"`
  - `display.showTokenUsage = true`
  - `display.showTurnTime = true`
- **R2**: `memory.backend = "off"` and `autolearn.enabled = false` MUST remain explicitly declared in `home/h82/agents/omp.nix`.
- **R3**: Reconciler tests and Nix flake checks MUST continue to pass without regression.

## Planning Contract

### Key Technical Decisions

- **KTD1**: Declare fields directly inside `my.omp.documents."config.yml"` in `home/h82/agents/omp.nix`.
  - *Rationale*: Nix's `builtins.toJSON` serializes attrset keys directly into JSON, which `omp-config-reconcile` loads and reconciles with `config.yml`.
  - *Alternative rejected*: Creating separate Nix options under `my.omp.*` for each UI field. That would add unnecessary indirection and boilerplate for settings that are purely static defaults.

### Technical Design

`home/h82/agents/omp.nix` lines 43-59 currently build a JSON string via `builtins.toJSON` with:

```nix
memory.backend = "off";
autolearn.enabled = false;
disabledProviders = [ "omp-managed" ];
startup.checkUpdate = false;
marketplace.autoUpdate = "off";
modelRoles.default = "openai-codex/gpt-6-astra";
defaultThinkingLevel = "low";
modelRoles.web = "web/synthetic";
skills.customDirectories = config.my.omp.skillDirectories;
contextFiles.extra = [ "OMP.md" ];
task.structured = true;
```

We extend this attrset with the exact structure from `~/.omp/agent/config.yml`.

## Implementation Units

### U1: Update default config.yml in home/h82/agents/omp.nix

- **Goal**: Add UI, TUI, terminal, display, and theme default properties to `home/h82/agents/omp.nix`.
- **Requirements**: R1, R2.
- **Files**: `home/h82/agents/omp.nix`
- **Approach**: Edit `home/h82/agents/omp.nix` to include `symbolPreset`, `composer`, `theme`, `setupVersion`, `tui`, `terminal`, and `display`.
- **Verification**: Run `nix eval .#homeConfigurations --apply builtins.attrNames` (or relevant checks) and `nix flake check`.

### U2: Validate reconciliation and existing tests

- **Goal**: Verify that existing test suites (`tests/omp-settings.nix` and `tests/omp_settings_applied.py`) pass and that `omp-config-reconcile` processes the new declaration cleanly.
- **Requirements**: R3.
- **Files**: `tests/omp-settings.nix` (if any adjustments needed, though none expected)
- **Verification**: Run `nix build --no-link .#checks.x86_64-linux.omp-settings`.

## Verification Contract

- `nix build --no-link .#checks.x86_64-linux.omp-settings`: verifies that `omp-config-reconcile` and activations succeed.
- `nix flake check`: runs all configured flake checks.
- `nix fmt -- --ci`: formatting verification.

## Definition of Done

- [ ] `home/h82/agents/omp.nix` declares all specified UI/TUI/theme properties.
- [ ] `memory.backend` and `autolearn.enabled` remain disabled.
- [ ] Formatting is clean (`nix fmt -- --ci`).
- [ ] All relevant flake checks pass.
- [ ] Changes are committed and pushed via the standard PR flow.
