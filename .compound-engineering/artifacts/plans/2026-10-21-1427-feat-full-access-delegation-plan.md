---
title: Full Access Delegation for T3 Code Child Tasks - Plan
type: feat
date: 2026-10-21
topic: full-access-delegation
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Full Access Delegation for T3 Code Child Tasks - Plan

## Goal Capsule

- **Objective:** A delegated T3 Code task launched in Full Access never stalls on an approval nobody sees, and the agent mentions "Subagent needs approval" only while a task it launched without Full Access still runs, instead of in every orchestration session.
- **Means:** The shared agent instructions launch every `delegate_task` child with `runtimeMode: "full-access"`, relaunch with the inherited mode only when T3 Code rejects that mode, and keep the approval note for those inherited-mode tasks alone (KTD1-KTD3).
- **Product authority:** The settled decisions below, made in this session's brainstorm. The Planning Contract decides how; it does not change product scope.
- **Execution profile:** Lightweight. Pinned instruction text, its check, one provisioning paragraph, one verification item, and one learning.
- **Open blockers:** None.
- **Stop conditions:** Stop and report when the `agent-instructions` check cannot be made to pass without weakening an assertion, or when a rendered instruction file still carries the old unconditional approval note.
- **Finish:** The implementation pipeline opens the pull request. The user merges. Do not apply the generation on the live machine as validation.

---

## Product Contract

### Summary

Every delegated task in a T3 Code session asks for Full Access, so it does not pause for approvals.
When T3 Code refuses that mode, the agent relaunches the task with the mode it would have inherited.
The "Subagent needs approval" note appears only while such an inherited-mode task still runs.

### Problem Frame

The `# T3 Code` section of `home/h82/agents/instructions/instructions.md.tmpl` tells the agent, every time it ends a turn with tasks still running, to say that a task paused on an approval shows "Subagent needs approval" and waits for the user.
The agent prints that note in every orchestration session, even though the user runs sessions in Full Access and no child has paused.
`delegate_task` leaves `runtimeMode` unset by default, so a child inherits the parent's mode, and an inherited mode steps down to the broadest mode the target provider offers, which can be one that asks for approval.
The user wants children launched in Full Access explicitly and the note gone when it cannot apply.

### Key Decisions

- **Every delegated task requests Full Access.** (session-settled: user-directed — chosen over leaving `runtimeMode` unset to inherit the parent's mode: children should never wait on approvals, and the approval note should go.) Governs R1.
- **A rejected Full Access launch is relaunched with the inherited mode.** (session-settled: user-directed — chosen over doing the work directly or leaving the task failed: delegation should still happen under a parent that runs below Full Access.) Governs R2.
- **The approval note stays only for inherited-mode tasks.** (session-settled: user-directed — chosen over never printing the note: an inherited-mode child can still pause where nobody sees it.) Governs R3.

### Requirements

**Launch mode**

- R1. In a T3 Code session, the agent launches every delegated task, cross-model peers and `ce-work` implementation units included, with `runtimeMode: "full-access"`.
- R2. When `delegate_task` rejects that mode, the agent relaunches the task once without `runtimeMode`, so it inherits the thread's mode.

**Approval note**

- R3. When the agent ends its turn with tasks still running, it names them, and it adds the "Subagent needs approval" note only when one of them was launched without `runtimeMode: "full-access"`.

**Checks and docs**

- R4. The `agent-instructions` check pins the new sentences, fails on the old unconditional note, and fails when a launch-mode rule appears outside the pinned sections.
- R5. `docs/provisioning.md`, `docs/verification.md`, and the delegation-wait learning describe the new launch mode and the narrowed note.

### Acceptance Examples

- AE1. **Covers R1, R3.** In a Full Access Claude Code session in T3 Code, `ce-code-review` launches its Antigravity and Grok peers. Both launch with `runtimeMode: "full-access"`, and when the agent ends its turn to wait, it names the two peers and says nothing about "Subagent needs approval", because every task still running was launched with `runtimeMode: "full-access"`.
- AE2. **Covers R2, R3.** In a session whose thread runs in Supervised mode, a `delegate_task` call with `runtimeMode: "full-access"` is rejected because that mode ranks above the thread's. The agent relaunches the task without `runtimeMode` under a new `clientRequestId`, and when it ends its turn, it names the task and adds the approval note.
- AE3. **Covers R2.** A target provider rejects `full-access` because it does not offer it. The agent relaunches without `runtimeMode` rather than moving to the category's fallback worker.

### Scope Boundaries

- Changing T3 Code or any provider's runtime modes.
- Answering a child's approval from the parent; `delegate_task` grants the parent no approval authority.
- Making children read-only through a runtime mode; the read-only instruction stays in the task prompt. Before this change a child already inherited the parent's Full Access in the user's sessions, so a read-only scout or peer was already bounded by its prompt, not by approvals; cross-model peers additionally run in their own worktree. Full Access never exceeds the parent's own mode, because T3 Code rejects a mode ranked above the parent's.
- Rewriting the 2026-10-19 notification-wait plan, which records the reasoning of its time; the learning and docs carry the current behavior.

### Dependencies / Assumptions

- `delegate_task` rejects a requested `runtimeMode` that ranks above the parent thread's or that the target provider does not list, per its tool description. A rejected launch creates no task. A probe in this session confirmed the shape: `runtimeMode: "auto-accept-edits"` on `grok` returned an `invalid_request` error whose message names the runtime mode ("Provider grok does not offer runtime mode auto-accept-edits, so it would run as approval-required. Use one of: approval-required, auto, full-access."). T3 Code refuses rather than silently running the child in a narrower mode.
- `orchestrator_capabilities` lists `runtimeModes` for `grok` (`approval-required`, `auto`, `full-access`) and `opencode`, and lists none for `claudeAgent` and `antigravity`. Probes from a Full Access thread launched `claude-haiku-5-5` on `claudeAgent` and `gemini-3.8-flash` on `antigravity` with `runtimeMode: "full-access"`; both were accepted, and `t3_thread_configuration` on each child thread reported `runtimeMode` `full-access`. An unlisted set therefore does not block Full Access, so R2 runs only under a parent below Full Access or on a provider that lists modes without `full-access`.

### Sources / Research

- `home/h82/agents/instructions/instructions.md.tmpl` (`# T3 Code` and `# Compound Engineering` sections).
- `tests/agent-instructions.nix` (`t3CodeSentences`, `confinedTerms`, `selfTestMutants`).
- `docs/provisioning.md` (the T3 Code delegation paragraph) and `docs/verification.md` (the T3 Code items).
- `.compound-engineering/artifacts/solutions/integration-issues/t3-thread-wait-cannot-carry-in-turn-delegation-waits-alone.md`.
- `.compound-engineering/artifacts/plans/2026-10-19-1736-feat-t3-code-notification-delegation-wait-plan.md` (R14 and its "children inherit the parent's runtime mode" note).
- The `delegate_task` and `orchestrator_capabilities` tool descriptions and output in this T3 Code session (thread `runtimeMode` `full-access`).

---

## Planning Contract

**Product Contract preservation:** Product Contract unchanged; the open areas the brief carried are resolved by KTD2-KTD4.

### Key Technical Decisions

- KTD1. **One launch-mode rule in `# T3 Code`, placed directly before the launch-failure rule.** It says to launch every delegated task, cross-model peers and implementation units included, with `runtimeMode: "full-access"`, so it never pauses on an approval nobody sees. A rule in the T3 Code section reaches the peer and `ce-work` launches without editing each of those sentences. Implements R1; inherits the first Key Decision.
- KTD2. **The inherited relaunch takes a new `clientRequestId` and is not a launch failure under any rule.** The agent recognizes a mode rejection as a `delegate_task` error that names the runtime mode (see Dependencies / Assumptions). A mode rejection is a deterministic refusal, so replaying the same request could return the same rejection, and a rejected launch creates no task, so a new id cannot duplicate one. The rule says such a rejection is not a failed or unavailable launch for any rule in these instructions: not the one retry the launch-failure rule allows, not the `ce-work` move to a category's fallback worker, and not a failed cross-model peer. A later failure of the inherited launch still gets those rules. Implements R2; inherits the second Key Decision.
- KTD3. **The note sentence is conditioned on how the task was launched, not on the thread's mode.** The agent knows which tasks it relaunched without `runtimeMode`; it cannot see whether an inherited mode stepped down. The sentence names the tasks still running and adds the note when one of them runs without `runtimeMode: "full-access"`. Implements R3; inherits the third Key Decision.
- KTD4. **`runtimeMode` joins `confinedTerms`.** A rule naming `runtimeMode` under any heading other than the two pinned sections then fails the check, so a later rule cannot quietly restore inheritance or request a supervised mode. Three self-test mutants prove the guard, following the existing removed-and-negated pair for the prohibition sentence: the launch-mode sentence removed, the launch-mode sentence negated, and a `runtimeMode` rule added under `# Git`. Implements R4.

### Assumptions

- The pipeline ran without a scoping confirmation for this plan. The inferred bets are KTD2's new `clientRequestId` for the inherited relaunch and KTD4's guard.

### Sequencing

U1 lands first; U2 describes the text it produces.

---

## Implementation Units

### U1. Full Access launch rule and narrowed approval note

**Goal:** Every rendering of the shared instructions carries the launch-mode rule, the inherited relaunch, and the narrowed note, and the check guards them.

**Requirements:** R1, R2, R3, R4; KTD1, KTD2, KTD3, KTD4.

**Dependencies:** None.

**Files:**

- `home/h82/agents/instructions/instructions.md.tmpl`
- `tests/agent-instructions.nix`

**Approach:**

1. In `# T3 Code`, insert directly before the "When a `delegate_task` launch fails" sentence two sentences: the KTD1 launch rule, then the KTD2 relaunch rule (a `delegate_task` error that names the runtime mode, because the thread runs below Full Access or the target provider does not offer it; relaunch once without `runtimeMode` under a new `clientRequestId`; such a rejection is not a failed or unavailable launch under any rule in these instructions, the launch-failure retry, the `ce-work` fallback worker, and a failed peer included).
2. Replace the "When you end your turn while tasks still run" sentence with the KTD3 form: name the tasks, and when one of them runs without `runtimeMode: "full-access"`, also say that it can pause on an approval, which shows "Subagent needs approval" in its thread and waits for the user, because T3 Code sends no notification for it.
3. Mirror the template in `t3CodeSentences`, in order. No pinned sentence may hold ". " inside it.
4. Add `runtimeMode` to `confinedTerms` and extend its comment and the file header to say why. Reword the confined-term failure message from "names a delegated-wait term" to "names a delegation term", and update the existing `t3_thread_read` mutant's `expect` to match.
5. Name the launch-mode sentence once in a `let` binding like `prohibitionSentence`, and add the three KTD4 mutants to `selfTestMutants`, expecting the missing-sentence message for the removed and negated sentence and the confined-term message for the `# Git` rule.

**Patterns to follow:** The existing `selfTestMutants` entries and `confinedTerms`. Before editing, read `.compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md`, `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`, and `.compound-engineering/artifacts/solutions/logic-errors/go-text-template-missingkey-error-misses-index-and-printed-nulls.md`.

**Test scenarios:**

- Covers AE1. Every rendering holds the launch-mode sentence and the narrowed note sentence exactly once, each at a sentence start, inside `# T3 Code` in pinned order.
- Covers AE2, AE3. Every rendering holds the relaunch sentence naming the runtime-mode error, a new `clientRequestId`, and its separation from the launch-failure retry, the `ce-work` fallback worker, and a failed peer, inside `# T3 Code`, which follows the `# Compound Engineering` fallback rules it qualifies.
- A rendering that still holds the old unconditional note fails the section's only-pinned-sentences check.
- The self-test's removed and negated launch-mode mutants each fail with the missing-sentence message.
- The self-test's `runtimeMode` rule under `# Git` fails with the reworded confined-term message, and the existing `t3_thread_read` mutant still fails with it.

**Verification:** `agent-instructions` passes on every host rendering, and fails when the launch-mode sentence is removed from the template or a `runtimeMode` sentence is added under another heading.

### U2. Docs and learning describe Full Access delegation

**Goal:** The provisioning doc, the verification checklist, and the delegation-wait learning match the new rules.

**Requirements:** R5.

**Dependencies:** U1.

**Files:**

- `docs/provisioning.md`
- `docs/verification.md`
- `.compound-engineering/artifacts/solutions/integration-issues/t3-thread-wait-cannot-carry-in-turn-delegation-waits-alone.md`

**Approach:**

1. In the `docs/provisioning.md` T3 Code delegation paragraph, say that the agent launches each delegated task with `runtimeMode: "full-access"`, relaunches with the inherited mode when T3 Code rejects it, and notes "Subagent needs approval" only while such a task runs. Add `runtimeMode` to the description of the `agent-instructions` confined terms, and rewrite the sentence that lists the check's self-test mutants so it names the three new ones.
2. In `docs/verification.md`, add a T3 Code item: in a Full Access session, delegate one task each to `claudeAgent`, `antigravity`, and `grok`, confirm each launch was accepted and `t3_thread_configuration` on each `childThreadId` reports `runtimeMode` `full-access` (this reads the child's mode as evidence; the note rule itself keys on how the task was launched, per KTD3), and confirm the turn-end message carries no approval note. Also update the `agent-instructions` description under the repository checks in `docs/verification.md` to name `runtimeMode` among the confined terms and the new self-test mutants.
3. In the learning, update the Solution bullet on the approval note and the "Children inherit the parent's runtime mode" line to the new launch rule.

**Test expectation:** none -- prose only; markdownlint runs on the staged files.

**Verification:** No doc outside `.compound-engineering/artifacts/plans/` describes the unconditional approval note or says that a delegated task inherits the parent's mode by default; the inherited relaunch after a rejection stays described. The provisioning mutant list matches `selfTestMutants`, and markdownlint passes.

---

## Verification Contract

- `nix fmt -- --ci` passes.
- `nix flake check` passes, including `agent-instructions`.
- Build every output under `nixosConfigurations`, `homeConfigurations`, `systemConfigs`, and `darwinConfigurations` that this builder can build, per `AGENTS.md`; leave aarch64 and macOS outputs to CI.
- `markdownlint-cli2` passes on the changed Markdown.
- `nix build --no-link .#vmChecks.all` passes on a builder with `/dev/kvm`.

---

## Definition of Done

- U1 and U2 are complete and each unit's verification holds.
- Each mutation named in U1 was run once in a scratch copy and turned its check red; see `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md` before making the copy.
- The Verification Contract passes.
- No abandoned-attempt code or scratch files remain in the diff.
