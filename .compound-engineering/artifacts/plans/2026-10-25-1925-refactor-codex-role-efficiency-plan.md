---
title: Reduce Codex worker effort and accelerate Luna
date: 2026-10-25
type: refactor
topic: codex-role-efficiency
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# Reduce Codex worker effort and accelerate Luna

## Goal Capsule

- **Objective:** Reduce waiting and resource consumption in routine Codex work without increasing rework or weakening substantive verification.
- **Means:** Lower routine worker effort and use priority for Luna roles.
- **Product authority:** The user confirmed the revised role table on 2026-10-25 after explicitly retaining Astra low as the default root.
- **Open blockers:** None for implementation planning; actual efficiency gains remain to be measured.

---

## Product Contract

### Summary

Use Luna low with priority for bounded retrieval and Sol low with Standard for ordinary execution.
Preserve the current root and complex-work profiles, and keep independent review requirements intact.

### Problem Frame

The current policy assigns medium effort to both routine Sol work and substantive verification, while every default GPT role uses Standard.
The user wants lower model and effort overhead and explicitly requests Luna priority.
No local timing or allowance baseline was supplied, so expected savings are a hypothesis rather than a measured result.

### Key Decisions

- **Keep the existing root.** (session-settled: user-directed — chosen over Sol low as the default root: the user explicitly retained Astra low after seeing the lower-model alternative.) Governs R1, R2.
- **Lower routine worker effort.** (session-settled: user-approved — chosen over retaining medium for routine workers: reduce overhead while keeping complex verification separate.) Governs R1, R3, R4.
- **Authorize Luna priority.** (session-settled: user-approved — chosen over Standard for Luna: accelerate bounded workers with the higher subscription-usage tradeoff disclosed.) Governs R1, R5, R6.
- **Do not add Luna max as a default.** (session-settled: user-approved — chosen over replacing ordinary Sol workers with Luna max: published results show much more token generation and weaker terminal-task performance.) Governs R1, R7.

### Requirements

**Role selection**

- R1. Apply the following default profiles only to Codex orchestration, including Codex-led T3 sessions, subject to existing scoped user overrides and applicable skill constraints.

| Profile | Responsibility | Model | Effort | Service | Change from current policy |
| --- | --- | --- | --- | --- | --- |
| P1 | Exact lookup, fixed-field extraction, status | `gpt-6-luna` | low | priority | Standard to priority |
| P2 | Bounded retrieval, classification, evidence summaries | `gpt-6-luna` | low | priority | medium to low; Standard to priority |
| P3 | Ordinary implementation, writing, straightforward verification | `gpt-6.1-sol` | low | Standard | medium to low |
| P4 | Complex diagnosis, substantive review, security, concurrency, data integrity | `gpt-6.1-sol` | medium | Standard | Unchanged |
| P5 | Root orchestration, delegation, progress | `gpt-6-astra` | low | Standard | Unchanged |
| P6 | Complex architecture, conflicting evidence, high-risk decisions | `gpt-6-astra` | medium | Standard | Unchanged |
| P7 | CE-required independent external review | CE-selected external model | CE-prescribed effort | Provider default | Unchanged |

- R2. Preserve native Codex and T3 new-session root defaults at P5, including existing precedence for explicit and persisted selections.
- R3. Align the native generic child fallback with P3 without replacing role-specific routing.
- R4. Route interpretation beyond bounded extraction to the appropriate Sol role, selecting P4 from the start for complex or safety-sensitive work.

**Service tier and escalation**

- R5. Treat priority for P1/P2 as standing user authorization when the selected route supports it, without extending that authorization to root, Sol, or external peers.
- R6. When native child tier cannot be independently controlled, preserve the root tier and report the unmet Luna priority request rather than accelerating the root or claiming independent control.
- R7. Do not introduce default high, xhigh, max, or ultra effort; retain existing restrictions on discretionary increases and Ultrafast.
- R8. Reassign substantive unresolved interpretation or verification failures to the appropriate higher role with the unresolved question and evidence recorded; transient network errors, malformed tool arguments, and queue delays do not justify an increase.
- R9. Preserve existing skill ownership, delegation triggers, permissions, recipient restrictions, review coverage, and artifact contracts while applying R1-R8.
- R10. Continue using ChatGPT-authenticated Codex for ordinary work without automatic purchases or separately billed API fallback.

### Acceptance Examples

- AE1. **Covers R1, R5.** A T3 task collecting exact repository facts requests Luna low/priority and reports whether the returned configuration matches.
- AE2. **Covers R3, R4.** An ordinary implementation uses Sol low; a concurrency defect is assigned Sol medium without first requiring a failed low-effort attempt.
- AE3. **Covers R2, R6.** A native session with an Astra low/Standard root cannot independently accelerate a child; the root stays Standard and the limitation is disclosed.
- AE4. **Covers R8.** A failed network request is retried under the existing tool policy without increasing effort; contradictory implementation evidence triggers a justified reassignment.
- AE5. **Covers R1, R7, R9.** A required external review retains its prescribed identity and effort instead of inheriting the cheaper ordinary-worker profile.

### Success Criteria

- Declared and observed selections agree for supported routes; unsupported independent tier selection is reported as a limitation.
- Compare representative retrieval, implementation, and review work against the current profiles, recording elapsed time, available usage evidence, retries, reassignment, and missed defects.
- Treat public API benchmarks as selection evidence, not proof of Codex subscription savings or production completion time.
- Report measured gains and regressions separately; do not declare the optimization successful from configuration changes alone.

### Scope Boundaries

- Change the Codex role policy and native generic child fallback; preserve root defaults per R2.
- Do not broaden delegation permissions or change other harnesses' general orchestration behavior, per R9.
- Do not add a permanent benchmark service, dashboard, scheduler, automatic quota scraping, or paid fallback.
- Preserve historical plans and learnings as records; this document defines the new deltas.

### Evidence and Assumptions

Repository claims were checked at revision `00f0fa1806a8abe1472aedb15a21df4c54029d5d`.
The current profile source is `home/h82/agents/instructions/instructions.md.tmpl:91`; native defaults are in `home/h82/agents/codex.nix:23`, and T3 defaults in `home/h82/t3code.nix:169`.
These declarations do not establish that activation or client selection has applied them at runtime.

The historical 2x adoption criterion concerned a Sol review-peer proposal, not a demonstrated blanket limit on Luna tasks.
See `.compound-engineering/artifacts/solutions/best-practices/codex-priority-tier-costs-2-5x-subscription-usage-for-review-peer.md`.
R5 is a newly approved standing policy, not a claim that a universal numeric limit previously existed.

As read on 2026-10-25, [Artificial Analysis's direct comparison](https://artificialanalysis.ai/models/comparisons/gpt-6-1-sol-low-vs-gpt-6-luna) reports Sol low/Luna max Intelligence Index scores of 42/38, Terminal-Bench 4.0 scores of 31%/13%, and weighted API costs per task of $0.13/$0.07.
Its output-token estimates are 4k/50k per task; these do not measure Codex subscription usage or Luna priority performance.
[OpenAI's speed documentation](https://learn.chatgpt.com/docs/agent-configuration/speed) states that Fast consumes included subscription usage at 2.5x Standard.

T3 advertised Luna priority and accepted a Luna medium/priority grounding task in this session.
That receipt establishes requested/returned selection, not serving attestation or a speed improvement, and does not validate the proposed low-effort workload.

---

## Planning Contract

### Key Technical Decisions

- KTD1. Update the existing Codex-only template section and the existing native child effort declaration in place. Keep model names, root startup settings, renderer, delivery paths, and T3 defaults unchanged. Implements R1-R3 and R9.
- KTD2. State the P1/P2 standing Fast authorization before the general conditional Fast rule, and explicitly cover unavailable native child priority. Preserve general acceleration restrictions for other roles. Implements R5-R8.
- KTD3. Reuse the materialized-instructions check and activation-execution settings check rather than adding a duplicate source-string guard. Change the existing settings fixture's child effort to a value different from the new expected low, so skipped application cannot pass by coincidence. Implements R1-R3 and R9.
- KTD4. Use a bounded paired smoke comparison for retrieval and a small scratch implementation, plus the substantive code-review result, to report timing and retry observations. Do not infer allowance consumption from API prices or promote a small sample to a benchmark. Implements the Success Criteria.

### Assumptions and Runtime Limits

The existing settings merger and delivery paths already implement this configuration pattern; this work changes values and policy, not their transport.
No new external interface or enforcement mechanism is introduced.
Native child service-tier independence remains unsupported unless the installed client supplies contrary evidence; R6 defines the fallback without requiring a client upgrade.
Runtime comparisons use explicit task options and bounded temporary artifacts, without applying this flake to the developer's machine.

## Implementation Units

### U1. Update worker defaults and their documented contract

- **Goal:** Deliver the approved profiles through the existing configuration and instruction owners.
- **Requirements:** R1-R10; AE1-AE5.
- **Dependencies:** None.
- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`, `home/h82/agents/codex.nix`, `docs/provisioning.md`, `tests/codex-settings.nix`.
- **Approach:** Apply KTD1-KTD3 and update provisioning prose to distinguish ordinary Sol low from P4 medium, Luna priority authorization, and the native fallback.
- **Execution note:** Inspect the existing activation test before editing it; preserve a distinct stale value in its seed and verify materialized output rather than adding source greps.
- **Test scenarios:** A stale medium child effort becomes low while root remains Astra low/default and unrelated TOML fields survive. Rendered Codex instructions carry the approved role table while the other three deliveries retain their common policy.
- **Verification:** Existing affected checks pass on supported builders; no unrelated settings or skill contracts change.

### U2. Verify selection behavior and record bounded efficiency evidence

- **Goal:** Distinguish correct policy delivery from actual model selection and observed efficiency.
- **Requirements:** R1-R9 and Success Criteria; AE1-AE5.
- **Dependencies:** U1.
- **Files:** `docs/verification.md` for dated evidence; temporary comparison artifacts remain outside the repository.
- **Approach:** Run KTD4 with the same task and repository revision for each pair: bounded extraction at Luna medium/Standard versus low/priority, and a disposable implementation at Sol medium/Standard versus low/Standard. Retain requested/returned selections, elapsed time, retries, reassignment, and correctness results. Use substantive review at P4 as unchanged review coverage and state that no review-profile speedup is claimed.
- **Test expectation:** No new permanent benchmark suite; this unit records bounded runtime observations and limitations.
- **Verification:** Report missing usage telemetry as unavailable, retain failures as evidence, and avoid claims about serving identity or independent native priority that the route cannot attest.

## Verification Contract

- Run Markdown lint, whitespace checks, and supported formatting checks on the complete branch diff.
- Run the existing `agent-instructions`, `codex-settings`, and `claude-effort-absent` checks where available; use supported native Darwin evaluation/materialization for local evidence and leave Linux-only checks to CI when no Linux builder is available.
- Verify the changed child effort check fails when the old medium declaration is restored in an isolated scratch checkout, without copying a live worktree's `.git` pointer.
- Confirm the current Codex app-server can read a synthetic scratch configuration with the new native fallback; never display authentication data or alter live user settings.
- Record U2 results separately from repository checks, including the native child-tier limitation.
- Before merge readiness, require current-head flake evaluation, all declared checks, VM tests, and all production/bootstrap host outputs per `docs/verification.md`; publication may precede unavailable platform evidence.

## Definition of Done

- U1 and U2 satisfy the approved Product Contract without changing the root default.
- Relevant local checks pass and platform-deferred checks are recorded accurately.
- Simplification and code review are complete, with every finding assessed and valid fixes applied.
- The PR contains behavior changes, verification evidence, efficiency limitations, and any unapplied findings; merge remains the user's action.
