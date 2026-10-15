---
title: T3 Code Async Delegation - Plan
type: fix
date: 2026-10-15
topic: t3-code-async-delegation
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# T3 Code Async Delegation - Plan

## Goal Capsule

- **Objective:** An agent that delegates work through T3 Code waits for the child's result the way T3 Code delivers it, by notification, so a thread no longer fills with repeated status checks or self-scheduled sleeps while a delegated task runs.
- **Means:** Replace the async-delegation bullet in the `# Cross-model delegation` section of `home/h82/agents/instructions/instructions.md.tmpl` and pin the new sentences in `tests/agent-instructions.nix` (KTD1, KTD2).
- **Product authority:** The user's 2026-10-15 request, with its screenshot of the failure.
- **Open blockers:** None.
- **Stop conditions:** Stop and report when a change would need an edit to the Compound Engineering plugin's own files or to T3 Code, or would weaken an existing pinned sentence's meaning.
- **Execution profile:** One documentation-and-check change, implemented by `ce-work`, then shipped through `lfg`.

## Product Contract

### Summary

The `# Cross-model delegation` section gains a short block that describes how T3 Code's `delegate_task` returns: at once in `async` mode, with a notification later saying the child finished and `task_status` holding the result. It says when to use `mode: "wait"` instead, forbids polling and self-wake timers, limits status reads to one per task in a turn, keeps subagents from ending their turn to wait, allows ending the turn to wait for the notification even inside a skill that says not to end the turn, and names how to resume. The check pins each new sentence and fails on any unpinned sentence about status reads, polling, notifications, sleeps, or timers in that section.

### Problem Frame

During a `ce-doc-review` cross-model pass inside T3 Code, an agent called `task_status` more than a dozen times while three delegated reviews ran. It reasoned "There's no blocking wait mode available here, so I'll just keep polling the task status periodically instead", then considered a 120-second background sleep to get itself re-invoked. T3 Code already delivers an async child's completion to the parent thread as a notification, steered into the active turn where the provider supports that and queued otherwise, and the `delegate_task` tool description says so.

The template's one sentence on this ("Delegate long work asynchronously, then continue other work or end your turn instead of polling. Read `task_status` only when you need the result mid-turn.") did not hold up. It never says that a notification arrives, so ending the turn looked like abandoning the result. Its exception ("when you need the result mid-turn") covered exactly the case at hand, a skill step that merges the delegated result. And `lfg` forbids ending the turn before `<promise>DONE</promise>`, so under `lfg` the agent saw no allowed way to wait.

### Requirements

**How delegation returns**

- R1. The section states that `delegate_task` in its default `async` mode returns a `taskId` at once, and that when the child finishes, T3 Code sends the thread a notification, into the current turn where the harness supports that or as the start of the next turn otherwise.
- R2. The section states that the notification only reports that the task finished, so the result is read with one `task_status` call, and that `task_status` never waits.

**How to wait**

- R3. The section says when to launch with `mode: "wait"` and what it blocks on, and that on `waitTimedOut` the child keeps running and still notifies, so the agent ends its turn and waits for that notification.
- R4. With `async`, the agent does the work that does not need the result; when a step needs results whose notifications have not all arrived, it ends its turn and resumes that step once every task the step waits on has notified.
- R5. The section forbids calling `task_status` in a loop and starting a sleep, timer, or background command to wake for a delegated task.
- R6. The section limits `task_status` to one read per task in a turn: after that task's notification, or when a turn starts without it, so a failed or stalled task reaches the section's existing retry rule.
- R7. Ending the turn to wait for a delegation notification is allowed where a skill says not to end the turn, naming `lfg`'s DONE rule, and the run continues from the step that waited.
- R9. Only the agent that owns the T3 Code thread ends its turn to wait; a subagent that delegates through T3 Code launches with `mode: "wait"` or returns its task IDs to its caller.

**Checks**

- R8. `tests/agent-instructions.nix` pins every new sentence, and fails when an unpinned sentence about `task_status`, polling, notifications, `mode: "wait"`, `waitTimedOut`, sleeping, or timers appears in the `# Cross-model delegation` section.

### Acceptance Examples

- AE1. **Covers R4, R7.** **Given** an `lfg` run whose `ce-doc-review` step has delegated its cross-model pass to two providers and finished its in-process reviewers, **when** only the delegated results remain, **then** the agent ends its turn without polling, reads each task's result once as its notification arrives, ends the turn again while the other is outstanding, and merges both before continuing `lfg` from that step.
- AE2. **Covers R3.** **Given** a single delegated task whose result the very next step needs, with nothing else to do, **when** the agent launches it, **then** it passes `mode: "wait"`, and on `waitTimedOut` it ends the turn and waits for the notification instead of calling `task_status` repeatedly.
- AE3. **Covers R6.** **Given** an agent waiting on a delegated task, **when** a turn starts from a user message instead of that task's notification, **then** the agent reads `task_status` once for the task, and when it failed or shows no progress, cancels and retries it under the existing retry rule.

### Scope Boundaries

- T3 Code's tool descriptions and its notification delivery are not changed.
- The Compound Engineering plugin's skill files are not edited; the instruction section overrides them, as `# Review findings` and `# Pull and merge requests` already do.
- The existing pinned sentences of the section keep their wording, including the review-pass sentence that says to "merge its result when it returns".
- Not built: an order check over the whole `# Cross-model delegation` section. The new sentences are written so none leans on the one before it, so a reorder cannot change their meaning; a sentence that later needs its neighbor would justify that check.
- Not built: a wake for a child that never finishes when no other turn starts. A child that fails still reaches a terminal state and notifies, and any later turn runs the R6 read; a T3 Code task that hangs forever without a terminal state would justify a bounded wake.

### Sources

- A probe on 2026-10-15 launched a 45-second child with `mode: "wait"` and `timeoutMs` 5000. The call returned `waitTimedOut: true`, and when the child finished, the thread received "Delegated task … reached a terminal state. Use task_status with taskId … to read the result." This settles R3 (a timed-out wait still notifies) and R2 (the notification carries no result).

## Planning Contract

### Key Technical Decisions

- KTD1. **Replace the one async bullet with self-contained bullets, one rule each.** Each sentence names its tool and mode instead of saying "otherwise" or "it", so the check can pin them one by one and a reorder cannot change what any of them means. The old sentence's two halves are kept in substance and made concrete (R1-R6).
- KTD2. **Guard the topic with `onlyPinnedSentences`, not a superseded-fragment list.** The failure was a missing fact, not an old directive coming back, so no earlier text needs banning. A pattern guard over the section (`task_status`, `poll`, `notification`, `mode: "wait"`, `waitTimedOut`, `sleep`, `timer`) catches an added reversal such as "keep polling `task_status`", which `requireSentences` would let stand beside the pinned rule. The section's existing sentence that lists the tools by name matches `task_status`, so it joins the allowed list.
- KTD3. **State the turn-ending override in this section rather than in `# Pull and merge requests`.** That section's override list covers `lfg`'s DONE rule only for babysitting; delegation waits happen in any skill, so the override sits beside the delegation rules it serves (R7).

### Sentence draft

Directional wording for the new bullets, in this order, replacing the current "Delegate long work asynchronously, ..." bullet. The implementer may tighten wording as long as each R holds and the check pins the final text.

1. `delegate_task` does not block in its default `async` mode: it returns a `taskId` at once, and when the child finishes, T3 Code sends this thread a notification, steered into your current turn where the harness supports that or queued to start your next turn otherwise.
2. The notification only reports that the task finished; read the task's result with one `task_status` call, which returns at once and never waits.
3. Launch with `mode: "wait"` only when your next step needs the child's result and no other work could run meanwhile; it blocks until the child finishes or `timeoutMs` passes, and on a `waitTimedOut` result the child keeps running and still sends its notification, so end your turn and wait for it.
4. After an `async` launch, do the work that does not need the result; when a step needs results whose notifications have not all arrived, end your turn, and resume that step once every task it waits on has notified.
5. Never call `task_status` in a loop, and never start a sleep, timer, or background command to wake yourself for a delegated task.
6. Read `task_status` at most once per task in a turn: after its notification, or when a turn starts without that notification, so a task that failed or shows no progress reaches the retry rule in this section.
7. Only the agent that owns the T3 Code thread ends its turn to wait; a subagent that delegates through T3 Code launches with `mode: "wait"` or returns its task IDs to its caller.
8. Ending your turn to wait for a delegated task's notification is allowed even where a skill says not to end the turn yet, such as `lfg`'s rule not to end the turn before `<promise>DONE</promise>`; when the notification arrives, continue the same run from the step that waited.

## Implementation Units

### U1. Rewrite the async-delegation rules

- **Goal:** The `# Cross-model delegation` section carries R1-R7 and R9.
- **Requirements:** R1, R2, R3, R4, R5, R6, R7, R9.
- **Dependencies:** None.
- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`.
- **Approach:** Replace the bullet that begins "Delegate long work asynchronously" with the bullets from the Sentence draft, in its place before the review-pass bullet. Leave every other bullet unchanged. The text sits outside the harness branches, so all three rendered files carry it (KTD1, KTD3).
- **Patterns to follow:** The bullet style of `# Pull and merge requests`, which names each tool and mode explicitly.
- **Test scenarios:** Covered by U2.
- **Verification:** The rendered instruction file for each harness carries the new sentences once, in the delegation section, and no longer carries the replaced sentence.

### U2. Pin the new sentences and guard the topic

- **Goal:** The check fails when any new sentence is dropped, reworded, negated, or contradicted inside the section.
- **Requirements:** R8.
- **Dependencies:** U1.
- **Files:** `tests/agent-instructions.nix`.
- **Approach:**
  1. Add the final U1 sentences to `delegationSentences`.
  2. Add an `onlyPinnedSentences` call for `# Cross-model delegation` with the KTD2 pattern; its allowed list is the new sentences plus the existing "The tools are `orchestrator_capabilities`, ..." sentence.
  3. Extend the header comment's description of the delegation assertions to name the async-wait rules and the new guard.
- **Execution note:** Mutation-test each new assertion against a scratch copy, following the mutation-testing learnings named in `AGENTS.md`, including the copied-worktree index trap.
- **Patterns to follow:** The existing Antigravity guard (`antigravitySentences` with `onlyPinnedSentences`), and the GPG section guard.
- **Test scenarios:**
  - Happy path: the check builds green with U1's text.
  - Dropping sentence 5 from the template fails with "lacks the cross-model delegation rule".
  - Prefixing sentence 5 with "Do not " fails, because a pinned sentence must start where a sentence starts.
  - Adding "Keep polling `task_status` until the task finishes." to the delegation section fails with the new unpinned-sentence message.
  - Adding the same polling sentence to another section, such as `# Review findings`, does not trip the new guard, which shows the guard reads only its section.
  - Adding "Start a timer and check the task when it fires." to the delegation section fails with the new unpinned-sentence message.
  - Rewording "`mode: \"wait\"`" in sentence 3 to "`mode: \"async\"`" fails.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.agent-instructions` passes on U1's text and fails on each mutation above.

## Verification Contract

| Gate | Command | Applies to |
| --- | --- | --- |
| Format | `nix fmt -- --ci` | U2 |
| Instruction check | `nix build --no-link .#checks.x86_64-linux.agent-instructions` | U1, U2 |
| Flake checks | `nix flake check` | whole change |
| Host outputs | the output loop in `AGENTS.md` for `nixosConfigurations` and `homeConfigurations` | whole change |
| Markdown lint | the pre-commit `markdownlint-cli2` hook on the plan | plan file |

VM tests and macOS outputs are untouched by a Home Manager text change; CI builds them.

## Definition of Done

- U1 and U2 land, and every gate above passes.
- Each U2 mutation was run and turned the check red, and the scratch copies are gone.
- The rendered Claude Code, Codex, and Antigravity instruction files each carry the new rules.
- No abandoned wording or debugging edits remain in the diff.
