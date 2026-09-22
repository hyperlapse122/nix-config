---
title: Claude Code Theme Declaration Matches the Current Setting - Plan
type: chore
date: 2026-09-22
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Claude Code Theme Declaration Matches the Current Setting - Plan

## Goal Capsule

- **Objective:** After the next rebuild, Claude Code on this laptop still starts in the theme the user selected with `/theme`, instead of reverting to a theme they did not choose.
- **Means:** Move the declared `theme` value in the settings tier from `dark-ansi` to `auto` (KTD1).
- **Authority:** The user directed the value; `AGENTS.md` governs style, testing, and commit conventions; `tests/claude.nix` governs how the declaration is asserted.
- **Stop conditions:** Stop if `auto` turns out not to be a value Claude Code persists in `~/.claude/settings.json`, or if a check outside the settings tier depends on the `dark-ansi` value.
- **Execution profile:** Single-session change, no migration, no hardware step. `nix flake check` plus both host builds are the proof.
- **Who finishes it:** `ce-work` implements; the pull request ships it.

---

## Product Contract

### Summary

Change the `theme` value this repository declares for Claude Code from `dark-ansi` to `auto`, in the module that declares it and in the check that asserts it, so the declaration agrees with what the user is actually running.

### Problem Frame

`home/h82/claude.nix` declares `theme = "dark-ansi"` in the tier that an activation merge reasserts into `~/.claude/settings.json`. The user has since selected `auto` with `/theme`, and `~/.claude/settings.json` now holds `"theme": "auto"`. A declared key returns to its declared value whenever the Home Manager generation changes, so the user's choice is temporary: the next rebuild that touches this generation puts `dark-ansi` back. The repository, not the user, currently decides this setting, and it decides it wrongly.

### Key Decisions

- **Declare `auto` rather than retiring the key.** The user asked for the declaration to carry the current value, not for the setting to become theirs permanently. Governs R1, R2.

### Requirements

**Declaration**

- R1. The settings tier in `home/h82/claude.nix` declares `theme = "auto"`.
- R2. `theme` stays a declared key — it is not moved to `retiredKeys` and not dropped from the settings tier.
- R3. The comment beside the declaration describes the value that is actually declared; the existing ANSI-palette rationale does not survive the change unedited.

**Checks**

- R4. `tests/claude.nix` asserts the declared value `auto`, so the rendered declared-settings JSON and the asserted JSON agree.
- R5. `tests/test_agent_settings.py` keeps a declared-theme fixture that differs from the seeded existing value, so the merge round can still distinguish a correct merger from a whole-file writer.

### Scope Boundaries

- Only the `theme` entry changes. Every other declared key, the environment tier, `retiredKeys`, and the merger script stay as they are.
- `README.md` and `docs/provisioning.md` name `theme` as a managed key but not its value, so they need no edit.
- No rebuild of the developer's host is performed as validation.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Declare `theme = "auto"` in the settings tier.** (session-settled: user-directed — chosen over leaving `dark-ansi` declared and letting the user's `/theme` choice revert on the next rebuild: the user asked for the declaration to match what they are running.) Governs R1.
- KTD2. **Keep `theme` in `settingsTier`, not `retiredKeys`.** (session-settled: user-directed — chosen over retiring the key so the setting becomes the user's permanently: the request was to set the declared value, not to stop declaring it.) Governs R2. Retiring the key would also make `remove` carry `theme`, which the merger refuses when the same key is also in `set`.
- KTD3. **Change the declared value in `home/h82/claude.nix` and `tests/claude.nix` in one unit.** `tests/claude.nix` diffs the rendered declared-settings JSON against its own expected copy, so the two files are a single edit, not two independent ones; splitting them would leave a red check between commits.

### Assumptions

- `auto` is a value Claude Code itself writes into `~/.claude/settings.json` — the file currently holds `"theme": "auto"` after the user ran `/theme`, which is the evidence. The merger only assigns scalars and does not validate them against Claude Code's schema, so no additional allow-list needs updating.
- No rebuild is triggered by this plan, so the user's live settings file is not rewritten during implementation. The declared and live values already agree, so the first merge after this change is a no-op on content.

### Sequencing

U1 then U2. U2 is a fixture alignment that is safe either way but reads as stale until U1 lands.

---

## Implementation Units

### U1. Declare `auto` in the settings tier and its check

- **Goal:** The declared value and the check that asserts it both say `auto`.
- **Requirements:** R1, R2, R3, R4 (per KTD1, KTD2, KTD3).
- **Files:** `home/h82/claude.nix`, `tests/claude.nix`.
- **Approach:** In `home/h82/claude.nix`, set `settingsTier.theme = "auto"` and replace the two-line ANSI-palette comment with a short note that `auto` follows the terminal's reported background. Leave `retiredKeys` empty. In `tests/claude.nix`, set the mirrored `settingsTier.theme` to `auto`; nothing else in that file references the value.
- **Test scenarios:**
  - The `claude` check passes with both files at `auto`: the rendered declared JSON matches the expected JSON on both the production and bootstrap hosts.
  - Mutation: changing only `home/h82/claude.nix` to a third value while `tests/claude.nix` says `auto` makes the `claude` check fail with the declared-settings drift message, confirming the assertion still bites.
  - The environment tier, the activation entry's ordering, and the merger invocation are untouched, so the remaining assertions in the `claude` check stay green.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.claude`, then `nix fmt -- --ci`.
- **Execution note:** This is a configuration value change; the check is the proof, and no new test file is warranted.

### U2. Align the merger fixture's declared theme

- **Goal:** The merger's fixture declares the same theme the repository declares, while staying divergent from the seeded existing value.
- **Requirements:** R5.
- **Files:** `tests/test_agent_settings.py`.
- **Approach:** Set `DECLARED['theme']` to `auto`. Leave `EXISTING['theme'] = 'light'` and `EXISTING['themePreference'] = 'keep-me'` alone — the first keeps the fixture divergent, the second is what the prefix-collision test needs.
- **Test scenarios:**
  - `test_declared_keys_reassert_and_undeclared_keys_survive` still passes: the merged file carries `theme = auto` and keeps `themePreference`, `statusLine`, `enabledPlugins`, and `numStartups`.
  - `test_prefix_collision_leaves_the_longer_key_alone` still passes: `themePreference` is untouched by a declared `theme`.
  - The fixture's declared and existing theme values still differ, so a whole-file writer and a correct merger cannot produce identical output.
- **Verification:** `python tests/test_agent_settings.py`.

---

## Verification Contract

| Command | Applies to | Proves |
|---|---|---|
| `nix fmt -- --ci` | U1 | Nix layout unchanged by hand-editing |
| `python tests/test_agent_settings.py` | U2 | Merger behavior under the updated fixture |
| `nix flake check` | U1, U2 | Every declared check, including `claude` and `agent-settings` |
| `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel` | U1 | Production host still evaluates and builds |
| `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel` | U1 | Bootstrap host still evaluates and builds |

No hardware verification step. `nixos-rebuild switch` is not run as validation.

---

## Definition of Done

- R1 through R5 hold.
- `nix flake check` and both host builds pass, and their results are reported in the pull request.
- No file outside `home/h82/claude.nix`, `tests/claude.nix`, and `tests/test_agent_settings.py` is modified.
- No dead-end or experimental edits remain in the diff.
- The commit subject uses a lowercase Conventional Commit prefix consistent with the history.
