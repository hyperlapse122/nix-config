---
title: Stalled Delegated Task Session Check - Plan
type: feat
date: 2026-10-21
topic: stalled-delegated-task-session-check
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Stalled Delegated Task Session Check - Plan

## Goal Capsule

- **Objective:** A cross-model review, or any other delegated step, no longer stalls forever when a delegated task has already written its result but never reaches a terminal state, as a Grok peer sometimes does; the parent picks up that result and continues without the user having to notice the stall.
- **Means:** Sentences in the `# T3 Code` section of `home/h82/agents/instructions/instructions.md.tmpl` that check a still-running task's session on every turn and take a finished result from it, plus a single 10-minute background wake so a turn comes even when no notification will (KTD1, KTD2); matching changes to the `# Compound Engineering` peer sentences (KTD5), the `agent-instructions` check, docs, and the T3 Code wait learning.
- **Product authority:** The user's 2026-10-21 request and the wake decision made during this plan's review; the Product Contract wins over the Planning Contract on any conflict.
- **Open blockers:** None.
- **Stop conditions:** Stop and report when the change would need an edit to T3 Code or the Compound Engineering plugin, or would bring back a blocking wait, a `task_status` loop, or more than one pending wake for a run with a person present.
- **Execution profile:** One instructions-and-check change with docs and a learning update, implemented by `ce-work` and shipped through `lfg`.

## Product Contract

### Summary

On every turn the agent gets while a delegated task its waiting step needs is still running, it reads that task's session to its end. If the session's latest assistant message is finished and holds the whole result the task prompt asked for, and nothing in the session is still running, the agent uses that message as the task's result, stops the task with `task_cancel`, and says it took the result from the session. With a person present, the agent keeps one 10-minute background wait pending while such tasks run, so a turn comes even when no notification will. With no person present, each in-turn wait times out after at most 10 minutes, and the timeout runs the same check.

### Problem Frame

With a person present, the agent ends its turn after launching delegated tasks and resumes on T3 Code's completion notification. A Grok cross-model review peer sometimes writes its full findings but its run never ends, so no notification arrives. When the other peer has already finished, nothing ever gives the agent another turn, the review step waits forever, and the user has to notice and intervene. With no person present, `t3_thread_wait` times out on the same task again and again, and the agent only reads `task_status`, which carries no result until the task is terminal; at the peer deadline it cancels the peer as failed and discards a result that was already there.

### Requirements

- R1. On every turn the agent gets (a notification, a user message, a background wake, or a `t3_thread_wait` timeout) while a delegated task its waiting step needs has not reached a terminal state, it reads that task's session with `t3_thread_read` on its `childThreadId`, in the `activity` view, paging to the end and reading the last assistant message's full text.
- R2. When the session's latest assistant message is finished and holds the whole result the task prompt asked for, and no item in the session is still running, the agent uses that message as the task's result, reads the task's `task_status` once, stops the task with `task_cancel`, and reports that it took the result from the session. Otherwise it keeps waiting.
- R3. A result taken from the session counts as the task's terminal outcome wherever the instructions name a completion notification and one `task_status` read as that outcome, including under skills that forbid ending the turn.
- R4. In a run with a person present, when the agent ends its turn while a task the waiting step needs still runs, it keeps exactly one background command pending that waits 10 minutes and wakes it when it exits, started through the harness's own background-command facility; a wake runs R1 and, while such a task still runs, starts the next wait. When the harness has no such facility, the agent says so when it ends the turn, so the user can write to have it check the sessions.
- R5. In a run with no person present, each `t3_thread_wait` passes as `timeoutMs` the smaller of 600000 and the time left before any deadline or skill bound on that task, and a timeout runs R1 before waiting again.
- R6. When a deadline or skill bound passes while a task still runs, the agent runs R1 first and cancels the task as failed only when its session holds no finished result.
- R7. For a cross-model peer, a result taken from the session is the peer's artifact, and its `task_status` read is still the identity receipt; cancelling a peer whose result is in its session is not the slow-peer cancellation left to the user.
- R8. When `task_cancel` does not bring the task to a terminal state, the agent still uses the result and tells the user the task is still running so they can stop it.
- R9. `tests/agent-instructions.nix` pins every new and changed sentence and confines `t3_thread_read` to the two pinned sections; `docs/provisioning.md`, `docs/verification.md`, `CONCEPTS.md`, and the T3 Code wait learning describe the session check and the wake.

### Scope Boundaries

- No change to T3 Code or the Compound Engineering plugin.
- No `task_status` loop and no in-turn blocking wait with a person present; the only wake is the single pending 10-minute background wait (R4).
- A task still working is not cancelled; the existing rules for slow peers and time-bounded tasks keep their meaning.
- Considered and not built: a T3 Code `schedule_task` interval wake. It works in every harness but outlives the step when its deletion is missed; evidence that harnesses without a background-command wake hit this stall would change this.
- Considered and not built: a fixed deadline that cancels any task past 10 minutes. It would discard real work from a slow but healthy peer.

### Sources / Research

- `home/h82/agents/instructions/instructions.md.tmpl` — the `# T3 Code` wait rules and the `# Compound Engineering` peer rules.
- `tests/agent-instructions.nix` — `t3CodeSentences`, `compoundEngineeringSentences`, `confinedTerms`.
- `.compound-engineering/artifacts/solutions/integration-issues/t3-thread-wait-cannot-carry-in-turn-delegation-waits-alone.md` — why the person-present wait ends the turn.
- T3 Code tool descriptions: `t3_thread_read` (the `messages` view returns user and assistant messages; the `activity` view returns all summarized timeline items; `afterPosition`/`nextPosition` paging; `itemId`/`textOffset` for long items), `t3_thread_wait` ("after timedOut=true ... use t3_thread_read/list"), `task_status` (`summary` is the final result), `task_cancel` (published results stay available; disposes the automatic parent delivery).
- A live read of a running Grok peer's session during this plan's review showed the activity view reporting each item's `status`, including a `running` reasoning item, which is what R2's "nothing running" test reads.

## Planning Contract

### Key Technical Decisions

- KTD1. **Wake once with a single pending 10-minute background command.** A check that runs only on turns the agent already gets misses the main case: the sibling peer's notification arrives before the stall, and no later turn comes. (session-settled: user-approved — proposed with the trade-off shown and chosen over checking only on turns that arrive and over a T3 Code `schedule_task` interval wake: it is the one wake that ends with the step and needs no cleanup.) It is an exception to the existing rule against waking yourself, which the changed sentence names. Governs R4.
- KTD2. **Check on every turn, not after an age gate.** A session read is cheap, and R2's content-and-liveness test, not the task's age, decides cancellation; so no launch timestamp or `date +%s` is needed, and a user who writes to ask for a check always gets one. Governs R1.
- KTD3. **Read the `activity` view to its end.** The `messages` view hides tool calls, so a task running tools after an interim message looks stalled there; only the activity view shows whether anything followed or is still running. Paging and `textOffset` keep a long timeline or result from being read cut off. Governs R1, R2.
- KTD4. **Cancel after taking the result.** `task_cancel` keeps published results and disposes the parent delivery, so a late notification cannot hand the agent a second copy. Governs R2, R8.
- KTD5. **Change every sentence that would otherwise contradict the check.** The terminal-outcome sentence, the skill-bound `timeoutMs` sentence, the `timedOut` sentence, the no-wake sentence, and the Compound Engineering peer-deadline, peer-result, and slow-peer sentences all change, so no two pinned sentences disagree. Governs R3, R5, R6, R7.
- KTD6. **The rule does not depend on which `workState` a stalled task reports.** No stall was captured in planning, so R1 keys on "not terminal", which covers both `working` and `waiting_for_children`.
- KTD7. **Write each new sentence without an internal ". "**, because `sectionSentences` splits on it.

## Implementation Units

### U1. Add the session check and wake to the instructions and pin them

**Goal:** Carry R1 to R8 in the template and pin them in the check.

**Requirements:** R1-R9

**Dependencies:** None

**Files:**

- `home/h82/agents/instructions/instructions.md.tmpl`
- `tests/agent-instructions.nix`

**Approach:**

1. In `# T3 Code`, after the sentence on user messages during delegated tasks, add the session-check sentence (R1), the take-and-cancel sentence (R2, R8), and the wake sentence (R4).
2. Change the sentence that forbids sleeps, timers, and background commands so it names the R4 wait as its one exception.
3. Change the terminal-outcome sentence for skills that forbid ending the turn, and the sentence that continues the step "once every result it needs has arrived", so a result taken from the session also counts (R3).
4. Change the `timedOut` sentence, the in-turn wait sentence, and the skill-bound sentence so `timeoutMs` is the smaller of 600000 and the time left, a timeout runs the session check, and a passed bound checks the session before cancelling (R5, R6).
5. In `# Compound Engineering`, change the peer-deadline sentence the same way (R5, R6), the peer-result sentence to allow a result taken from the session (R7), and the slow-peer sentence so it covers only a peer still working (R7).
6. Mirror every new and changed sentence in `t3CodeSentences` and `compoundEngineeringSentences` in file order, and add `t3_thread_read` to `confinedTerms`.

**Test scenarios:**

- The rendered file for every harness holds each new and changed sentence exactly once, in order, inside its section.
- Dropping or negating any new sentence turns `agent-instructions` red.
- A `t3_thread_read` mention outside `# T3 Code` and `# Compound Engineering` turns the check red.

**Verification:** `nix build --no-link .#checks.x86_64-linux.agent-instructions` passes, and a mutation that drops one new sentence fails it.

### U2. Update docs and the learning

**Goal:** Describe the session check and the wake where the wait is described today.

**Requirements:** R9

**Dependencies:** U1

**Files:**

- `docs/provisioning.md`
- `docs/verification.md`
- `CONCEPTS.md`
- `.compound-engineering/artifacts/solutions/integration-issues/t3-thread-wait-cannot-carry-in-turn-delegation-waits-alone.md`

**Approach:** Add the session check and the wake to the T3 Code and cross-model paragraphs of `docs/provisioning.md` and the Delegated task entry of `CONCEPTS.md`; add live verification items for a task that writes its result and does not finish, with a person present and with none; add the stalled-result case and the wake exception to the learning.

**Test expectation:** none -- prose only; the Markdown lint hook covers it.

## Verification Contract

- `nix fmt -- --ci`
- `nix build --no-link .#checks.x86_64-linux.agent-instructions`
- `nix flake check`

## Definition of Done

- The rendered instructions carry R1 to R8 for every harness, and the check pins them and confines `t3_thread_read`.
- Docs and the learning describe the session check and the wake.
- Live behavior with a real stalled Grok peer is listed as a manual verification item, not claimed.
