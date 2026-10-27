---
title: Early Research Delegation - Plan
type: feat
date: 2026-10-27
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Early Research Delegation - Plan

## Goal Capsule

- Objective: Users receive a consolidated, evidence-backed answer while separable parts of substantial research and triage are investigated concurrently.
- Means: Add an early delegation policy to the shared agent instructions.
- Authority: The current request and its chosen early-delegation behavior govern scope; existing skill ownership, permissions, and runtime restrictions remain binding.
- Execution profile: One bounded instruction change, implemented and verified in the current checkout, followed by review and an open PR. The user performs the merge.
- Stop conditions: Report unavailable mandatory verification or an invalidated user decision without claiming readiness.

## Product Contract

### Summary and Problem Frame

The common instructions describe roles and dispatch rules but do not tell agents when to initiate delegation. Research requiring several searches and source comparisons, and triage with several plausible causes, can consequently remain entirely serial.

### Requirements

- R1. At the outset of substantial research or triage, identify independently answerable questions and delegate useful separable investigations without waiting for the task to become slow.
- R2. Use the work's shape to decide: multiple sources requiring comparison, datasets requiring reconciliation, or distinct plausible causes are signals; elapsed time or tool-call count alone is not.
- R3. Give each child a bounded question, relevant context, and an expected return containing evidence, conclusions, and uncertainty. Avoid duplicating the child's investigation in the root.
- R4. The root integrates results, resolves conflicting evidence, and remains responsible for user communication and the final conclusion. Apply existing parallel-dispatch rules to independent work.
- R5. Keep simple lookups and indivisible dependent reasoning local. Preserve explicit delegation restrictions, skill-defined ownership and sequencing, model routing, and recipient permissions.

### Key Decision

Initiate delegation early when useful independent questions exist (session-settled: user-directed — chosen over waiting for complexity to emerge or delegating every nontrivial lookup: start separable investigations promptly without unnecessary delegation). Governs R1, R2, R5.

### Scope Boundaries

This change covers the shared policy for Claude Code, Codex, and OMP. It does not introduce a new scheduler, model roster, agent-count quota, elapsed-time threshold, or tool transport. These mechanisms are unnecessary for the requested instruction change.

## Planning Contract

- KTD1. Put the policy in a common subsection of `home/h82/agents/instructions/instructions.md.tmpl`, before harness-specific branches. Keep the existing role table as the routing authority; adjust its introductory permission wording only if needed to distinguish the new policy from role selection. Implements R1-R5.
- KTD2. Add a concise explanation to `docs/agent-routing.md` so readers can distinguish delegation triggers from model routing. Do not duplicate model tables or modify model choices.
- KTD3. Update the existing expected routing content in `tests/agent-instructions.py` to admit the new subsection without relaxing its whole-section comparison or existing permission guards. Use the materialized instruction-delivery check and manual scenario review; do not add separate literal sentence tests that would only repeat the existing prompt-byte boundary.

### Assumptions and Limits

The policy operates within each harness's available delegation tools and higher-priority instructions. Rendering checks establish delivery, not future model compliance. No quantitative latency improvement is claimed.

## Implementation Units

### U1. Add and document the early delegation policy

- Goal: Make R1-R5 available in all three delivered instruction files.
- Requirements: R1-R5; the Key Decision governs timing.
- Dependencies: Existing template renderer and delivery configuration.
- Files: `home/h82/agents/instructions/instructions.md.tmpl`, `docs/agent-routing.md`, `tests/agent-instructions.py`.
- Approach: Follow KTD1-KTD3 using the existing imperative bullet style and common-section layout.
- Patterns: `home/h82/agents/instructions/default.nix` renders the common template once for each harness; `tests/agent-instructions.nix` checks materialized Home Manager files.
- Test scenarios: A multi-source investigation has bounded independent questions; a multi-cause triage separates evidence gathering; a single lookup stays local; sequential reasoning is not artificially split; an invoked skill retains its reserved responsibilities; an explicit runtime prohibition prevents dispatch.
- Verification: Inspect each rendered variant for the shared policy, update the existing routing expectation, run the affected delivery check and its existing negative controls, and inspect the scenarios against the complete instruction hierarchy. No new test file is required.

## Verification Contract

- Run `git diff --check` and the repository Markdown lint for changed Markdown, including the plan.
- Run the affected `agent-instructions` check on a supported builder; native Darwin instruction delivery is included in `checks.aarch64-darwin.darwin-outputs`.
- Before readiness, obtain flake evaluation, all declared checks, VM tests, and every production/bootstrap host output as required by `AGENTS.md`. Local Darwin results and Linux/ARM CI evidence must be reported separately.
- Use the complete branch diff to assess CI path filters. This runtime-template change is not inert documentation.
- Report scenario inspection and rendered delivery separately from live authenticated agent behavior; do not claim that a build proves actual delegation decisions.

## Definition of Done

U1 satisfies R1-R5 in the common rendered policy and documentation. Required checks pass on the PR head, review findings are assessed and resolved or recorded, and the PR is open for the user's merge. No host activation is needed for validation.
