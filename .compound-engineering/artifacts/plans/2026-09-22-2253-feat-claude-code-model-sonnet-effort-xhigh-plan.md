---
title: Set Claude Code Defaults to Sonnet and XHigh Effort - Plan
type: feat
date: 2026-09-22
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Set Claude Code Defaults to Sonnet and XHigh Effort - Plan

## Goal Capsule

- **Objective:** Update declared defaults for Claude Code in `home/h82/claude.nix` to use `sonnet` as the primary model with `xhigh` reasoning effort level, update tests in `tests/claude.nix`, and align related documentation and test fixtures.
- **Means:** Update `settingsTier.model = "sonnet"` and `settingsTier.effortLevel = "xhigh"` in `home/h82/claude.nix` (KTD1) and `tests/claude.nix` (KTD2). Keep `test_agent_settings.py` test fixtures divergent to maintain mutation testing integrity (KTD3). Update documentation in `docs/provisioning.md` and `docs/verification.md` (KTD4).
- **Authority:** Issue #72 (`feat(home): set claude code default model to sonnet with xhigh effort`); `AGENTS.md` rules on code style, Conventional Commits, flake check, and all host builds.
- **Stop conditions:** Stop if `xhigh` or `sonnet` is not supported by the schema or settings tier, or if `nix flake check` or host builds fail.
- **Execution profile:** Single-session change, no hardware migration. Proof is `nix flake check`, host builds, and python test suite.
- **Who finishes it:** `ce-work` implements; the pull request ships it.

---

## Product Contract

### Summary

Update the declared defaults for Claude Code in `home/h82/claude.nix` to use `sonnet` as the primary model with `xhigh` reasoning effort level, updating the assertions in `tests/claude.nix`, updating documentation in `docs/provisioning.md` and `docs/verification.md`, and keeping test fixtures in `tests/test_agent_settings.py` divergent.

### Problem Frame

`home/h82/claude.nix` currently declares `model = "opus[1m]"` and `effortLevel = "medium"` in the settings tier that activation merges into `~/.claude/settings.json`. Issue #72 requests changing the primary default model to `sonnet` and the reasoning effort level to `xhigh`. Without updating both the declaration and its asserting checks, builds or checks will fail due to assertion drift, and activation will keep writing `opus[1m]` and `medium`.

### Key Decisions

- **Set `model = "sonnet"` and `effortLevel = "xhigh"` in `settingsTier`**: Specified by issue #72. Governs R1, R2.
- **Update assertions in `tests/claude.nix`**: `tests/claude.nix` diffs the rendered JSON with `declaredExpected`; it must match the updated `settingsTier`. Governs R3.
- **Invert fixture values in `tests/test_agent_settings.py`**: The unit test `test_agent_settings.py` requires `DECLARED` and `EXISTING` to have differing values to verify that `DECLARED` overwrites `EXISTING`. When `DECLARED` uses `sonnet` and `xhigh`, `EXISTING` should be seeded with other values (e.g., `opus[1m]` and `medium` or `haiku` and `low`) so the test remains mutation-sensitive. Governs R4.
- **Update documentation**: `docs/provisioning.md` and `docs/verification.md` mention `opus[1m]` and `medium`; update them to reflect `sonnet` and `xhigh`. Governs R5.

### Requirements

**Declaration**

- R1. `home/h82/claude.nix` declares `model = "sonnet"` in `settingsTier`.
- R2. `home/h82/claude.nix` declares `effortLevel = "xhigh"` in `settingsTier`.

**Checks and Tests**

- R3. `tests/claude.nix` declares `model = "sonnet"` and `effortLevel = "xhigh"` in its `settingsTier` mirror, ensuring rendered declared settings match expectations on both `ThinkPad-X1-Carbon-Gen-11` and `ThinkPad-X1-Carbon-Gen-11-bootstrap`.
- R4. `tests/test_agent_settings.py` updates `DECLARED` and/or `EXISTING` fixtures so that `DECLARED` values differ from `EXISTING` values, preserving the merger overwrite test coverage.

**Documentation**

- R5. `docs/provisioning.md` and `docs/verification.md` are updated to document the `sonnet` model and `xhigh` effort level.

### Scope Boundaries

- Only Claude Code defaults for `model` and `effortLevel` change. Other settings (such as `language`, `theme`, `cleanupPeriodDays`, etc.) and the environment tier remain untouched.
- No hardware installation, disk formatting, or `nixos-rebuild switch` is run.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Update `settingsTier` in `home/h82/claude.nix`**: (session-settled: user-directed — issue #72) Change `model` from `"opus[1m]"` to `"sonnet"`, and `effortLevel` from `"medium"` to `"xhigh"`. Governs R1, R2.
- KTD2. **Update `tests/claude.nix` to assert `sonnet` and `xhigh`**: (session-settled: user-directed — issue #72) Update `settingsTier.model = "sonnet"` and `settingsTier.effortLevel = "xhigh"`. Governs R3.
- KTD3. **Keep `tests/test_agent_settings.py` fixtures divergent**: To prevent decorative testing where `DECLARED` and `EXISTING` have the same values, update `EXISTING['model']` and `EXISTING['effortLevel']` to values other than `sonnet` and `xhigh` (e.g. `haiku` or `opus[1m]`, and `medium` or `low`), while updating `DECLARED['model'] = 'sonnet'` and `DECLARED['effortLevel'] = 'xhigh'`, or keep them clearly divergent. Governs R4.
- KTD4. **Update documentation in `docs/provisioning.md` and `docs/verification.md`**: Ensure accurate developer instructions and manual verification steps reflecting `sonnet` and `xhigh`. Governs R5.

### Assumptions

- `sonnet` and `xhigh` are valid Claude Code settings (as documented in schema and issue #72).
- The `agent-settings` python script performs scalar merge without validating against a fixed enum, so custom or new model/effort values are seamlessly merged into `~/.claude/settings.json`.

### Sequencing

U1 (configuration and tests) then U2 (documentation and fixture updates).

---

## Implementation Units

### U1. Update Claude Code defaults in `home/h82/claude.nix` and `tests/claude.nix`

- **Goal:** Set `model = "sonnet"` and `effortLevel = "xhigh"` in `home/h82/claude.nix` and mirror in `tests/claude.nix`.
- **Requirements:** R1, R2, R3 (per KTD1, KTD2).
- **Files:** `home/h82/claude.nix`, `tests/claude.nix`.
- **Approach:**
  - In `home/h82/claude.nix`, update `settingsTier.model = "sonnet"` and `settingsTier.effortLevel = "xhigh"`.
  - In `tests/claude.nix`, update `settingsTier.model = "sonnet"` and `settingsTier.effortLevel = "xhigh"`.
- **Test scenarios:**
  - Run `nix build --no-link .#checks.x86_64-linux.claude` — passes cleanly.
  - Verify that mutating `home/h82/claude.nix` back to `opus[1m]` causes `nix build --no-link .#checks.x86_64-linux.claude` to fail with declared-settings drift.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.claude`, `nix fmt -- --ci`.

### U2. Align test fixtures and update documentation

- **Goal:** Keep `tests/test_agent_settings.py` fixtures divergent and update `docs/provisioning.md` and `docs/verification.md`.
- **Requirements:** R4, R5 (per KTD3, KTD4).
- **Files:** `tests/test_agent_settings.py`, `docs/provisioning.md`, `docs/verification.md`.
- **Approach:**
  - In `tests/test_agent_settings.py`: Update `DECLARED` to `model: 'sonnet'` and `effortLevel: 'xhigh'`. Update `EXISTING` so `model` and `effortLevel` differ (e.g. `model: 'opus[1m]'`, `effortLevel: 'medium'`). Update assertions in `MergeTests` (e.g. `self.assertEqual(result['model'], 'sonnet')`).
  - In `docs/provisioning.md`: Update section describing `model` and `effortLevel` defaults.
  - In `docs/verification.md`: Update the manual verification checklist item to expect `sonnet` and `xhigh`.
- **Test scenarios:**
  - Run `python3 -m unittest discover -s tests -p "test_*.py"` — all tests pass.
  - Run `nix flake check` — all checks pass.
- **Verification:** `python3 -m unittest discover -s tests -p "test_*.py"`, `nix flake check`.

---

## Verification Contract

| Command | Applies to | Proves |
| --- | --- | --- |
| `nix fmt -- --ci` | U1, U2 | Nix formatting compliance |
| `python3 -m unittest discover -s tests -p "test_*.py"` | U2 | Python test suite passes |
| `nix build --no-link .#checks.x86_64-linux.claude` | U1 | Claude test check passes |
| `nix flake check` | U1, U2 | All flake checks pass |
| `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel` | U1 | ThinkPad production build succeeds |
| `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel` | U1 | ThinkPad bootstrap build succeeds |
| `nix build --no-link .#nixosConfigurations.MS-7D91.config.system.build.toplevel` | U1 | Desktop production build succeeds |
| `nix build --no-link .#nixosConfigurations.MS-7D91-bootstrap.config.system.build.toplevel` | U1 | Desktop bootstrap build succeeds |

---

## Definition of Done

- R1 through R5 hold.
- `nix fmt -- --ci` passes.
- `nix flake check` passes.
- All four host builds succeed (`ThinkPad-X1-Carbon-Gen-11`, `ThinkPad-X1-Carbon-Gen-11-bootstrap`, `MS-7D91`, `MS-7D91-bootstrap`).
- Commits use Conventional Commit format (e.g. `feat(home): set claude code default model to sonnet with xhigh effort`).
