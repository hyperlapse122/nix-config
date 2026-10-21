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
  - "A Grok cross-model peer writes its full result but its run never ends, so no completion notification arrives and, once the sibling peer's notification has come, nothing gives the parent another turn"
  - "An unattended parent times out on the same task in t3_thread_wait again and again, reads only task_status, and at the peer deadline cancels a peer whose result was already in its session"
root_cause: wrong_api
resolution_type: documentation_update
tags: ["t3code", "t3-thread-wait", "delegate-task", "task-status", "waiting-for-children", "has-pending-question", "child-run-id", "subagents", "parallel-delegation", "completion-notification", "end-the-turn", "agent-instructions", "stalled-task", "t3-thread-read", "background-wait", "session-check"]
retire_when: "T3 Code steers completion notifications into active Claude Code turns, or gives a wait that returns on result_available and on pending questions while leaving the thread open to the user, and ends a run that has written its final message; check the t3_thread_wait and task_status tool descriptions in a T3 Code session, and whether a peer that writes its result still never reaches a terminal state"
---

# T3 Code delegated waits end the turn because t3_thread_wait cannot carry them in-turn

## Problem

Agents in T3 Code delegated several jobs one at a time, because the shared instructions told them to use `delegate_task` but gave no way to wait for several results. The first fix, on 2026-10-19, launched every independent task in one response with `async` and waited on each child with `t3_thread_wait` inside the same turn. That wait was fragile, and it also held the turn, so the user could not talk to the parent while the children ran. The instructions now end the turn after the launch and resume on T3 Code's completion notification.

That left a second gap, found on 2026-10-21: a task such as a Grok cross-model peer sometimes writes its full result and its run never reaches a terminal state, so its completion notification never comes. Grok has since left the peer pair (issue #284), but the rule covers any task that stops this way. With a person present and the sibling peer already finished, nothing gave the parent another turn, the review step waited forever, and the user had to notice. With no person present, `t3_thread_wait` timed out on that task repeatedly and the parent read only `task_status`, which carries no result until the task is terminal. The instructions now read the task's session for the result.

## Symptoms

- The parent alternates `t3_thread_wait` and `task_status` in a tight loop while a task's `workState` is `waiting_for_children`.
- A child paused on a question or approval never gets an answer; the parent times out every 10 minutes and waits again.
- A review pass with several reviewers holds the parent's turn for many minutes, and the user cannot interject, ask something else, or redirect the run.
- Before the first fix, delegated reviewers and implementation units ran serially.
- A peer's result sits in its session while `task_status` reports it as not terminal, the parent's turn has ended, and no notification, user message, or timer will start another turn.
- An unattended parent discards, at the peer deadline, a result that was already written.

## What Didn't Work

- **Re-waiting without `runId` after a non-result status.** `t3_thread_wait` without `runId` selects the thread's latest run at call time, and "an idle thread returns immediately" (its tool description). When a task's run has ended but nested subagents or background work are still live, `task_status` reports `waiting_for_children` while the child thread has no newer run, so the wait returns at once with `timedOut: false`. Both peers traced this to T3 Code's `waitForThread` selecting the already-settled run (per the 2026-10-19 review, from the T3 Code bundle).
- **Re-waiting on every `timedOut` without reading `task_status`.** `t3_thread_wait` settles only when the run reaches a terminal state. Unlike `delegate_task` with `mode: "wait"`, which "blocks until completion, a blocking question, or timeout", it does not return when the child asks a question. A rule that forbids `task_status` in the timeout path hides `hasPendingQuestion` forever.
- **Assuming `childRunId` is always set.** `delegate_task`'s result schema allows a null `childRunId` (`NullOr(RunId)` in the T3 Code bundle), for a task whose first run does not exist yet. A null value is not a valid `runId`, and omitting it hits the idle-thread case above.
- **Holding the turn in `t3_thread_wait` at all.** Even a correct in-turn wait keeps the parent's turn open until the children finish, so the user's messages wait behind it. The 2026-10-19 parallel delegation plan chose that over ending the turn because skills such as `lfg` forbid ending the turn before `<promise>DONE</promise>`. The notification-wait plan reversed the choice the same day, because freeing the thread for the user outweighs that skill rule.

## Solution

The `# T3 Code` section of `home/h82/agents/instructions/instructions.md.tmpl` splits the wait by whether a person is present (pinned in `tests/agent-instructions.nix`):

- Launch every delegated task, cross-model peers and implementation units included, with `runtimeMode: "full-access"`, so it never pauses on an approval nobody sees; when `delegate_task` rejects that launch with an error about the requested runtime mode, such as one saying the target provider does not offer it or that it ranks above the parent thread's mode, relaunch the task once without `runtimeMode`, so it inherits the parent thread's mode, under a new `clientRequestId` (not counted as a failed or unavailable launch under any rule in the instructions, including the launch-failure retry, a category's fallback worker, and a failed cross-model peer, though a failure of the relaunch is one). The launch sets `runtimeMode` even though `delegate_task`'s own description says to leave it unset, and the `clientRequestId` reuse rule names the relaunch as its exception.
- With no person present, a task whose `task_status` shows `pendingApproval` is cancelled with `task_cancel` and counted as failed, because nobody can approve it and `t3_thread_wait` does not return on an approval.
- Never use `mode: "wait"`, even for a single task, because it holds the turn until the task finishes.
- With a person present, after launching, do the work that needs no delegated result, then end the turn so the user can talk to the agent while the tasks run.
- When ending the turn while tasks still run, name them, and when one of them runs without `runtimeMode: "full-access"`, also say that such a task can pause on an approval, which shows "Subagent needs approval" in its thread and waits for the user, because T3 Code sends no notification for it.
- Each notification, whether it starts the turn or arrives with a user message, names the tasks that finished or have a question; read each finished task once with `task_status`.
- While another task the waiting step needs is still running, end the turn again without cancelling it.
- When a notification says a task has a question, read it with `t3_pending_request_read`, answer it with `t3_pending_request_respond` or ask the user, and end the turn again; when the user's next message answers it, forward that answer with `t3_pending_request_respond`.
- On every turn the agent gets while a task the waiting step needs is not terminal and its result is not taken (a notification, a user message, a background wait, or a `t3_thread_wait` timeout), read that task's `task_status` once, then its session with `t3_thread_read` on its `childThreadId` in the `activity` view, paging with `afterPosition` until no `nextPosition` remains, and read the latest assistant message by `itemId`, repeating with `textOffset` set to `nextTextOffset` until it is null.
- When that `task_status` is terminal, use its result as usual; when it shows a pending question or `hasPendingChildRuns` true, keep waiting and cancel nothing.
- Otherwise, when the latest assistant message is finished, holds the whole result the task prompt asked for, and nothing in the session has changed since the previous check, use it as the task's result, stop the task with `task_cancel`, and say the result came from the session. A take therefore needs two checks: a sibling's notification or a wake, then the next wake.
- When `task_cancel` leaves the task running, keep the result, tell the user once that it still runs, and count the result as taken, so no second take and no new wait follow. A result taken from the session is the task's terminal outcome, including under a skill that forbids ending the turn.
- Whenever the agent ends its turn while such a task still runs and its result is not taken, keep exactly one background command pending that waits 10 minutes, such as `sleep 600`, started through the harness's own way of running a command in the background that wakes the agent on exit; a wake checks those tasks and starts the next wait only while such a task remains. Stop the pending wait through the same facility once none remains or the user redirects the work. A harness with no such facility, or one that ends background commands with the turn, says so when it ends the turn, so the user can write to have the sessions checked.
- With a person present, never wait with `t3_thread_wait`; in any run, never call `task_status` in a loop or start a sleep, timer, or background command, except the 10-minute waits these rules name.
- Ending the turn to wait is allowed even where a skill forbids ending the turn or fails when no blocking wait exists, such as `lfg` before `<promise>DONE</promise>` or `ce-code-review`'s reviewer collection; for such a skill a notification plus one `task_status` read, or a result taken from the task's session, is the terminal outcome, and a task past the skill's time bound on resume counts as failed unless its session holds a whole result.
- With no person present, such as a headless, scheduled, or pipeline run, wait inside the turn: `t3_thread_wait` on each task's `childRunId` with the smaller of 600000 and the time left before any bound as `timeoutMs` (no wait when no time is left, and no new wait once the bound has passed), a pending question answered from the task and the instructions, a check after each timeout, and a wait without `runId` while a newer run exists. At a passed bound, take a whole result from the session even if it changed since the previous check; otherwise cancel the task and count it as failed. When no run is left to block on (`childRunId` null, or `waiting_for_children` with `hasPendingChildRuns` false), check the task, then stay in the turn, wait the smaller of 10 minutes and the time left before the bound through the harness's own in-turn wait, and check again, instead of ending the turn for a notification.

The `# Compound Engineering` section keeps the cross-model peer deadline only for a run with no person present, where the in-turn wait can enforce it through `timeoutMs`. With a person present a peer has no deadline: its result arrives by notification or from its session, and the user cancels a slow peer whose session holds no whole result. An unattended run cannot drop the deadline, because a hung peer sends no notification and no person is there to cancel it; at the deadline it takes a whole result from the peer's session even if the session changed, and otherwise cancels the peer as failed, never waiting again after the deadline. A result taken from the session is the peer's artifact, with the `task_status` read as the identity receipt.

The check confines `t3_thread_wait`, `t3_thread_read`, `CROSS_MODEL_HARD_SECS`, `timeoutMs`, `childRunId`, `runtimeMode`, `full-access`, `full access`, `approval-required`, `auto-accept-edits`, and `pendingApproval` to the two pinned sections, failing when another section names a delegation term, so a rule added under another heading cannot restore the blocking wait for a run with a person present or move a delegation rule out of its section. It also runs a self-test that applies its own per-file rules to ten mutants of the rendered Claude Code file (the take-from-session sentence removed, a `t3_thread_read` rule under `# Git`, the self-wake prohibition sentence removed, the self-wake prohibition sentence negated, the full-access launch sentence removed, the full-access launch sentence negated, a `runtimeMode` rule under `# Git`, the rejected-mode relaunch sentence inverted, the approval note made unconditional again, and a `full access` rule under `# Git`) and fails when a mutant passes or fails without the expected message, so a rule that stops firing turns the check red.

## Why This Works

`t3_thread_wait` is a run waiter, not a task waiter. A task can outlive its run (nested work) or start before its run exists (null `childRunId`), and a run can stall on input without ending, so no in-turn wait fits every state. T3 Code's completion notification is the one signal that covers them, and ending the turn is what frees the thread for the user. These delivery facts come from the T3 Code 0.1.1 nightly 20261018 server bundle:

- An idle parent gets a new turn automatically when an `async` child finishes.
- A parent that is mid-turn gets the notification queued ahead of other queued messages, but Claude Code parents are never steered, so for them the notification always opens the next turn.
- Completions that land close together are batched into one notification naming several task IDs.
- The notification text carries only task IDs, so the result is read with `task_status`.
- A child's question (`user_input`) wakes the parent with a notification naming the pending request.
- A child paused on an approval does not wake the parent, but its thread shows "Subagent needs approval". Children are launched with `runtimeMode: "full-access"` (`claudeAgent` and `antigravity` accept it from a Full Access thread and report it through `t3_thread_configuration`, even though `orchestrator_capabilities` lists no `runtimeModes` for them, and `grok`, disabled in T3 Code since issue #284, listed it, while an unoffered mode or one ranked above the parent thread's is rejected rather than silently narrowed); only a task relaunched without `runtimeMode` after such a rejection runs with the inherited mode and can pause on an approval.
- A run that writes its result and never ends sends no notification at all, so the notification covers every state except this one; the session check and the wake cover it.

The session check reads the `activity` view, not `messages`, because `messages` returns only user and assistant messages and hides tool calls: a task that wrote an interim message and then went on running tools would look stalled and be cancelled with its real work unwritten. The first version judged a stall by item status, taking the result when no item was still running. Review showed two failures: a stuck item can keep showing `running` on a task that is done, and a message can be finished just before the next tool call starts. A session that stays unchanged between two checks covers both, at the cost that a take needs two checks. `task_status` is read first so that a terminal task, a pending question, or `hasPendingChildRuns` true is never taken from the session or cancelled, and a long result is paged to the end with `textOffset` before it is judged whole. At a passed bound the changed-session test is dropped, because a deadline decides then and a whole result is worth more than waiting for quiet. The single 10-minute background wait is the one exception to the rule against starting a timer, because a check that runs only on turns the agent already has misses the main case: the sibling peer's notification arrives before the stall and no later turn comes. The wait is stopped once no needed task remains, and it is not re-armed after a failed `task_cancel`, so it cannot outlive the step or loop on a result already taken. An unattended run with no run to block on stays in the turn with its own timed wait rather than ending it, because no person and no timer would give it another turn. No stall's `task_status` state was captured, so the rule keys on "not terminal", which covers `working` and `waiting_for_children`, and the first live stall should record which one it was.

## Prevention

- Before writing an agent rule that waits on T3 Code delegated work, check that it leaves the thread open to the user; a rule that blocks in a tool shuts the user out until the work ends.
- A rule that drops a deadline or ends the turn must name who notices a hung task when no person is present; with nobody there, a missing notification stalls the run for good.
- Map every `task_status.workState` value and `hasPendingQuestion` to the signal that reports it. A rule that re-calls a waiter must name the state that guarantees the waiter has something to block on, and "call it again" is a polling loop unless the call is bound to a specific non-terminal run.
- A rule that waits on a notification needs a second path for a task that never sends one: a check of the task's own output on each turn, and, with a person present, one timed wake so a turn comes without any event. Bound the wake to one pending command, or a forgotten timer outlives the step.
- Before cancelling a task on a deadline or a time bound, read what it already wrote; a deadline that discards a finished result throws work away.
- Check a task's liveness in a view that shows tool calls and item status, not one that shows messages only.
- Judge a stall by an unchanged session across two checks, not by item status: a status can stay `running` on a finished task, and a finished-looking message can precede the next tool call.
- Read `task_status` before taking a result from a session, and page a long result to the end before judging it whole.
- The `agent-instructions` check pins the sentences and its self-test proves the per-file rules fire on a removed, a negated, and an out-of-section rule, but it cannot show agents follow them; only a live T3 Code run with a message sent mid-delegation, a nested-work child, a child that asks a question, or a task that writes its result and never finishes exercises these branches (see [Verification](../../../../docs/verification.md)).

## Related Issues

- [Substring sentence checks pass a negated instruction](../best-practices/substring-sentence-check-passes-a-negated-instruction.md), the pinning pattern the `# T3 Code` section uses.
- Plans: `.compound-engineering/artifacts/plans/2026-10-19-1736-feat-t3-code-notification-delegation-wait-plan.md` (the notification wait this doc describes), `.compound-engineering/artifacts/plans/2026-10-19-1550-fix-t3-code-parallel-delegation-plan.md` (the in-turn wait it replaced), and `.compound-engineering/artifacts/plans/2026-10-15-2103-fix-t3-code-async-delegation-plan.md` (an earlier notification-based wait, later removed).
