---
title: T3 Code's t3_thread_wait cannot carry an in-turn wait for delegated tasks on its own
date: "2026-10-19"
category: integration-issues
module: Shared agent instructions (T3 Code section)
problem_type: integration_issue
component: tooling
severity: high
symptoms:
  - "A parent agent alternates t3_thread_wait and task_status with no delay while a delegated task shows workState waiting_for_children"
  - "A parent re-calls t3_thread_wait every 10 minutes while a delegated child sits paused on a question nobody answers"
  - "Agents in T3 Code launch delegated tasks one at a time, waiting for each before launching the next"
root_cause: wrong_api
resolution_type: documentation_update
tags: ["t3code", "t3-thread-wait", "delegate-task", "task-status", "waiting-for-children", "has-pending-question", "child-run-id", "subagents", "parallel-delegation", "agent-instructions"]
retire_when: "T3 Code gives t3_thread_wait (or a batch wait tool) a mode that blocks until a delegated task is result_available and returns early on a pending question; check the t3_thread_wait and task_status tool descriptions in a T3 Code session"
---

# T3 Code's t3_thread_wait cannot carry an in-turn wait for delegated tasks on its own

## Problem

Agents in T3 Code delegated several jobs one at a time, because the shared instructions told them to use `delegate_task` but gave no way to wait for several results inside one turn. The fix teaches them to launch every independent task in one response with `async`, then wait on each child with `t3_thread_wait`. A first version of those rules said "when `task_status` is not `result_available`, call `t3_thread_wait` again without `runId`" and "on `timedOut`, call it again". Cross-model review (Grok and Antigravity, both through T3 Code) showed both rules can spin or stall.

## Symptoms

- The parent alternates `t3_thread_wait` and `task_status` in a tight loop while a task's `workState` is `waiting_for_children`.
- A child paused on a question or approval never gets an answer; the parent times out every 10 minutes and waits again.
- Before the fix, delegated reviewers and implementation units ran serially.

## What Didn't Work

- **Re-waiting without `runId` after a non-result status.** `t3_thread_wait` without `runId` selects the thread's latest run at call time, and "an idle thread returns immediately" (its tool description). When a task's run has ended but nested subagents or background work are still live, `task_status` reports `waiting_for_children` while the child thread has no newer run, so the wait returns at once with `timedOut: false`. Both peers traced this to T3 Code's `waitForThread` selecting the already-settled run (per this session's review, from the T3 Code bundle).
- **Re-waiting on every `timedOut` without reading `task_status`.** `t3_thread_wait` settles only when the run reaches a terminal state. Unlike `delegate_task` with `mode: "wait"`, which "blocks until completion, a blocking question, or timeout", it does not return when the child asks a question. A rule that forbids `task_status` in the timeout path hides `hasPendingQuestion` forever.
- **Assuming `childRunId` is always set.** `delegate_task`'s result schema allows a null `childRunId` (`NullOr(RunId)` in the T3 Code bundle), for a task whose first run does not exist yet. A null value is not a valid `runId`, and omitting it hits the idle-thread case above.

## Solution

The `# T3 Code` section of `home/h82/agents/instructions/instructions.md.tmpl` now says, among its wait rules and in this order (pinned in `tests/agent-instructions.nix`):

- Wait on each task with its `childRunId` as `runId` once every task is launched, then read each result with one `task_status` call.
- On `timedOut: true`, read that task's `task_status` once, and never call `task_status` in a loop; when `hasPendingQuestion` is true, answer it with `t3_pending_request_read` and `t3_pending_request_respond` or ask the user, then wait again with the same `runId`.
- Re-wait without `runId` only when `task_status` shows `workState` `working` or `hasPendingChildRuns` true, which means a newer run exists to block on.
- When `childRunId` is null, or `task_status` shows `waiting_for_children` with `hasPendingChildRuns` false, there is no run to block on: read the other results, end the turn, and resume on the task's completion notification.

The last of these is the only place the instructions end the turn. Everywhere else the in-turn wait takes precedence over the `delegate_task` description's advice to end the turn after an `async` launch.

## Why This Works

`t3_thread_wait` is a run waiter, not a task waiter. Passing `childRunId` binds it to the run the launch created, so it blocks until that run ends. A task can outlive its run (nested work) or start before its run exists (null `childRunId`), and a run can stall on input without ending. The rules route each of those states to the one tool that observes it: `task_status` for `hasPendingQuestion` and `hasPendingChildRuns`, and T3 Code's completion notification for nested work, which no in-turn tool can block on.

The mechanism was verified live in this session: three `async` `delegate_task` reviewers launched in one response, `t3_thread_wait` with `runId` on each, then one `task_status` each, all inside one turn.

## Prevention

- Before writing an agent rule that waits on T3 Code delegated work, map every `task_status.workState` value and `hasPendingQuestion` to the tool that can block on it; a rule that re-calls a waiter must name the state that guarantees the waiter has something to block on.
- Treat "call it again" in a wait rule as a polling loop unless the call is bound to a specific non-terminal run.
- The `agent-instructions` check pins the sentences but cannot show agents follow them; only a live T3 Code run with a nested-work child or a child that asks a question exercises these branches.

## Related Issues

- [Substring sentence checks pass a negated instruction](../best-practices/substring-sentence-check-passes-a-negated-instruction.md), the pinning pattern the `# T3 Code` section now uses.
- Plans: `.compound-engineering/artifacts/plans/2026-10-15-2103-fix-t3-code-async-delegation-plan.md` (notification-based waiting, later removed) and `.compound-engineering/artifacts/plans/2026-10-19-1550-fix-t3-code-parallel-delegation-plan.md` (the in-turn wait this doc corrects).
