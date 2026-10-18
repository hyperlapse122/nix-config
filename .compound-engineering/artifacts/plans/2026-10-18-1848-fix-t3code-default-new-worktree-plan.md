---
title: T3 Code Default New Worktree - Plan
type: fix
date: 2026-10-18
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# T3 Code Default New Worktree - Plan

## Goal Capsule

- **Objective:** A new T3 Code thread starts in a new worktree by default on every machine this flake configures, as it did before commit `e54b95b`.
- **Means:** declare `defaultThreadEnvMode = "worktree"` again in the settings `home/h82/t3code.nix` merges into `~/.t3/userdata/settings.json` (KTD1).
- **Authority:** the user's request, then this plan, then repository conventions in `AGENTS.md`.
- **Stop conditions:** stop if the declared key cannot reach `settings.json` through the agent-settings merge, or if the `t3code-traits` check cannot express the new declaration.
- **Execution profile:** Lightweight, two units, Nix config plus one learning document.
- **Finishing:** `ce-work` implements; `lfg` reviews, commits, and opens the pull request.

## Product Contract

### Summary

Put `defaultThreadEnvMode = "worktree"` back into the declared T3 Code settings, take it off the retired-keys list, update the `t3code-traits` expectation, and update the learning that recorded the retirement.

### Problem Frame

Commit `e54b95b` (issue #224) stopped declaring `defaultThreadEnvMode` and retired the stored value, so each repository's `t3.json` or T3 Code's built-in `local` decides where a thread starts. The user wants New Worktree to be the default again.

### Key Decisions

- **T3 Code's default thread env mode is declared machine-wide as `"worktree"`.** Governs R1, R2. (session-settled: user-directed — chosen over leaving the key undeclared so each repository's t3.json or T3 Code's built-in `local` decides: the user wants New Worktree as the default again.)

### Requirements

**Settings**

- R1. The declared settings set `defaultThreadEnvMode` to `"worktree"`.
- R2. Activation no longer removes `defaultThreadEnvMode` from `settings.json`.

**Checks and records**

- R3. `checks.x86_64-linux.t3code-traits` expects the restored declaration and fails if the key is dropped or retired again.
- R4. The learning `.compound-engineering/artifacts/solutions/integration-issues/t3code-settings-json-value-outranks-repository-t3-json.md` no longer says the module leaves the key to `t3.json`.

### Scope Boundaries

- The plan `.compound-engineering/artifacts/plans/2026-10-16-0004-fix-t3code-thread-env-mode-from-t3-json-plan.md` stays as a historical record.
- The repository's own `t3.json` is not changed.
- `worktreeSubmodules` and other project-file-backed keys stay undeclared.
- Not built: a per-repository opt-out. A declared value outranks every repository's `t3.json`, which the user accepted; a per-project override in T3 Code's UI still wins over it.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Restore the key as a plain scalar in `settings`.** It lands in the declaration's `set` map like the other scalars, which is how it was declared before `e54b95b`. Governs R1.
- KTD2. **Keep `retiredKeys` and the `remove` plumbing, with an empty list.** `home/h82/agents/codex.nix` and `home/h82/agents/gemini.nix` keep `retiredKeys = [ ]` the same way, so the next retirement needs no plumbing change. Governs R2.
- KTD3. **Update the existing learning in place rather than marking it stale.** Its precedence facts stay true; only the Solution, which describes the retired state, and the Prevention advice change. Governs R4.

### Assumptions

- T3 Code still resolves `defaultThreadEnvMode` from `settings.json` before `t3.json`. The learning records that order for `0.0.46-nightly.20261015.3158`; the repository now pins `0.1.1-nightly.20261018.3302`, so U1 rechecks it against the pinned build. If the order changed, the declared value would lose to a repository's `t3.json`, and the restored declaration would still set the default for repositories that do not set the key.

---

## Implementation Units

### U1. Restore the declaration and its check

- **Goal:** declare `defaultThreadEnvMode = "worktree"` and stop retiring it.
- **Requirements:** R1, R2, R3; KTD1, KTD2.
- **Dependencies:** none.
- **Files:** `home/h82/t3code.nix`, `tests/t3code-traits.nix`.
- **Approach:**
  1. Add `defaultThreadEnvMode = "worktree";` to `settings` in alphabetical position after `defaultAutoPull`.
  2. Set `retiredKeys = [ ];` and rewrite its comment so it describes the convention without naming `defaultThreadEnvMode`.
  3. In `settingsExpectedBase`, add the key to `set` and change `remove` to `[ ]`; update the comment above `settingsExpected` that says a retired key is removed.
  4. Confirm in the pinned T3 Code build's client bundle (`t3ProjectFile-*.js`, the file the learning's `retire_when` names) that the resolver still returns the `settings.json` value with source `environment` before `t3.json`, and record the pin checked in the learning (U2).
- **Patterns to follow:** the `retiredKeys = [ ];` comment in `home/h82/agents/codex.nix`.
- **Test scenarios:**
  - The rendered `t3code-declared-settings.json` has `set.defaultThreadEnvMode = "worktree"` and `remove = [ ]`; `t3code-traits` passes.
  - Mutation: removing the key from `settings` fails `t3code-traits`.
  - Mutation: putting `"defaultThreadEnvMode"` back into `retiredKeys` fails `t3code-traits`.
- **Verification:** `t3code-traits` passes on the change and fails on both mutations.

### U2. Update the learning

- **Goal:** the learning describes the current declaration and the accepted precedence trade-off.
- **Requirements:** R4; KTD3.
- **Dependencies:** U1.
- **Files:** `.compound-engineering/artifacts/solutions/integration-issues/t3code-settings-json-value-outranks-repository-t3-json.md`.
- **Approach:**
  1. Keep the four-tier list in Why This Works, and reword its closing sentence ("With no value at tier 2 ... which is what issue #224 asked for") to say the module now fills tier 2 with `"worktree"` on purpose, so a project reaches its `t3.json` only if that value is removed.
  2. Add a short note that the module declares `defaultThreadEnvMode = "worktree"` again on purpose, so New Worktree is the default and outranks every repository's `t3.json`.
  3. Reword Solution and Prevention so they no longer claim the key is retired; keep the `retiredKeys` convention as the way to stop declaring a key.
- **Test scenarios:** Test expectation: none -- documentation only; `markdownlint-cli2` through the pre-commit hook covers its format.
- **Verification:** no sentence in the learning says the module leaves `defaultThreadEnvMode` to `t3.json` or presents falling through to `t3.json` as the goal.

---

## Verification Contract

| Gate | Command | Applies to |
| --- | --- | --- |
| Format | `nix fmt -- --ci` | U1 |
| Traits check | `nix build --no-link .#checks.x86_64-linux.t3code-traits` (on macOS, verify inputs through `nix derivation show` per the learning on Linux-only checks, or leave to CI) | U1 |
| Flake evaluation | `nix flake check --no-build` | U1 |
| Markdown lint | pre-commit hook `mise run lint-staged-markdown` | U2 |

## Definition of Done

- R1 through R4 hold.
- `t3code-traits` passes, and both mutations in U1 fail it. The check builds only on Linux, so on macOS the evidence is the `nix derivation show` comparison of the check's expected and rendered declarations for the change and each mutation, plus the CI `check-shards` run on the pull request.
- The pinned T3 Code build was confirmed to resolve `settings.json` before `t3.json` (U1 step 4).
- No abandoned-attempt code or leftover mutation remains in the diff.
