---
title: Apply Every Review Finding - Plan
type: docs
date: 2026-09-28
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Apply Every Review Finding - Plan

## Goal Capsule

- **Objective:** An agent working in this repository applies every finding that `ce-code-review` and `ce-simplify-code` report, at every severity, instead of leaving any as a deferred residual.
- **Means:** Rewrite the existing review-findings rule in `AGENTS.md` so it names both skills, their severity and routing vocabulary, and the skill defaults it overrides (KTD1, KTD2).
- **Authority:** the user's request, then this plan's Requirements, then KTDs. The rest of `AGENTS.md`, especially its security and lifecycle constraints, still binds every applied fix.
- **Stop conditions:** stop if the new wording would contradict another `AGENTS.md` rule that the user has not asked to change.
- **Execution profile:** one docs-only edit; verified by markdown lint and `nix flake check`.
- **Who finishes and ships:** the implementing agent opens the PR under the repo's commit and PR conventions.

## Product Contract

### Summary

Replace the `AGENTS.md` sentence "Always apply all review findings..." with a rule that covers all P0-P3 findings from `ce-code-review`, every `autofix_class` including `manual` and `advisory`, and the findings `ce-simplify-code` would otherwise skip as low-value. The rule names the few exceptions, and each exception must be reported with its reason.

### Problem Frame

The current rule says to apply all review findings. The two skills and the `lfg` pipeline still ship defaults that leave findings unapplied. `ce-code-review`'s severity table marks P2 as "Fix if straightforward" and P3 as "User's discretion". Its `advisory` class is report-only. `lfg`'s step 5 applies only mechanical, high-confidence `suggested_fix` findings and moves the rest into a PR-body residual list. `ce-simplify-code` records low-value findings as skipped. The rule does not name these defaults, so an agent following a skill's own text can still defer P2 and P3 findings. The user wants them applied.

### Requirements

**Coverage**

- R1. The rule applies to findings from `ce-code-review` and `ce-simplify-code`, whether invoked directly or inside another workflow such as `lfg`.
- R2. Every severity from P0 through P3, and anything lower, is applied on the branch; severity sets only the order of work.
- R3. Every `autofix_class` is in scope: `gated_auto` fixes are applied, `manual` findings are resolved by choosing a defensible fix and implementing it, and `advisory` findings that name a concrete change are applied. The same holds for `ce-code-review`'s secondary `testing_gaps` and `residual_risks` lists: an entry that names a concrete change, such as a missing test or check, is applied.
- R4. `ce-simplify-code` findings are applied even when the skill would call them low-value, as long as the change keeps behavior.

**Override and exceptions**

- R5. The rule states that it overrides the skills' defaults: the P2/P3 action column, the report-only reading of `advisory`, the whole of `lfg`'s step-5 eligibility bar (including its `suggested_fix`, confidence, mechanical-fix, and contract or behavior-change exclusions), and the use of the residual handoff for findings that are merely hard or low-priority. It also names `ce-code-review`'s report-only default: a bare or `mode:agent` run does not apply anything, so the invoking agent applies every finding itself on the branch after the review returns.
- R6. A finding stays unapplied only when it is a false positive verified against the code, when the fix would change behavior or remove a safety check that `ce-simplify-code` must keep, when the agent cannot establish that a `ce-simplify-code` fix preserves outputs, errors, side effects, and ordering, when a `ce-simplify-code` fix would edit outside the scope the user named for that run, when it conflicts with a user-settled decision or with `AGENTS.md`'s security and lifecycle constraints, or when it needs an irreversible action the user did not grant.
- R7. Each unapplied finding, and each `testing_gaps` or `residual_risks` entry that names no change, is reported with its exception or reason and the evidence; an unapplied finding with no named exception counts as a defect in the run. In `lfg`, the report goes through step 6's `## Unapplied review findings` PR-body section, or through tickets and the DONE report when no PR exists, and that section lists only R6 exceptions.
- R8. Applied fixes are verified with the same checks the repo requires before shipping.

### Scope Boundaries

- The shared Home Manager instruction template (`home/h82/agents/instructions/instructions.md.tmpl`) is unchanged; see Assumptions.
- The installed plugin skills under `~/.local/share/agent-plugins/` are not edited; the repo instruction overrides them.
- The PR-watching paragraph that follows the rule in `AGENTS.md` is unchanged.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Rewrite the existing paragraph in place instead of adding a second rule.** The rule already lives in `## Commit and pull request guidelines`; a second paragraph would split one rule across two owners. Governs R1-R8.
- KTD2. **Name the skill vocabulary exactly (`P0`-`P3`, `gated_auto`, `manual`, `advisory`, `testing_gaps`, `residual_risks`, `mode:agent`, "low-value", residual handoff).** An agent reading a skill's own text sees these terms, so an override has to use the same words to be recognized as covering them. Governs R2-R5.
- KTD3. **List the exceptions as a closed set and require a report for each.** An open-ended "unless infeasible" would let any deferral pass as an exception; a closed list plus a reporting duty keeps deferrals visible. Governs R6, R7.

### Assumptions

- The user means this repository's agent instructions (`AGENTS.md`, loaded through `CLAUDE.md`), where the rule already exists. The global template renders tool-use guidance for every project and has no review rule, so extending it would be a separate change the user can request.
- A finding whose fix changes a contract, a permission, or user-visible behavior is applied like any other, because the request asks for every finding to be applied; a change that would weaken a security stance is already covered by the `AGENTS.md` security exception in R6.
- Confidence tiers are not an exception: a lower-confidence finding is checked against the code, then applied or reported as a verified false positive under R6.

---

## Implementation Units

### U1. Rewrite the review-findings rule in `AGENTS.md`

- **Goal:** Replace the single sentence rule with the stronger rule.
- **Requirements:** R1-R8, KTD1-KTD3.
- **Dependencies:** none.
- **Files:** `AGENTS.md`.
- **Approach:**
  1. Replace the paragraph that begins "Always apply all review findings." in `## Commit and pull request guidelines`.
  2. Open with the direct rule, then state the overrides (R5), then the closed exception list (R6) and the reporting duty (R7), then verification (R8).
  3. Keep the existing sentence about failure modes, regressions, and edge cases in substance.
  4. Use short bullets for the exception list if prose gets long; match the file's plain, imperative voice.
- **Patterns to follow:** the neighbouring PR-watching paragraph, which overrides a skill instruction by naming it ("this supersedes that skill's instruction ...").
- **Test expectation:** none -- instruction text only; no behavior under test. Lint and flake checks cover formatting.
- **Verification:** the rule names both skills, every severity, all three `autofix_class` values, the `testing_gaps` and `residual_risks` lists, the `ce-simplify-code` low-value skip, the report-only default of a bare or `mode:agent` `ce-code-review` run, and `lfg`'s step-5 bar and residual handoff; markdown lint passes.

---

## Verification Contract

| Gate | Command | Applies |
| --- | --- | --- |
| Markdown lint | `markdownlint-cli2` (run by the `markdown-lint-tests` flake check) | U1 |
| Flake checks | `nix flake check` | U1 |
| Host builds | build every `nixosConfigurations` output as `AGENTS.md` lists | before shipping, per `AGENTS.md` |

## Definition of Done

- `AGENTS.md` carries the rewritten rule meeting R1-R8, and no other paragraph changed.
- `nix flake check` passes.
- No leftover draft text or duplicate rule remains in the diff.
