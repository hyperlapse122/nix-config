---
title: Claude Code Full Context Window - Plan
type: feat
date: 2026-10-19
topic: claude-full-context-window
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Claude Code Full Context Window - Plan

## Goal Capsule

- **Objective:** Claude Code sessions on every host, T3 Code sessions included, use the model's full context window again instead of the reduced 400K window, so auto-compaction starts near the 1M limit rather than at about 367K.
- **Means:** Stop declaring `autoCompactWindow` and retire it through `retiredKeys`, so activation removes the stored value from `~/.claude/settings.json` (KTD1).
- **Product authority:** The user, in this request. Other Claude Code settings are not active scope.
- **Stop conditions:** Stop and report if evidence shows that removing the key does not restore the full window, or that retiring it would discard a per-model `/autocompact` choice.
- **Execution profile:** Repository checks and built outputs verify the work. Applying the new generation to a host is the user's explicit action, never a validation step.
- **Who ships:** `ce-work` implements; the PR carries the change; the user applies it per host and can confirm with `/context`.

## Product Contract

### Summary

The `autoCompactWindow = 400000` declaration that commit `e659e35` added comes out of the Claude Code settings tier. The key moves to `retiredKeys`, so the next rebuild that produces a new Home Manager generation deletes it from the settings file and Claude Code falls back to the model's full window.

### Problem Frame

`home/h82/agents/claude.nix` declares `autoCompactWindow = 400000`. Claude Code then measures every session, terminal and T3 Code alike, against a 400K window and compacts at about 367K tokens (the window minus the 33K autocompact buffer), although the declared model is `opus[1m]`. The user wants the reduced size gone. The merge only assigns, so deleting the declaration alone would leave `400000` in every host's `~/.claude/settings.json` permanently.

### Requirements

- R1. The repository no longer declares `autoCompactWindow`; after activation, `~/.claude/settings.json` on every host carries no top-level `autoCompactWindow` key.
- R2. The removal is enforced by activation through the existing retirement path, not by a manual edit.
- R3. A window the user saves with `/autocompact`, stored per model under `modelSettings`, survives the rebuild.
- R4. The `claude` check and `docs/provisioning.md` describe the retired key, not a declared 400K window.

### Acceptance Examples

- AE1. **Covers R1, R2.** Given a settings file holding `autoCompactWindow: 400000` and no per-model window saved for the active model, when activation runs the merge, the key is gone and `/context` reports the full window (`/ 1m` on a 1M model).
- AE2. **Covers R3.** Given `modelSettings.<model>.autoCompactWindow` set by `/autocompact`, after the merge that entry is unchanged.

### Scope Boundaries

- `model` stays `opus[1m]`; no other settings-tier key changes.
- No `CLAUDE_CODE_AUTO_COMPACT_WINDOW` or other environment variable is added.
- `modelSettings` stays the user's; the merge never touches it.
- The `retiredKeys` entry follows the documented procedure: it stays until every host has rebuilt past it, then is dropped, after which a top-level window is the user's again.

### Sources / Research

- `home/h82/agents/claude.nix`: `settingsTier.autoCompactWindow` and `retiredKeys = [ "advisorModel" ]`.
- `tests/claude.nix`: literal `settingsTier` and `retiredKeys` it compares against the rendered declaration.
- `docs/provisioning.md`, "Which tier owns which setting": lists `autoCompactWindow` as declared and describes the retirement procedure.
- `.compound-engineering/artifacts/solutions/integration-issues/claude-code-global-config-keys-ignored-in-settings-json.md`: measured on Claude Code 2.1.296 that a settings file without the key shows `16.2k / 1m` in `/context`, and that a per-model `modelSettings` value outranks the top-level key.

## Planning Contract

### Key Technical Decisions

- KTD1. **Retire through `retiredKeys`, not delete.** The merge only assigns, so a deleted declaration would leave the last written value on every host; `retiredKeys` feeds the merge's `remove` list, which deletes the top-level key and leaves `modelSettings` alone. This is the documented procedure in `docs/provisioning.md`. Governs R1, R2, R3.

### Assumptions

- No host relies on a hand-set top-level `autoCompactWindow`; retirement removes any top-level value, declared or not, until the entry is dropped. A different window stays available per model through `/autocompact` (R3).

## Implementation Units

### U1. Retire `autoCompactWindow`

- **Goal:** The declaration renders without `autoCompactWindow` in `set` and with it in `remove`.
- **Requirements:** R1, R2, R3 (per KTD1); AE1, AE2.
- **Dependencies:** None.
- **Files:** `home/h82/agents/claude.nix`, `tests/claude.nix`
- **Approach:**
  - Delete `autoCompactWindow` and its comment from `settingsTier`; add it to `retiredKeys` beside `advisorModel`.
  - Mirror both changes in the check's literal `settingsTier` and `retiredKeys`, so the check fails if the module still sets the key or stops removing it.
- **Patterns to follow:** the `advisorModel` retirement already in both files.
- **Test scenarios:**
  - Covers the rendered half of AE1 (the `/context` half is the post-apply check). The rendered `claude-declared-settings.json` has no `autoCompactWindow` under `set` and lists it under `remove`, on every user configuration.
  - Mutation: putting the key back in `settingsTier`, or dropping it from `retiredKeys`, fails the `claude` check.
  - Covers AE2. `agent-settings`' existing suite already proves `remove` deletes only top-level keys, so a `modelSettings` entry survives; no new test is needed.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.claude` green.

### U2. Align the documentation

- **Goal:** `docs/provisioning.md` no longer lists `autoCompactWindow` as declared and records its retirement.
- **Requirements:** R4.
- **Dependencies:** None.
- **Files:** `docs/provisioning.md`, `.compound-engineering/artifacts/solutions/integration-issues/claude-code-global-config-keys-ignored-in-settings-json.md`
- **Approach:** In `docs/provisioning.md`, drop `autoCompactWindow` from the settings-file key list and its 400000 sentence; add it beside the `advisorModel` retirement note, saying Claude Code returns to the model's full window and a per-model `/autocompact` choice still holds. Refresh the learning with `ce-compound-refresh`: it says declaring the top-level key keeps an `/autocompact` choice, which no longer describes this repository; keep its measurements.
- **Test expectation:** none -- documentation only.

## Verification Contract

- `nix flake check`.
- `nix build --no-link .#checks.x86_64-linux.claude`.
- Build every `nixosConfigurations`, `homeConfigurations`, and `systemConfigs` output the repository lists; macOS outputs are left to CI's `build-darwin` job.
- Post-apply, per host (the user's step): `/context` in a Claude Code session started after activation, in a terminal and in T3 Code, reports the full window. A session already running may keep the old window until it restarts. The full-window fallback was measured on Claude Code 2.1.296; if a newer release reports a smaller window, that triggers the stop condition.

## Definition of Done

- The checks and builds above are green.
- `grep -rn autoCompactWindow home tests docs .compound-engineering/artifacts/solutions` matches only the `retiredKeys` entries, the retirement note, and the learning's measurements, none of which describe the key as declared.
