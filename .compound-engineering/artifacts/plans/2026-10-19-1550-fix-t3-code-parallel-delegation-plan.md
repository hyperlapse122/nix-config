---
title: T3 Code Parallel Delegation - Plan
type: fix
date: 2026-10-19
topic: t3-code-parallel-delegation
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# T3 Code Parallel Delegation - Plan

## Goal Capsule

- **Objective:** When an agent in T3 Code hands several independent jobs to subagents, such as a skill's reviewers or a plan's implementation units, those jobs run at the same time, so the step takes about as long as its slowest job instead of the sum of all of them.
- **Means:** Add parallel-launch and multi-result wait rules to the `# T3 Code` section of the shared agent instructions, `home/h82/agents/instructions/instructions.md.tmpl`, and pin them in `tests/agent-instructions.nix` (KTD1, KTD2).
- **Product authority:** The user's 2026-10-19 request and the decisions made in this brainstorm; the Product Contract below wins over the Planning Contract on any conflict.
- **Open blockers:** None.
- **Stop conditions:** Stop and report when a change would need an edit to T3 Code or the Compound Engineering plugin's files, or would weaken an existing pinned sentence's meaning.
- **Execution profile:** One instructions-and-check change with a docs update, implemented by `ce-work` and shipped through `lfg`.

---

## Product Contract

### Summary

The `# T3 Code` section tells an agent to launch every independent delegated task in one response with `delegate_task` in `async` mode. When a later step needs the results in the same turn, the agent waits on each child thread with `t3_thread_wait` and then reads each result once with `task_status`. Tasks that would edit the same files in a shared checkout run in their own worktree or one after another.

### Problem Frame

Inside T3 Code, agents that delegate several jobs launch one, wait for it to finish, and only then launch the next. The user has seen two forms of this: a `delegate_task` call in `mode: "wait"` per job, and one `async` launch per turn followed by ending the turn until its notification arrives. Either way, a `ce-code-review` pass with several reviewers, or a `ce-work` run with several units, takes the sum of every job's time.

The cause is in the instructions. The 2026-10-18 slimming refactor (`.compound-engineering/artifacts/plans/2026-10-18-2127-refactor-slim-agent-instructions-plan.md`) dropped the detailed T3 Code delegation procedure and left one rule: delegate subagent work through `delegate_task` instead of the native subagent tool. That rule takes away the native tool, which runs several subagents at once, and puts nothing about batching in its place. It also gives no way to wait for several results inside a turn. A skill step that merges results therefore reaches for `mode: "wait"`, which blocks on one task at a time. The refactor assumed T3 Code's own tool descriptions would cover the mechanics, but those descriptions explain a single task's `async` and `wait` modes and say nothing about launching a batch.

### Key Decisions

- **Wait for several results inside the turn with `t3_thread_wait`, not by ending the turn.** Waiting inside the turn works under skills that forbid ending the turn, such as `lfg` before `<promise>DONE</promise>`, and needs only a few sentences. (session-settled: user-directed — chosen over ending the turn and resuming on completion notifications, and over a hybrid that ends the turn only for long tasks: the notification route would bring back the turn-ending override and `task_status` limits the 2026-10-18 refactor removed.) Governs R5, R6.
- **Keep tasks that share files apart.** Parallel launch must not let two tasks edit the same files in one checkout at the same time. (session-settled: user-approved — proposed in the scoping synthesis with the conflict risk stated, and confirmed.) Governs R3.
- **Change only the instructions, their check, and the provisioning doc that describes them.** T3 Code and the Compound Engineering plugin stay untouched, as in the 2026-10-15 async delegation plan.

### Requirements

**Launching**

- R1. The section tells the agent to launch every delegated task that does not need another task's result in the same response, each with `delegate_task` in the default `async` mode, and not to launch one, wait for it, and then launch the next.
- R2. The section limits `mode: "wait"` to launching exactly one task whose result the next step needs.
- R3. The section tells the agent that tasks editing the same files in a shared checkout must not run at the same time: launch them with `isolation: "worktree"` or one after another.
- R4. A task that needs an earlier task's result is launched only after that result has been read.

**Waiting**

- R5. When a later step in the same turn needs the results, the agent, after launching every task, waits on each task's `childThreadId` with `t3_thread_wait` and then reads each result with one `task_status` call.
- R6. When `t3_thread_wait` returns `timedOut: true`, the agent calls it again for the same thread, and never loops on `task_status` or starts a sleep, timer, or background command to wake itself.

**Scope of the rules**

- R7. The new rules apply only when the session lists T3 Code's delegation tools, and the existing fallback to the native subagent tool stays unchanged.
- R8. `tests/agent-instructions.nix` pins each new sentence in the `# T3 Code` section, so the check fails when one is dropped, reworded, negated, or moved to another section.

### Acceptance Examples

- AE1. **Covers R1, R5.** Given `ce-code-review` dispatches four reviewers in a T3 Code session, when the agent delegates them, all four `delegate_task` calls go out in one response, and the agent then waits on the four child threads before merging findings.
- AE2. **Covers R2.** Given a skill step needs one scout's result before it can continue, when the agent delegates that scout alone, it may use `mode: "wait"`.
- AE3. **Covers R3.** Given `ce-work` has two units that both edit `flake.nix`, when the agent delegates them in a shared checkout, it gives each its own worktree or runs them in order.
- AE4. **Covers R6.** Given `t3_thread_wait` returns `timedOut: true` for one reviewer while the others finished, the agent calls `t3_thread_wait` again on that thread rather than polling `task_status` or sleeping.
- AE5. **Covers R4.** Given unit B needs unit A's output, the agent launches B only after reading A's result, while unrelated unit C launches with A.

### Scope Boundaries

- No change to T3 Code, its tool descriptions, or the Compound Engineering plugin's skills.
- The 2026-10-15 notification-based waiting rules (turn-ending override, per-turn `task_status` limits) are not restored.
- No concurrency cap on how many tasks launch at once; T3 Code and the providers set their own limits.
- The temporary prompt given to the user for sessions already running is not part of the repository change.

### Dependencies / Assumptions

- `t3_thread_wait` on a delegated task's `childThreadId` blocks until that child's latest run ends, per its tool description ("Wait for a T3 thread run to reach a terminal durable state"); it reports status only, so `task_status` still reads and acknowledges the result.
- Claude Code may run several MCP calls from one response one after another, but an `async` `delegate_task` returns at once, so the children still run together.

### Outstanding Questions

None. The question of a live run before shipping is resolved in KTD4.

### Sources / Research

- `home/h82/agents/instructions/instructions.md.tmpl`, `# T3 Code` section: the one delegation rule this work extends.
- `tests/agent-instructions.nix`: the existing pins for the `# T3 Code` section.
- `.compound-engineering/artifacts/plans/2026-10-15-2103-fix-t3-code-async-delegation-plan.md`: the earlier async waiting rules and their check pattern.
- `.compound-engineering/artifacts/plans/2026-10-18-2127-refactor-slim-agent-instructions-plan.md`: the refactor that removed them and its assumption that T3 Code's own guidance covers delegation mechanics.
- Before writing the check, read the sentence-check learnings `AGENTS.md` lists, including `.compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md`.

Product Contract preservation: changed: the third Key Decision now names the provisioning doc beside the instructions and check — U3's docs update was always in the plan, and the review found the decision's wording excluded it; no requirement changed.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Add the rules as bullets in the existing `# T3 Code` section, right after its delegation bullet.** The section already gates on the session listing T3 Code's tools, which covers R7 without repeating the condition in each bullet, and the `topLevelHeadings` check would reject a new heading anyway. The pull request watch bullet stays last.
- KTD2. **Add `# T3 Code` to `checkedSections` in `tests/agent-instructions.nix`.** That gives the section the same allowlist, membership, and order checks `# Review findings` and `# Compound Engineering` have, so a separate sentence that reverses a pinned rule ("keep polling `task_status`") fails, which `requireSentences` alone would let stand (R8). The section's sentences move into a named list, as `compoundEngineeringSentences` does, and `pinnedSentences` reuses it.
- KTD3. **Write every new sentence without a full stop followed by a space inside it.** `sectionSentences` splits on ". ", so "e.g. " or a period inside a code span would split a pinned sentence and fail the order check.
- KTD4. **Ship on the rendered-text check plus the mechanism run already done in this session.** This plan's own document review launched three reviewers with `async` `delegate_task` in one response, waited on each child thread with `t3_thread_wait`, and read each result with one `task_status` call, all inside one turn, so R1 and R5's mechanism works. The check proves the rules reach every harness; whether agents follow them over the tool description's end-the-turn advice shows only in use, which the precedence sentence in Rule wording addresses and the user's temporary prompt is already trying.

### Rule wording

The final sentences for U1, in this order, between the existing delegation bullet and the pull request watch bullet. Each states one requirement; U2 pins this exact text.

1. Launch every delegated task that does not need another task's result in the same response, each with `delegate_task` in its default `async` mode, instead of launching one, waiting for it, and then launching the next. (R1)
2. Use `mode: "wait"` only when you launch exactly one task and your next step needs its result. (R2)
3. Never run two tasks that edit the same files in one checkout at the same time: commit first, launch each with `isolation: "worktree"`, and merge its changes back, or launch them one after another. (R3)
4. Launch a task that needs an earlier task's result only after you have read that result. (R4)
5. When a later step in the same turn needs the results, call `t3_thread_wait` on each task's `childThreadId` with its `childRunId` as `runId` once every task is launched, then read each result with one `task_status` call. (R5)
6. When `t3_thread_wait` returns `timedOut: true`, call it again for that thread; never call `task_status` in a loop, and never start a sleep, timer, or background command to wake yourself. (R6)
7. When `task_status` shows a `workState` other than `result_available`, call `t3_thread_wait` on that thread again, without `runId`, before reading it once more. (R5, R6)
8. This in-turn wait takes precedence over the `delegate_task` description's advice to end the turn after an `async` launch. (R5)

The trailing (R1) to (R6) tags are traceability labels, not template text: each template bullet ends at its sentence's full stop. The implementer may tighten wording as long as each R holds, KTD3 holds, and U2 pins the final text.

### Assumptions

- `delegate_task` returns `childRunId` with every launch, so sentence 5 ties each wait to the task's own run, even when a worktree child is still running project setup. A run can end while the task still waits on nested work (`workState` `waiting_for_children`), which sentence 7 sends back to `t3_thread_wait`.

---

## Implementation Units

### U1. Add the parallel delegation rules

- **Goal:** The `# T3 Code` section of the rendered instructions carries R1 through R6 through the eight Rule wording sentences.
- **Requirements:** R1, R2, R3, R4, R5, R6, R7; governed by the Key Decisions on in-turn waiting (R5, R6) and on shared files (R3).
- **Dependencies:** None.
- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`.
- **Approach:** Insert the eight bullets from Rule wording after the bullet that begins "When the session lists T3 Code's delegation tools" and before the pull request watch bullet (KTD1, KTD3). Leave every other line unchanged; the template's one action, `{{ .user.gpgKey }}`, stays the only action.
- **Patterns to follow:** The bullet style of the existing `# T3 Code` and `# Pull and merge requests` sections, which name each tool and mode in backticks.
- **Test scenarios:** Covered by U2.
- **Verification:** Each harness's rendered file holds the eight sentences once, inside `# T3 Code`, in Rule wording order.

### U2. Pin the T3 Code section

- **Goal:** The `agent-instructions` check fails when a new sentence is dropped, reworded, negated, duplicated, reordered, moved out of `# T3 Code`, or contradicted by an added sentence in that section.
- **Requirements:** R8.
- **Dependencies:** U1.
- **Files:** `tests/agent-instructions.nix`.
- **Approach:**
  1. Add `t3CodeHeading` and `t3CodeSentences`, in section order: the existing delegation sentence, the eight U1 sentences, then the existing pull request watch sentence.
  2. Add a `checkedSections` entry for `# T3 Code` (KTD2).
  3. Replace the literal `# T3 Code` block at the end of `pinnedSentences` with `[ t3CodeHeading ] ++ t3CodeSentences`.
  4. Update the header comment that lists the sections holding only their pinned sentences to name `# T3 Code`.
- **Execution note:** Mutation-test each new assertion in a scratch copy, following the mutation-testing learnings `AGENTS.md` lists, including `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`.
- **Patterns to follow:** `compoundEngineeringHeading`, `compoundEngineeringSentences`, and their `checkedSections` entry.
- **Test scenarios:**
  - Happy path: the check builds green with U1's text on every host. Covers AE1, AE2, AE3, AE4, AE5.
  - Dropping the R1 sentence from the template fails the build, naming that sentence.
  - Prefixing the R5 sentence with "Do not " fails the build.
  - Adding the sentence "Keep polling `task_status` until every task finishes." to `# T3 Code` fails the build as an unpinned sentence.
  - Swapping the R5 and R6 bullets fails the order check.
  - Dropping "with its `childRunId` as `runId`" from sentence 5 fails the build.
  - Dropping "commit first," from sentence 3 fails the build.
  - Moving the R3 sentence under `# Compound Engineering` fails both sections' checks.
- **Verification:** The check passes on the real template and fails on each mutation above.

### U3. Describe the new rules and check in the docs

- **Goal:** `docs/provisioning.md` describes what the `# T3 Code` section now holds and that the check pins it like the other checked sections.
- **Requirements:** R8.
- **Dependencies:** U1, U2.
- **Files:** `docs/provisioning.md`.
- **Approach:**
  1. In "Shared agent instructions", extend the description of the T3 Code section to say it launches independent delegated tasks together and waits for their results inside the turn.
  2. In the `agent-instructions` check paragraph, add `# T3 Code` to the sections that fail on an unpinned, missing, or reordered sentence.
- **Patterns to follow:** The existing wording of those two paragraphs.
- **Test scenarios:** Test expectation: none -- documentation only; `markdownlint-cli2` through the pre-commit hook covers its form.
- **Verification:** Both paragraphs match the shipped template and check.

---

## Verification Contract

| Command | Proves | Units |
| --- | --- | --- |
| `nix fmt -- --ci` | Nix formatting | U2 |
| `nix build --no-link .#checks.x86_64-linux.agent-instructions` | Rules reach every harness and are pinned | U1, U2 |
| Mutation runs in a scratch copy per U2's test scenarios | The new assertions can fail | U2 |
| `nix flake check` | Every declared check still evaluates and builds | U1, U2 |
| `nix build --no-link .#vmChecks.all`, then every `nixosConfigurations`, `homeConfigurations`, `systemConfigs` output per `AGENTS.md` | Host outputs still build with the new instructions | U1 |
| `mise run lint-staged-markdown` (pre-commit hook) | Markdown lint for the plan and docs | U3 |

macOS and aarch64 outputs build only on CI's runners; leave them to CI.

---

## Definition of Done

- U1 through U3 are complete and their verification holds.
- Every command in the Verification Contract that runs on this host passes, and each U2 mutation turned the check red before being reverted.
- No scratch copy, mutation, or abandoned attempt remains in the diff.
