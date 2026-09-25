---
title: Set Claude Code Defaults to Opus 5.5 Medium - Plan
type: feat
date: 2026-09-25
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Set Claude Code Defaults to Opus 5.5 Medium - Plan

## Goal Capsule

- **Objective:** A fresh Claude Code session on either machine starts on Claude Opus 5.5 with the 1M-context window at medium reasoning effort, without manual setup.
- **Means:** Change the two declared values in the Claude Code settings tier and move the check, fixtures, and docs that mirror or describe them (Key Decisions, KTD1 to KTD3).
- **Authority:** The request that invoked this run; `AGENTS.md` for checks, host builds, and repository style; the plan `2026-09-22-2253-feat-claude-code-model-sonnet-effort-xhigh-plan.md`, whose declared values this plan replaces.
- **Stop conditions:** Stop if a one-sided mutation of the `claude` check stays green, because the guard would then be decorative. Stop if `nix flake check` or a host build fails for a reason these edits do not explain.
- **Execution profile:** Single-session configuration change with no hardware step. Repository checks and builds prove the declared values. Whether Claude Code applies them is the manual checklist item in `docs/verification.md`, reported separately.
- **Who finishes it:** `ce-work` implements; the pull request ships it.

## Product Contract

### Summary

The declared Claude Code defaults become `model = "opus[1m]"` and `effortLevel = "medium"`, replacing `sonnet` and `xhigh`. The `claude` check, the merger test fixtures, and two docs pages move with them.

### Problem Frame

`home/h82/agents/claude.nix` declares `sonnet` at `xhigh`, set by commit `07246cb` for issue #72. The user now wants Claude Opus 5.5 at medium effort as the default. Activation reasserts every declared key on each rebuild that produces a new Home Manager generation, so leaving the module alone keeps writing `sonnet` and `xhigh` into `~/.claude/settings.json`. Changing only the module fails the `claude` check on drift and leaves the docs describing values no host runs.

### Key Decisions

- **The declared `model` is `opus[1m]`.** (session-settled: user-directed — chosen over keeping `sonnet`: the user wants Claude Opus 5.5 as the default model.) Governs R1.
- **The declared `effortLevel` is `medium`.** (session-settled: user-directed — chosen over keeping `xhigh`: the user asked for Medium as the default effort.) Governs R2.

### Requirements

**Declaration**

- R1. `home/h82/agents/claude.nix` declares `model = "opus[1m]"` in `settingsTier`.
- R2. `home/h82/agents/claude.nix` declares `effortLevel = "medium"` in `settingsTier`.

**Guards**

- R3. `tests/claude.nix` mirrors both values, so the `claude` check goes red when the module and the mirror disagree on either.
- R4. `tests/test_agent_settings.py` holds the declared pair in `DECLARED` and the other pair in `EXISTING`, so the two still differ on both keys.

**Documentation**

- R5. `docs/provisioning.md` describes the declared model and effort as they now stand.
- R6. The `docs/verification.md` checklist item expects Claude Opus 5.5 with the 1M context window and effort `medium`.

### Scope Boundaries

- Only `model` and `effortLevel` change. Every other declared setting, the environment tier, and `retiredKeys` stay as they are.
- The comment above `effortLevel` in `home/h82/agents/claude.nix` states a schema fact that does not depend on the value, so it stays.
- The `agent-settings` check in `flake.nix` seeds `sonnet` and declares `opus[1m]` as merger data with no link to the module. It is already divergent, so it stays.
- No hardware installation, disk change, or `nixos-rebuild switch` runs as validation.

#### Deferred to Follow-Up Work

- The `claude` check evaluates only the two ThinkPad configurations, while the same Home Manager module also serves the MS-7D91 configurations. Extending the check to them is separate work.

## Planning Contract

### Key Technical Decisions

- KTD1. **Realign `tests/test_agent_settings.py` so `DECLARED` carries `opus[1m]` and `medium`, and `EXISTING` carries `sonnet` and `xhigh`.** The fixtures are literals owned by the merger tests. That file loads `scripts/agent-settings` and never reads the module, so leaving them would not break anything. Realigning follows the convention `07246cb` set and restores the pair the file held before that commit, so `DECLARED` keeps mirroring what the repository declares. The pair still differs on both keys, which is what lets the tests tell a whole-file writer from a correct merger (`.compound-engineering/artifacts/solutions/best-practices/converged-fixture-state-defeats-nix-check-mutation-testing.md`). Governs R4.
- KTD2. **Replace the one-line `sonnet` sentence in `docs/provisioning.md` with an explanation of the `[1m]` suffix and the effort level.** `07246cb` swapped an operator-facing explanation, which said what the suffix does and how to drop it, for a sentence that restated the values. The explanation is worth restoring because a reader who wants the standard context window needs to know which suffix to remove. Governs R5.
- KTD3. **The verification checklist names the resolved model as well as the alias.** `opus` is an alias that follows the current Opus, and the request is for Opus 5.5 specifically. A hardware check that only names `opus[1m]` cannot notice the alias resolving to a different model. Governs R6.

### Assumptions

- `opus[1m]` and `medium` are accepted by Claude Code. The repository declared both before `07246cb`, and `scripts/agent-settings` assigns declared scalars without validating `model` or `effortLevel`.
- The `opus` alias resolves to Claude Opus 5.5 on the hosts, as the request states. The repository pins the alias, not a version, and cannot verify the resolution. The checklist item in R6 is where it gets verified.
- The Claude Code model-config documentation does not state what happens when a host lacks 1M-context support, so the docs make no fallback promise and only say that dropping the `[1m]` suffix selects the standard context.

### Sequencing

U1 changes behavior and proves its guard. U2 and U3 do not depend on U1 or on each other, so any order works. Land U1 first, because its `claude` check is what proves the declared values took effect.

### Sources

- The previous change to the same values: commit `07246cb` and `.compound-engineering/artifacts/plans/2026-09-22-2253-feat-claude-code-model-sonnet-effort-xhigh-plan.md`. This plan reverses its values and keeps its file set.
- `.compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md` for why the `claude` check diffs the rendered JSON, which is what makes the mutation rounds in U1 meaningful.
- `.compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md` for keeping each mutation a string-literal change so it reaches the assertion instead of dying at evaluation.

## Implementation Units

### U1. Declare the new defaults and mirror them in the `claude` check

- **Goal:** Activation writes `opus[1m]` and `medium`, and the `claude` check asserts exactly those values.
- **Requirements:** R1, R2, R3 (Key Decisions on `model` and `effortLevel`).
- **Dependencies:** None.
- **Files:** `home/h82/agents/claude.nix`, `tests/claude.nix`.
- **Approach:**
  1. In `settingsTier` of `home/h82/agents/claude.nix`, set `model` and `effortLevel` to the Key Decision values.
  2. In `settingsTier` of `tests/claude.nix`, set the same two values. The check diffs the JSON the module renders against the JSON built from this mirror.
- **Patterns to follow:** The same two-file edit `07246cb` made, with the values inverted.
- **Execution note:** Prove the guard before trusting it. Run each one-sided mutation, confirm the failure is the drift message and not an evaluation error, then restore both files.
- **Test scenarios:**
  - Happy path: with both files at `opus[1m]` and `medium`, the `claude` check passes on both ThinkPad configurations.
  - Failure path: the module set back to `"sonnet"` while the mirror keeps `opus[1m]` turns the check red with "the declared settings this repository renders drifted from the asserted values".
  - Failure path: the module at the new values while the mirror's `effortLevel` is `"xhigh"` turns the check red with the same message.
  - Edge case: each mutation changes only a string literal, so evaluation still succeeds and the round exercises the assertion.
- **Verification:** The `claude` check is green, both mutations are red for the drift reason, and the working tree holds the intended values afterwards.

### U2. Realign the merger fixtures

- **Goal:** The fixtures mirror the declared pair and still differ from the seeded file on both keys.
- **Requirements:** R4 (KTD1).
- **Dependencies:** None.
- **Files:** `tests/test_agent_settings.py`.
- **Approach:**
  1. Set `DECLARED['model']` and `DECLARED['effortLevel']` to `opus[1m]` and `medium`, and `EXISTING['model']` and `EXISTING['effortLevel']` to `sonnet` and `xhigh`.
  2. Change the three assertions that expect the declared model after a merge to expect `opus[1m]`: the test that restores a key the user removed, `test_main_returns_zero_on_success`, and `test_process_exits_zero_and_merges_on_success`.
- **Patterns to follow:** The fixture inversion in `07246cb`, reversed.
- **Test scenarios:**
  - Happy path: `tests/test_agent_settings.py` passes end to end.
  - Edge case: `EXISTING` and `DECLARED` differ on `model` and on `effortLevel`, so a merger that rewrote the whole file could not produce the same output as a correct one.
  - Integration: the `agent-settings` flake check, which this unit does not touch, still passes.
- **Verification:** The Python suite and the `agent-settings` check both pass.

### U3. Update the docs

- **Goal:** The docs describe the values hosts run and tell the operator what to confirm on hardware.
- **Requirements:** R5, R6 (KTD2, KTD3).
- **Dependencies:** None.
- **Files:** `docs/provisioning.md`, `docs/verification.md`.
- **Approach:**
  1. In `docs/provisioning.md`, replace the sentence about the `sonnet` value with one that says `opus[1m]` starts every session on the 1M-context Opus variant, that dropping the `[1m]` suffix selects the standard window instead, and that `medium` is the declared effort.
  2. In `docs/verification.md`, rewrite the checklist item so a fresh `claude` session is expected to report Claude Opus 5.5 with the 1M context window, declared as `opus[1m]`, at effort `medium`. Keep its closing sentence that repository checks verify only the declared values.
- **Test scenarios:**
  - Test expectation: none — prose only. The `markdown-lint` check gates formatting.
- **Verification:** `markdown-lint` passes, and a search of `docs/` finds no line that still presents `sonnet` or `xhigh` as the declared values.

## Verification Contract

| Command | Applies to | Proves |
| --- | --- | --- |
| `nix fmt -- --ci` | U1 | Nix formatting is unchanged |
| `nix build --no-link .#checks.x86_64-linux.claude` | U1 | The module and its mirror agree on the declared values |
| `python3 tests/test_agent_settings.py` | U2 | The merger tests pass with the realigned fixtures |
| `nix build --no-link .#checks.x86_64-linux.agent-settings` | U2 | The packaged merger check is unaffected |
| `nix build --no-link .#checks.x86_64-linux.markdown-lint` | U3 | The docs and this plan lint clean |
| `nix flake check` | U1, U2, U3 | Every declared check passes |
| `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel` | U1 | The ThinkPad production build succeeds |
| `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel` | U1 | The ThinkPad bootstrap build succeeds |
| `nix build --no-link .#nixosConfigurations.MS-7D91.config.system.build.toplevel` | U1 | The desktop production build succeeds |
| `nix build --no-link .#nixosConfigurations.MS-7D91-bootstrap.config.system.build.toplevel` | U1 | The desktop bootstrap build succeeds |

Hardware confirmation of the running model and effort is the `docs/verification.md` checklist item. It stays unchecked and is reported separately from these results.

## Definition of Done

- R1 through R6 hold.
- Both one-sided mutation rounds in U1 turned the `claude` check red for the drift reason, and both files were restored.
- Every command in the Verification Contract passes.
- No file outside the five named in the units changed, apart from this plan.
- Abandoned mutation edits are gone from the diff.
