---
title: T3 Code delegated waits end the turn because t3_thread_wait cannot carry them in-turn
date: "2026-10-19"
category: integration-issues
module: Shared agent instructions (T3 Code section)
problem_type: integration_issue
component: tooling
severity: high
symptoms:
  - "A parent agent alternates t3_thread_wait and task_status with no delay while a delegated task shows workState waiting_for_children"
  - "A parent re-calls t3_thread_wait every 10 minutes while a delegated child sits paused on a question nobody answers"
  - "The user cannot talk to a parent thread that holds its turn in t3_thread_wait until every delegated child finishes"
  - "Agents in T3 Code launch delegated tasks one at a time, waiting for each before launching the next"
root_cause: wrong_api
resolution_type: documentation_update
tags: ["t3code", "t3-thread-wait", "delegate-task", "task-status", "waiting-for-children", "has-pending-question", "child-run-id", "subagents", "parallel-delegation", "completion-notification", "end-the-turn", "agent-instructions"]
retire_when: "T3 Code steers completion notifications into active Claude Code turns, or gives a wait that returns on result_available and on pending questions while leaving the thread open to the user; check the t3_thread_wait and task_status tool descriptions in a T3 Code session"
---

# T3 Code delegated waits end the turn because t3_thread_wait cannot carry them in-turn

## Problem

Agents in T3 Code delegated several jobs one at a time, because the shared instructions told them to use `delegate_task` but gave no way to wait for several results. The first fix, on 2026-10-19, launched every independent task in one response with `async` and waited on each child with `t3_thread_wait` inside the same turn. That wait was fragile, and it also held the turn, so the user could not talk to the parent while the children ran. The instructions now end the turn after the launch and resume on T3 Code's completion notification.

## Symptoms

- The parent alternates `t3_thread_wait` and `task_status` in a tight loop while a task's `workState` is `waiting_for_children`.
- A child paused on a question or approval never gets an answer; the parent times out every 10 minutes and waits again.
- A review pass with several reviewers holds the parent's turn for many minutes, and the user cannot interject, ask something else, or redirect the run.
- Before the first fix, delegated reviewers and implementation units ran serially.

## What Didn't Work

- **Re-waiting without `runId` after a non-result status.** `t3_thread_wait` without `runId` selects the thread's latest run at call time, and "an idle thread returns immediately" (its tool description). When a task's run has ended but nested subagents or background work are still live, `task_status` reports `waiting_for_children` while the child thread has no newer run, so the wait returns at once with `timedOut: false`. Both peers traced this to T3 Code's `waitForThread` selecting the already-settled run (per the 2026-10-19 review, from the T3 Code bundle).
- **Re-waiting on every `timedOut` without reading `task_status`.** `t3_thread_wait` settles only when the run reaches a terminal state. Unlike `delegate_task` with `mode: "wait"`, which "blocks until completion, a blocking question, or timeout", it does not return when the child asks a question. A rule that forbids `task_status` in the timeout path hides `hasPendingQuestion` forever.
- **Assuming `childRunId` is always set.** `delegate_task`'s result schema allows a null `childRunId` (`NullOr(RunId)` in the T3 Code bundle), for a task whose first run does not exist yet. A null value is not a valid `runId`, and omitting it hits the idle-thread case above.
- **Holding the turn in `t3_thread_wait` at all.** Even a correct in-turn wait keeps the parent's turn open until the children finish, so the user's messages wait behind it. The 2026-10-19 parallel delegation plan chose that over ending the turn because skills such as `lfg` forbid ending the turn before `<promise>DONE</promise>`. The notification-wait plan reversed the choice the same day, because freeing the thread for the user outweighs that skill rule.

## Solution

The `# T3 Code` section of `home/h82/agents/instructions/instructions.md.tmpl` splits the wait by whether a person is present (pinned in `tests/agent-instructions.nix`):

- Never use `mode: "wait"`, even for a single task, because it holds the turn until the task finishes.
- With a person present, after launching, do the work that needs no delegated result, then end the turn so the user can talk to the agent while the tasks run.
- When ending the turn while tasks still run, name them and say that a task paused on an approval shows "Subagent needs approval" and waits for the user, because T3 Code sends no notification for it.
- Each notification, whether it starts the turn or arrives with a user message, names the tasks that finished or have a question; read each finished task once with `task_status`.
- While another task the waiting step needs is still running, end the turn again without cancelling it.
- When a notification says a task has a question, read it with `t3_pending_request_read`, answer it with `t3_pending_request_respond` or ask the user, and end the turn again; when the user's next message answers it, forward that answer with `t3_pending_request_respond`.
- With a person present, never wait with `t3_thread_wait`; in any run, never call `task_status` in a loop or start a sleep, timer, or background command.
- Ending the turn to wait is allowed even where a skill forbids ending the turn or fails when no blocking wait exists, such as `lfg` before `<promise>DONE</promise>` or `ce-code-review`'s reviewer collection; for such a skill a notification plus one `task_status` read is the terminal outcome, and a task past the skill's time bound on resume counts as failed.
- With no person present, such as a headless, scheduled, or pipeline run, wait inside the turn: `t3_thread_wait` on each task's `childRunId`, one `task_status` read after a timeout, a wait without `runId` while a newer run exists, and ending the turn only when no run is left to block on.

The `# Compound Engineering` section keeps the cross-model peer deadline only for a run with no person present, where the in-turn wait can enforce it through `timeoutMs`. With a person present a peer has no deadline: its result arrives by notification, and the user cancels a slow peer. An unattended run cannot drop the deadline, because a hung peer sends no notification and no person is there to cancel it.

The check confines `t3_thread_wait`, `CROSS_MODEL_HARD_SECS`, `timeoutMs`, and `childRunId` to the two pinned sections, so a rule added under another heading cannot restore the blocking wait for a run with a person present.

## Why This Works

`t3_thread_wait` is a run waiter, not a task waiter. A task can outlive its run (nested work) or start before its run exists (null `childRunId`), and a run can stall on input without ending, so no in-turn wait fits every state. T3 Code's completion notification is the one signal that covers them, and ending the turn is what frees the thread for the user. These delivery facts come from the T3 Code 0.1.1 nightly 20261018 server bundle:

- An idle parent gets a new turn automatically when an `async` child finishes.
- A parent that is mid-turn gets the notification queued ahead of other queued messages, but Claude Code parents are never steered, so for them the notification always opens the next turn.
- Completions that land close together are batched into one notification naming several task IDs.
- The notification text carries only task IDs, so the result is read with `task_status`.
- A child's question (`user_input`) wakes the parent with a notification naming the pending request.
- A child paused on an approval does not wake the parent, but the parent thread shows "Subagent needs approval". Children inherit the parent's runtime mode, so such pauses are rare.

## Prevention

- Before writing an agent rule that waits on T3 Code delegated work, check that it leaves the thread open to the user; a rule that blocks in a tool shuts the user out until the work ends.
- A rule that drops a deadline or ends the turn must name who notices a hung task when no person is present; with nobody there, a missing notification stalls the run for good.
- Map every `task_status.workState` value and `hasPendingQuestion` to the signal that reports it. A rule that re-calls a waiter must name the state that guarantees the waiter has something to block on, and "call it again" is a polling loop unless the call is bound to a specific non-terminal run.
- The `agent-instructions` check pins the sentences but cannot show agents follow them; only a live T3 Code run with a message sent mid-delegation, a nested-work child, or a child that asks a question exercises these branches (see [Verification](../../../../docs/verification.md)).

## Related Issues

- [Substring sentence checks pass a negated instruction](../best-practices/substring-sentence-check-passes-a-negated-instruction.md), the pinning pattern the `# T3 Code` section uses.
- Plans: `.compound-engineering/artifacts/plans/2026-10-19-1736-feat-t3-code-notification-delegation-wait-plan.md` (the notification wait this doc describes), `.compound-engineering/artifacts/plans/2026-10-19-1550-fix-t3-code-parallel-delegation-plan.md` (the in-turn wait it replaced), and `.compound-engineering/artifacts/plans/2026-10-15-2103-fix-t3-code-async-delegation-plan.md` (an earlier notification-based wait, later removed).
