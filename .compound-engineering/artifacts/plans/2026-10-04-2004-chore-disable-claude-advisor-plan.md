---
title: Disable the Claude Code Advisor - Plan
type: chore
date: 2026-10-04
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Disable the Claude Code Advisor - Plan

## Goal Capsule

- **Objective:** Claude Code sessions that user `h82` starts on any host no longer consult an advisor model.
- **Means:** retire the declared `advisorModel` key through `retiredKeys` so activation removes it from `~/.claude/settings.json` (KTD1).
- **Authority:** this plan, then `AGENTS.md`, then `docs/provisioning.md`.
- **Stop conditions:** stop if the `agent-settings` merger rejects the rendered declaration, or if any `nixosConfigurations`, `homeConfigurations`, or `systemConfigs` output stops building.
- **Execution profile:** one small Nix change plus its check and docs; `ce-work` implements, LFG ships.

## Product Contract

### Summary

Stop declaring `advisorModel = "fable"` for Claude Code and list it as a retired key, so the next rebuild removes it from the user settings file on every host and Claude Code falls back to its default of no advisor.

### Problem Frame

The 2026-09-30 advisor plan turned the advisor on for every host by declaring `advisorModel` in the settings tier. The user now wants it off. Because the settings merge only assigns, deleting the declaration alone would leave `"fable"` in `~/.claude/settings.json` on every machine that already rebuilt.

### Requirements

- R1. After a rebuild, `~/.claude/settings.json` on every host carries no `advisorModel` key, so the advisor is off.
- R2. Every other declared Claude Code setting keeps its declared value, and undeclared keys stay the user's.
- R3. The `claude` check asserts the retirement, so reintroducing `advisorModel` to the declared set or dropping it from the retired list turns the check red.
- R4. `docs/provisioning.md` no longer describes `advisorModel` as declared.

### Key Decisions

- **Disable the advisor.** Governs R1. (session-settled: user-directed — chosen over keeping `advisorModel = "fable"` declared: the user asked to disable the advisor.)

### Scope Boundaries

- No `CLAUDE_CODE_ENABLE_EXPERIMENTAL_ADVISOR_TOOL` or other environment variable; removing the key is enough.
- `.compound-engineering/artifacts/solutions/integration-issues/claude-code-global-config-keys-ignored-in-settings-json.md` stays unchanged; its note that `advisorModel` works from `settings.json` is still true.
- The 2026-09-30 advisor plan stays as a historical record.

## Planning Contract

### Key Technical Decisions

- KTD1. **Retire `advisorModel` through `retiredKeys`, not a bare deletion.** Implements the Key Decision (R1). The merger's `remove` list is the repository's documented way for a key to leave the declared set (`home/h82/agents/claude.nix` `retiredKeys` comment, `docs/provisioning.md` last paragraph of the tier section). `scripts/agent-settings` drops each listed top-level key and is already covered by `test_retired_key_is_dropped_and_others_survive` and `test_retiring_an_absent_key_is_a_no_op` in `tests/test_agent_settings.py`, so the materialized behavior needs no new merger test.
- KTD2. **Give `tests/claude.nix`'s expected-declaration helper a per-merge `remove` list.** `expectedDeclared` hardcodes `remove = [ ]` for both merges. The settings merge now renders `remove = [ "advisorModel" ]` while the global-config merge stays empty, so the helper takes the list as an argument. `tests/gemini.nix` already asserts a non-empty `remove` this way.

### Assumptions

- Claude Code leaves the advisor off when `advisorModel` is absent from every settings tier, as the 2026-09-30 advisor plan recorded.
- While `advisorModel` is listed in `retiredKeys`, each rebuild that produces a new Home Manager generation strips it again, so an `/advisor` choice does not survive such a rebuild. That is the intended effect of disabling it here; the entry is dropped once every host has rebuilt past it, per the `retiredKeys` comment.

## Implementation Units

### U1. Retire advisorModel and assert it

- **Goal:** the declared settings drop `advisorModel` and list it for removal, and the `claude` check pins both.
- **Requirements:** R1, R2, R3; KTD1, KTD2.
- **Dependencies:** none.
- **Files:** `home/h82/agents/claude.nix`, `tests/claude.nix`.
- **Approach:**
  1. In `home/h82/agents/claude.nix`, delete `advisorModel` and its comment from `settingsTier`, and add `"advisorModel"` to `retiredKeys`.
  2. In `tests/claude.nix`, delete `advisorModel` from the `settingsTier` mirror, add a mirror of the retired list, and pass it as the settings merge's expected `remove` while the global-config merge passes an empty list (KTD2).
  3. Update the check's header comment if it describes the rendered JSON in a way the `remove` list changes.
- **Patterns to follow:** `tests/gemini.nix` `hooksExpected` and `declaredExpected` for asserting a rendered `remove` list.
- **Test scenarios:**
  - With the change, the rendered `claude-declared-settings.json` carries `remove: ["advisorModel"]`, no `advisorModel` under `set`, and the `claude` check passes on every user entry.
  - Mutation: `advisorModel` put back into `settingsTier` makes the check fail with its declared-settings drift message (and the merger would refuse it as both set and removed).
  - Mutation: `retiredKeys` emptied again makes the check fail with the same drift message.
  - The global-config merge still renders `remove: []` and its assertion still passes.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.claude` passes, and each mutation above turns it red.

### U2. Update provisioning docs

- **Goal:** the docs describe the advisor as not declared and name its retirement.
- **Requirements:** R4.
- **Dependencies:** U1.
- **Files:** `docs/provisioning.md`.
- **Approach:**
  1. Remove `advisorModel` from the settings-file key list.
  2. Replace the "`advisorModel` is `fable`…" line with one sentence saying `advisorModel` is retired, so the advisor is off and the retired entry goes once every host has rebuilt.
- **Test expectation:** none -- documentation only.
- **Verification:** no remaining text in `docs/provisioning.md` describes `advisorModel` as declared.

## Verification Contract

| Gate | Command | Applies to |
| --- | --- | --- |
| Formatting | `nix fmt -- --ci` | U1 |
| Claude check | `nix build --no-link .#checks.x86_64-linux.claude` | U1 |
| Merger unit tests | `nix build --no-link .#checks.x86_64-linux.agent-settings` | U1 (unchanged, confirms remove semantics) |
| Flake checks | `nix flake check` | all |
| Host builds | the per-output build loop in `AGENTS.md` for `nixosConfigurations`, `homeConfigurations`, and `systemConfigs` | all |

No NixOS VM test reads Claude Code settings, so the VM checks are not affected by this change.

## Definition of Done

- `advisorModel` appears in `retiredKeys` and nowhere in `settingsTier` or its test mirror.
- The `claude` check passes and fails under both U1 mutations.
- `docs/provisioning.md` matches the declared set.
- `nix flake check` and every host output build pass.
- No abandoned experimental edits remain in the diff.
