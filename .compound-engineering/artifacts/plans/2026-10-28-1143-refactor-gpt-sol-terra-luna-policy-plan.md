---
title: GPT Sol, Terra, and Luna Policy - Plan
type: refactor
date: 2026-10-28
topic: gpt-sol-terra-luna-policy
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# GPT Sol, Terra, and Luna Policy - Plan

## Goal Capsule

- **Objective:** Make the user's Codex allowance last longer while retaining comparable capability for each kind of work.
- **Means:** Replace the managed Astra/Sol/Luna policy with Sol/Terra/Luna, adjusting reasoning effort by role.
- **Product authority:** The confirmed scope and choices from the 2026-10-28 conversation, recorded below.
- **Open blockers:** None. API benchmark costs are supporting evidence, not a measurement of subscription consumption.

---

## Product Contract

### Summary

Use Sol for coordination and complex work, Terra for routine Codex work, and Luna for retrieval.
Align Codex startup and default subagent settings with that policy, including the approved Sol max exception for hard decisions and final gates.
Keep existing service tiers.

### Problem Frame

Astra consumes the user's allowance too quickly for routine coding sessions.
Startup settings and instruction routing are separate managed surfaces, so changing only the instructions would leave new Codex sessions on Astra.

### Key Decisions

- **Include startup defaults.** Governs R1, R3. (session-settled: user-directed — chosen over instruction-only changes: new Codex sessions must also stop starting on Astra.)
- **Preserve capability through role-specific effort.** Governs R2, R4. (session-settled: user-approved — chosen over uniform replacement with Terra: routine work can move to Terra while complex work retains Sol.)
- **Permit Sol max for the two highest-stakes roles.** Governs R5. (session-settled: user-directed — chosen over an xhigh ceiling: preserve the upper role's benchmark capability while saving allowance elsewhere.)
- **Retain service tiers.** Governs R6. The user explicitly requested this compatibility boundary when confirming scope.

### Requirements

**Models and role coverage**

- R1. Remove Astra from managed GPT routing and Codex startup defaults, including fallback entries in the T3 Code table and the standalone Codex table.
- R2. Apply the following role assignments wherever the corresponding GPT role is configured; retain the other existing Sol assignments and their efforts.

| Surface | Role | Required model | Reasoning effort |
| --- | --- | --- | --- |
| T3 Code Codex and standalone Codex | `root` primary | `gpt-6.1-sol` | `high` |
| Standalone Codex | `writing`, `visual`, `implement` | `gpt-6.1-terra` | `medium` |
| T3 Code and standalone Codex | `hard-decision`, `review-gate` GPT selection | `gpt-6.1-sol` | `max` |
| T3 Code and standalone Codex | `scout`, `quick` GPT selection | `gpt-6-luna` | `low` |

- R3. Set the managed Codex startup model to Sol high and the managed default subagent to Terra medium.
- R4. Keep the current Sol selections for complex implementation, analysis, ordinary review, and architecture; the T3 Code `implement` fallback remains Sol medium because it already belongs to that capability level.
- R5. Allow automatic GPT max only for `gpt-6.1-sol` in `hard-decision` and `review-gate`; all other GPT max uses and every GPT ultra use continue to require an explicit request for the affected work.

**Compatibility and delivery**

- R6. Preserve existing service-tier assignments and precedence: Fast Codex entries use `priority`, other Codex entries use `default`, and `ultrafast` remains prohibited.
- R7. Preserve non-GPT model selections, their relative fallback order, and CE-owned peer selection.
- R8. Preserve usage-threshold handling, explicit user overrides, resume-state precedence, and the rule against changing a running root session's model.
- R9. Keep rendered instructions, managed Codex settings, `docs/agent-routing.md`, and the affected check expectations consistent with R1 through R8.

### Acceptance Examples

- AE1. **Covers R1, R3, R8.** When a fresh Codex session uses the managed defaults without an explicit override, it selects Sol high; an already-running session retains its selection.
- AE2. **Covers R2, R3, R4.** A standalone Codex routine implementation uses Terra medium, and a child without a role override receives that same managed default; complex implementation and the T3 Code implementation fallback retain their existing Sol effort.
- AE3. **Covers R2, R5.** A hard decision or final gate may select Sol max without asking again; an ordinary review cannot select max under this exception.
- AE4. **Covers R1, R6, R7.** Removing an Astra fallback does not promote a standard entry to Fast or reorder the remaining non-GPT fallbacks.
- AE5. **Covers R6.** A Fast Luna lookup remains at priority service, while the managed Codex startup remains at default service.

### Scope Boundaries

- This work covers the shared GPT routing policy, its documentation and checks, and the managed Codex startup/subagent defaults.
- T3 Code's global `defaultModelSelection` remains Claude Opus medium under R7; selecting Codex as the GPT root is separate from changing that app-wide selection.
- Provider catalogs, usage accounting, thresholds, paid API access, and non-GPT role redesign are outside scope.
- Historical plans and third-party comparison baselines remain historical evidence; R1 applies to managed selections rather than every mention of Astra.
- This brainstorm produces requirements only. Applying configuration to a machine, committing, and publishing are separate actions.

### Evidence and Assumptions

The user observed rapid allowance depletion with Astra.
Artificial Analysis provides a capability reference for the proposed effort choices, but neither its composite score nor API task cost proves equal performance or an exact allowance saving on the user's workload.

The following snapshot was retrieved on 2026-10-28 from AA pages identifying Intelligence Index v5.0.
Some pairwise comparison pages still identify v4.3.2; their scores are excluded from this table.

| Model and effort | AA v5.0 score | Source |
| --- | --- | --- |
| Astra medium | 51 | [Model page](https://artificialanalysis.ai/models/gpt-6-astra-medium) |
| Sol high | 50 | [Model page](https://artificialanalysis.ai/models/gpt-6-1-sol-high) |
| Astra high | 55 | [Model page](https://artificialanalysis.ai/models/gpt-6-astra-high) |
| Sol xhigh | 52 | [Model page](https://artificialanalysis.ai/models/gpt-6-1-sol-xhigh) |
| Sol max | 55 | [Release page](https://artificialanalysis.ai/models/releases/gpt-6-1-sol) |
| Sol low | 35 | [Model page](https://artificialanalysis.ai/models/gpt-6-1-sol-low) |
| Terra medium | 38 | [Model page](https://artificialanalysis.ai/models/gpt-6-1-terra-medium) |

The scores support approximate capability matching rather than equality across tasks.
No exact subscription saving is an acceptance threshold.
Live T3 Code capabilities listed Sol, Terra, and Luna with the required reasoning efforts and existing service tiers; this establishes selectable configuration, not authenticated execution of every combination.

### Sources / Research

- `home/h82/agents/instructions/instructions.md.tmpl`: current shared T3 Code table, standalone Codex table, effort limits, and tier rules.
- `home/h82/agents/codex.nix`: managed startup and default subagent settings.
- `home/h82/t3code.nix`: separate global Claude selection and Codex provider-instance configuration.
- `docs/agent-routing.md`: mirrored role policy and the current statement that Terra is unused.
- `flake.nix`: registration of the `agent-instructions` consumer check.
- `.compound-engineering/artifacts/plans/2026-10-26-1329-refactor-codex-sol-elevated-effort-plan.md`: previous routing work; its exclusion of startup defaults does not apply to this scope.

---

## Planning Contract

**Product Contract preservation:** Requirements and acceptance examples unchanged; planning-owned questions resolved below.

### Key Technical Decisions

- KTD1. **Preserve the two existing Sol root fallbacks.** Replace the Astra primary with Sol high, leaving Sol medium Fast then Sol medium as the fallback order under R1, R2, R6, R8.
- KTD2. **Collapse the two GPT hops in each T3 upper-role chain.** Use one Sol max entry followed by the existing non-GPT fallback under R1, R2, R5, R7.
- KTD3. **Update existing contract owners.** `tests/agent-instructions.py` owns delivered prompt policy; `tests/codex-settings.nix` owns materialized startup settings and scratch-home activation under R9.

### Assumptions

This is a bounded configuration change using existing renderers and reconciliation.
Repository checks prove the declared settings and instruction delivery, not actual model quality or exact authenticated subscription consumption.
No new runtime mechanism or redundant check is needed.

---

## Implementation Units

### U1. Align GPT routing and its delivered instructions

**Goal:** Apply R1, R2, R4 through R9 to all managed instruction deliveries.

**Dependencies:** None.

**Files:** `home/h82/agents/instructions/instructions.md.tmpl`, `docs/agent-routing.md`, `tests/agent-instructions.py`.

**Approach:** Follow KTD1 and KTD2, update the common effort sentence, and synchronize current-policy documentation while preserving historical comparison baselines.
Update existing independent prompt-byte expectations and their mutation controls rather than adding a parallel test inventory.

**Test scenarios:**

- Covers AE3. Delivered instructions permit the scoped max exception and retain explicit-request restrictions elsewhere.
- Covers AE4, AE5. Rendered chains contain no managed Astra entry and retain existing tiers and non-GPT fallback order.
- Covers AE2. Standalone routine roles use the required Terra selection while unchanged complex roles remain Sol.

**Verification:** The existing delivered-instructions check passes for all local fixtures and continues to reject altered model, effort, and policy sentences.

### U2. Align managed startup and subagent defaults

**Goal:** Apply R3, R6, R8, R9 at the settings activation boundary.

**Dependencies:** U1.

**Files:** `home/h82/agents/codex.nix`, `tests/codex-settings.nix`.

**Approach:** Update the existing declared keys and expected applied TOML through KTD3; keep the merger, ownership boundaries, and tier value intact.

**Execution note:** Prefer the existing scratch-home activation proof over adding a unit test of literal source text.

**Test scenarios:**

- Covers AE1. Executing activation in a scratch home replaces stale model and effort defaults with the managed values.
- Covers AE2, AE5. The resulting TOML has the required subagent defaults and default service tier while retaining unrelated user settings.

**Verification:** The existing settings check passes and the seeded fixture differs from the new managed values, so a no-op activation cannot pass.

---

## Verification Contract

- Run Markdown lint, `git diff --check`, and `nix fmt -- --ci` before publication.
- Build `checks.x86_64-linux.agent-instructions` and `checks.x86_64-linux.codex-settings` locally; use the existing instruction mutation controls and divergent activation fixture as the primary behavior evidence.
- Evaluate the flake and obtain all declared checks, VM checks, and production/bootstrap host outputs required by repository policy before declaring readiness; current-head CI may supply supported-platform evidence.
- Report unavailable platform builders and authenticated runtime or hardware checks separately, without treating a missing result as a pass.
- Do not activate the configuration on the user's machine as validation.

---

## Definition of Done

- U1 and U2 meet their verification outcomes and R1 through R9 hold.
- Review findings are assessed and every substantiated fix is applied, with any unapplied findings recorded using repository disposition tags.
- The complete branch diff passes local applicable checks; the PR records local and CI evidence separately.
- Remove abandoned experimental edits and scratch artifacts from the branch.
- Publish an open PR and leave merging to the user; readiness requires the repository's current-head CI and platform evidence.
