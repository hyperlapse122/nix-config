---
title: Raise Luna Effort to High - Plan
type: fix
date: 2026-10-29
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Raise Luna Effort to High - Plan

## Goal Capsule

- Objective: Delegated grounding and lookup work routed to Luna reaches its goal instead of ending early with an incomplete answer.
- Means: Raise the Codex `gpt-6-luna` entries in the `scout` and `quick` roles from `medium` to `high`, keeping Fast (KTD1).
- Authority: The user's request, then this plan, then `AGENTS.md`.
- Stop conditions: Stop if the `agent-instructions` check cannot be made to pass without changing anything beyond the Luna effort and its documentation.
- Execution profile: One small configuration and documentation change with its pinned test expectations.
- Finish and ship: `ce-work` implements; the `lfg` pipeline reviews, commits, pushes, and opens the pull request.

## Product Contract

### Summary

Every Luna entry in the shared agent instructions moves from `medium` to `high`. The model, the Fast service tier, and every fallback entry stay as they are.

### Problem Frame

Commit `8809ac7` raised Luna from `low` to `medium` because grounding scouts ended without reaching their goal. The user still sees CE grounding scouts on Luna `medium` stop short the same way.

### Requirements

- R1. The T3 Code table's `scout` and `quick` chains start with `codex` `gpt-6-luna` `high` Fast.
- R2. The Codex table's `scout` and `quick` rows read `gpt-6-luna` `high` Fast.
- R3. `docs/agent-routing.md` matches the rendered tables, including its prose about Luna effort and the oh-my-openagent comparison rows.

### Key Decisions

- Luna moves one step, to `high`, not further (session-settled: user-directed — chosen over keeping `medium`: Luna `medium` grounding scouts still end without reaching their goal, as `low` did). Governs R1, R2.

### Scope Boundaries

- The Claude Code, Antigravity, and OMP fallback entries in the same chains keep their current models and efforts.
- No other role's effort changes.

## Planning Contract

### Key Technical Decisions

- KTD1. **Change both `scout` and `quick` Luna entries.** Both roles share the single Luna entry shape, and `8809ac7` raised them together; keeping them equal leaves one Luna setting to reason about. Governs R1, R2.
- KTD2. **Keep Fast (`priority`).** The user asked only for the effort to change, and the standing Fast authorization for Luna lookup roles is unaffected.

### Assumptions

- `quick` follows `scout` to `high`. The request names grounding, which is `scout` work, but refers to "Luna's effort" as one setting, and the previous raise moved both.
- `gpt-6-luna` accepts `high`: T3 Code's `orchestrator_capabilities` lists `low`, `medium`, `high`, `xhigh`, and `max` for it.

## Implementation Units

### U1. Raise Luna to high in the instructions, routing doc, and test

- **Goal:** All Luna entries read `high` in the template, the routing document, and the pinned test expectations.
- **Requirements:** R1, R2, R3; KTD1, KTD2.
- **Dependencies:** None.
- **Files:**
  - `home/h82/agents/instructions/instructions.md.tmpl`
  - `docs/agent-routing.md`
  - `tests/agent-instructions.py`
- **Approach:**
  1. In the template, change `medium` to `high` on the Luna entry of the T3 Code `scout` and `quick` rows and the Codex `scout` and `quick` rows.
  2. In `docs/agent-routing.md`, make the same change in the T3 Code table, the Codex table, and the oh-my-openagent comparison rows; update the "both Luna lookup roles now use medium effort with Fast" sentence and the "Luna uses `medium` instead of `low`" differences.
  3. In `tests/agent-instructions.py`, update the expected `scout` and `quick` strings for the T3 Code and Codex tables.
- **Patterns to follow:** Commit `8809ac7`, which made the `low` to `medium` change across the same three files.
- **Test scenarios:**
  - The rendered instructions for every harness carry `codex` `gpt-6-luna` `high` Fast as the first `scout` and `quick` entry in the T3 Code table.
  - The rendered Codex instructions carry `gpt-6-luna` `high` Fast in the Codex table's `scout` and `quick` rows.
  - The Haiku, DeepSeek Flash, and GLM-5.3-Flash fallback entries in those chains still read as before.
- **Verification:** A repository search for `` `gpt-6-luna` `medium` `` outside plans and solutions finds nothing, and the `agent-instructions` check passes.

## Verification Contract

| Check | Command | Proves |
| --- | --- | --- |
| Rendered instructions | `nix build --no-link .#checks.<system>.agent-instructions` | R1, R2 for every harness |
| Formatting | `nix fmt -- --ci` (Linux CI where the formatter is absent on macOS) | No layout drift |
| Markdown lint | the pre-commit `markdownlint-cli2` hook | `docs/agent-routing.md` stays lint-clean |
| Whitespace | `git diff --check` | No stray whitespace |

## Definition of Done

- R1, R2, and R3 hold, and no `medium` Luna entry remains outside historical plans and solutions.
- The `agent-instructions` check passes on a supported builder.
- No abandoned edits remain in the diff.
