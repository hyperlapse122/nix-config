---
title: T3 Code Thread Environment Mode from t3.json - Plan
type: fix
date: 2026-10-16
topic: t3code-thread-env-mode-from-t3-json
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# T3 Code Thread Environment Mode from t3.json - Plan

## Goal Capsule

- **Objective:** Each repository's `t3.json` decides whether new T3 Code threads start in a worktree or the local checkout, and a repository without the key gets T3 Code's built-in `"local"`.
- **Means:** Stop declaring `defaultThreadEnvMode` and retire the stored value through the `agent-settings` `remove` list (KTD1, KTD2).
- **Product authority:** GitHub issue #224.
- **Open blockers:** None.
- **Stop conditions:** Stop and report when retiring the key would need the module to manage `projectSettingsOverrides`, or when the pinned T3 Code no longer reads `t3.json` for this key.
- **Execution profile:** One module change, one check change, and one plan note, implemented by `ce-work` and shipped through `lfg` in one pull request.

## Product Contract

### Summary

`home/h82/t3code.nix` no longer sets `defaultThreadEnvMode`. Its rendered `settings.json` declaration lists the key under `remove`, so the next activation deletes the value written earlier. `tests/t3code-traits.nix` expects that declaration. The T3 Code settings plan records the change.

### Problem Frame

The module merges `defaultThreadEnvMode = "worktree"` into `~/.t3/userdata/settings.json`. The pinned T3 Code resolves the key through project override, then `settings.json`, then `t3.json`, then the built-in `"local"`, so the machine-wide value hides every repository's `t3.json`. A repository that wants local threads cannot get them.

### Requirements

**Declared settings**

- R1. The declared `settings.json` settings do not set `defaultThreadEnvMode`.
- R2. Activation deletes a `defaultThreadEnvMode` already present in `settings.json`, and leaves every other key as it was.

**Check coverage**

- R3. `tests/t3code-traits.nix` fails when the rendered declaration sets `defaultThreadEnvMode` again, or no longer lists it under `remove`.

**Record**

- R4. The T3 Code settings plan's KTD2 no longer lists `defaultThreadEnvMode` in the declared set and names its retirement.

### Key Decisions

- **Leave the thread environment mode to each repository.** (session-settled: user-directed — chosen over keeping `"worktree"` machine-wide: the machine value overrides every repository's `t3.json`.) Governs R1.
- **The module leaves per-project overrides alone.** (session-settled: user-directed — chosen over declaring or resetting `projectSettingsOverrides` in Nix: they are app state.) Governs R2.

### Scope Boundaries

- No change to `t3.json`, `worktreeSubmodules`, or any other declared key.
- No management of `projectSettingsOverrides`, including the stored `defaultProjectScripts`.

## Planning Contract

### Key Technical Decisions

- KTD1. **`render` emits a `remove` list from a named `retiredKeys` binding.** `home/h82/t3code.nix` declares `retiredKeys = [ "defaultThreadEnvMode" ]` with the comment the agent modules carry (`home/h82/agents/claude.nix`, `codex.nix`, `gemini.nix`): the merge only assigns, so a dropped key moves here, and the entry is deleted once every host has rebuilt past it. That end date keeps the entry from deleting a machine-wide mode the user later picks in the app. `render` gains a list argument written as the declaration's `remove` field: `retiredKeys` for `settings.json` and `[ ]` for `client-settings.json`. `scripts/agent-settings` already reads `remove` and rejects a key that is both set and removed, so a mutation that puts the key back while the remove entry stays fails activation as well as the check. (session-settled: user-directed — chosen over only dropping the key from `set`: the merge only assigns, so the stored value would remain.) Covers R1, R2.
- KTD2. **The check compares the rendered file byte for byte.** `assertSettingsWith` already `cmp`s the materialized declaration against `settingsExpected`, which the test renders itself. Adding `remove` to both expected documents and dropping the key from `set` makes any mutation of the declared key set fail, with no new assertion machinery. This reads the materialized output, as `.compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md` asks. Covers R3.

### Findings on stored project scripts

The issue asked whether a stored project script outranks `t3.json`'s `scripts` when a worktree is created. In the pinned nightly (`0.0.46-nightly.20261015.3158`), `resolveProjectScripts` returns `projectSettingsOverrides[projectId].defaultProjectScripts` when it is set. Once `projectSettingsFolded` is true, it otherwise returns the environment's `defaultProjectScripts`. It never reads `t3.json` there: the schema describes `t3.json` scripts as ones "team members can import". On this machine `projectSettingsFolded` is true, and two projects carry stored `defaultProjectScripts`. One holds the current `Setup` command. The other holds the older `Setup Worktree` command without `git config core.hooksPath .githooks`. That stale override wins, so resetting or re-importing it in the app is the user's call. No project carries a stored `defaultThreadEnvMode`, so after R2 every project follows its `t3.json`.

### Assumptions

- A project-level `defaultThreadEnvMode` set later in the app's project settings still outranks `t3.json`, by T3 Code's design. This plan does not change that.

## Implementation Units

### U1. Retire `defaultThreadEnvMode` from the declared settings

**Goal:** The rendered `settings.json` declaration drops the key from `set` and lists it under `remove`.

**Requirements:** R1, R2, R3; KTD1, KTD2.

**Dependencies:** None.

**Files:**

- `home/h82/t3code.nix`
- `tests/t3code-traits.nix`

**Approach:**

1. Remove `defaultThreadEnvMode` from `settings` in `home/h82/t3code.nix`.
2. Declare `retiredKeys` with its comment, give `render` a `remove` list argument, and pass `retiredKeys` and `[ ]` from the two `merges` entries, per KTD1.
3. In `tests/t3code-traits.nix`, drop the key from `settingsExpected.set`, add `remove = [ "defaultThreadEnvMode" ]` there, and add `remove = [ ]` to `clientSettingsExpected`, per KTD2.
4. Update the module's comment where it describes what the declaration carries.

**Patterns to follow:** `retiredKeys` in `home/h82/agents/claude.nix`, and `tests/codex.nix` and `tests/gemini.nix`, which already render `remove = [ ]` in expected declarations.

**Test scenarios:**

- The `t3code-traits` check passes with the change.
- Mutation: put `defaultThreadEnvMode = "worktree"` back in `settings`, and the check fails on the declaration mismatch.
- Mutation: drop `"defaultThreadEnvMode"` from the `remove` list, and the check fails.
- Mutation: render `client-settings.json` without its `remove` field, and the check fails.
- `agent-settings` run against a copy of `settings.json` that holds `defaultThreadEnvMode` removes it and keeps the other keys.

**Verification:** `nix build --no-link .#checks.x86_64-linux.t3code-traits` passes on the change and fails on each mutation. The check exists only under `checks.x86_64-linux` and builds only on an x86_64-linux builder. On a macOS host without one, show each mutation locally by comparing the module's rendered declaration with the test's expected document through `nix eval`, run the `agent-settings` scenario directly, and leave the check build to CI's check shards.

### U2. Record the change in the settings plan

**Goal:** KTD2 of the T3 Code settings plan matches the declared set.

**Requirements:** R4.

**Dependencies:** U1.

**Files:**

- `.compound-engineering/artifacts/plans/2026-10-08-2247-feat-t3code-declarative-settings-plan.md`

**Approach:** Remove `defaultThreadEnvMode` from the KTD2 list in place, and add one sentence that the key is retired through `remove` so each repository's `t3.json` decides (issue #224).

**Test expectation:** none -- documentation only.

**Verification:** KTD2 no longer lists the key and cites #224.

## Verification Contract

- `nix fmt -- --ci`
- `nix flake check`, or `nix flake check --no-build` on a macOS host without a Linux builder.
- `nix build --no-link .#checks.x86_64-linux.t3code-traits` on an x86_64-linux builder or in CI, plus each U1 mutation seen to fail it, by that build or by the local `nix eval` comparison U1 describes.
- Build every `nixosConfigurations`, `homeConfigurations`, `systemConfigs`, and `darwinConfigurations` output this builder can build, as `AGENTS.md` lists; outputs for another platform build in CI.

## Definition of Done

- R1 through R4 hold, the `t3code-traits` check passes in CI, and every U1 mutation was seen to fail, with the report naming where each was seen.
- No experimental or abandoned code remains in the diff.
