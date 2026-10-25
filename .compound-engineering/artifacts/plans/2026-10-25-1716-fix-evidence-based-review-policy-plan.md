---
title: Evidence-based review policy - Plan
type: fix
date: 2026-10-25
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# Evidence-based review policy - Plan

## Goal Capsule

Replace compulsory application of every review comment with evidence-based adjudication in the shared agent instructions and this repository's matching policy. The user authorized implementation, verification, review, and an open PR; merging and machine activation remain outside this work.

## Product Contract

### Summary

Agents assess every review finding and fix substantiated problems. They may reject unsupported speculation, preference-only comments, and refactors without concrete benefit, recording a brief reason instead of asking permission for every rejection.

### Problem Frame

The current policy forces agents to implement even implausible concerns and explicitly forbids several grounds for judging whether a change has value. Adding a separate complexity-approval rule would leave contradictory obligations.

### Key Decisions

- **Replace unconditional application with adjudication.** Governs R1-R4. (session-settled: user-directed — chosen over adding approval around the existing mandatory-fix rule: reduce unjustified changes at their source.)
- **Include taste-only and benefit-free refactoring suggestions among exclusions.** Governs R2. (session-settled: user-approved — chosen over limiting exclusions to speculative failures: avoid unnecessary churn.)

### Requirements

- R1. Assess every finding from review, verification, or check steps, including testing gaps and residual risks; fix substantiated defects and requirement violations in the same change regardless of severity labels.
- R2. Permit reasoned rejection of factually wrong findings, assumptions outside supported behavior, implausible speculative failure chains, taste without a project-rule or clarity rationale, and refactors without concrete benefit.
- R3. Base judgments on the actual code, supported behavior, failure path, impact, and change cost. Rarity alone does not dismiss a credible security or data-loss defect; code reasoning can substantiate a defect without a reproducer.
- R4. Record unapplied findings with concise evidence and explicit dispositions, without routine approval requests. Preserve safety exceptions, the user's decisions, review-only consent, and the existing requirement to ask before reversing a user decision.
- R5. Keep the shared template, repository policy, glossary, provisioning and verification documentation, and delivered-instruction check consistent with R1-R4.

### Acceptance Examples

- AE1. Covers R1/R3: a reachable data-loss race supported by code analysis is fixed even when no reproduction exists and its frequency is unknown.
- AE2. Covers R2/R4: a speculative multi-failure scenario without a credible supported execution path is rejected with that reason.
- AE3. Covers R2: a rename requested only for reviewer taste or a new abstraction without concrete benefit is rejected; an established naming-rule violation or demonstrated clarity problem remains actionable.
- AE4. Covers R4: a fix reversing an explicit user choice still requires the user's decision when a person is present.

## Planning Contract

### Key Technical Decisions

- KTD1. Update the existing Review findings section and its repository counterpart together; keep delivery through the current common template and Codex conditional unchanged. Implements R5.
- KTD2. Extend the existing independent prompt-policy expectations and their deletion, negation, and repetition controls in `tests/agent-instructions.py`. Do not add a new check or claim that string checks prove model behavior. Implements R1-R5.

### Scope Boundaries

No changes to models, orchestration, encryption, host activation, or the installed CE skills. No probabilistic risk scoring system or approval workflow is introduced.

## Implementation Units

### U1. Align policy and documentation

**Requirements:** R1-R5. **Dependencies:** none.

**Files:** `home/h82/agents/instructions/instructions.md.tmpl`, `AGENTS.md`, `CONCEPTS.md`, `docs/provisioning.md`, `docs/verification.md`.

**Approach:** Follow KTD1, replacing contradictory mandatory-application clauses and updating the disposition vocabulary and manual verification guidance.

**Test scenarios:** Review the resulting policy against AE1-AE4; confirm each excluded category has a documented evidence requirement and no old unconditional-application override remains in active policy.

**Verification:** All active descriptions express the same decisions and preserve the retained safeguards.

### U2. Verify delivered policy

**Requirements:** R1-R5. **Dependencies:** U1.

**Files:** `tests/agent-instructions.py`.

**Approach:** Follow KTD2 using the current materialized-delivery boundary and independent policy sentences. Preserve unrelated policy checks.

**Test scenarios:** Updated expectations reject the old policy; the new policy passes; deletion, negation, and repetition of the required review-policy sentences fail for the intended reason. Both common and Codex deliveries retain the new policy.

**Verification:** Run the check's Python controls and supported materialized Nix checks. Exercise AE1-AE4 through a bounded scenario review, separately reported from build evidence.

## Verification Contract

Run `git diff --check`, changed-Markdown lint, and `nix fmt -- --ci`. Use `tests/agent-instructions.py` for targeted baseline and mutation evidence; build `checks.aarch64-darwin.darwin-outputs` on this Mac and obtain Linux `agent-instructions` evidence from CI. This changes runtime instructions, so apply the full publishing-and-merge-readiness requirements in `docs/verification.md`: flake evaluation, declared checks, VM tests, and every production/bootstrap output must have successful evidence before readiness. Unavailable platforms stay pending; no machine activation is authorized.

## Definition of Done

U1 and U2 satisfy R1-R5, targeted checks and scenario review pass, required review findings are adjudicated with evidence, and the PR records local and CI results separately. No abandoned experiments remain. Hardware behavior and installed-session uptake are not inferred from builds.
