---
title: T3 Code PR Watch Handoff - Plan
type: fix
date: 2026-10-15
topic: t3-code-pr-watch-handoff
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# T3 Code PR Watch Handoff - Plan

## Goal Capsule

- **Objective:** Inside T3 Code, every pull or merge request an agent opens or pushes to shows as watched in its thread, and T3 Code's wakes drive its babysitting, whichever skill shipped it.
- **Means:** Amend the `# Pull and merge requests` section of `home/h82/agents/instructions/instructions.md.tmpl`.
- **Product authority:** The user, in the 2026-10-15 brainstorm. This work builds on the [forge-neutral PR babysitting plan](2026-10-15-1558-feat-forge-neutral-pr-babysitting-plan.md) and changes only how its T3 Code path waits, how it ends, and how it handles tool failures.
- **Open blockers:** None.
- **Stop conditions:** Stop and report when a change would need an edit to the Compound Engineering plugin's own files, or would weaken an existing pinned sentence's meaning.
- **Execution profile:** One documentation-and-check change, implemented and verified by `ce-work`, then shipped through `lfg`.

---

## Product Contract

### Summary

Inside T3 Code, `ce-babysit-pr` still runs each babysit tick, but T3 Code's watch replaces the skill's own watcher for the wait between ticks. That holds whether the agent babysits directly, through `ce-commit-push-pr`'s handoff, or through `lfg`. The section also defines when the T3 Code tools count as available, and how the agent recovers when a call to one of them fails.

### Problem Frame

The section added on 2026-10-15 tells agents to link a request, run one tick, then call `watch_pull_request` and end the turn. Both GitHub pull requests opened in T3 Code later that day skipped the watch.

- **PR #215 (`lfg`).** The agent linked the PR, then followed `lfg` step 10 into `ce-babysit-pr mode:pipeline` and waited on `pr-snapshot watch`. `lfg` says to invoke that babysit "unconditionally", and `ce-commit-push-pr` forbids arming a watcher outside `ce-babysit-pr`. The template names no skill rule that gives way to it, unlike `# Review findings`, so the more specific skill text won.
- **PR #216.** The agent opened the PR in a turn woken by a background-command notification. `link_pull_request` failed twice with `The calling provider no longer owns an active thread run.` The agent took that as "T3 Code unavailable" and fell back to the skill's watcher. In the next user-started turn, the same tools worked. The template never defines "available", has no rule for a T3 tool call that fails, and states the deferred-tools rule only under `# Cross-model delegation`.

In both cases the thread showed no watch and got no wake, and the user had to ask for the T3 Code watch by hand.

### Key Decisions

- **T3 Code's watch replaces only the wait.** `ce-babysit-pr` keeps its tick engine, delegates, budgets, and stop conditions. (session-settled: user-approved — chosen over keeping `lfg`'s synchronous `pr-snapshot watch` with T3 Code's watch only for display, and over bypassing `ce-babysit-pr` with hand-run ticks: it keeps the skill's repair logic and moves only the wait.) Governs R1, R2, R3, R4.
- **`lfg` babysits to looks-ready under T3 Code.** (session-settled: user-approved — chosen over unwatching at `lfg`'s "CI decided" stop: it matches the template's rule to babysit until a request looks ready.) Governs R5.
- **A failed tool call does not mean T3 Code is unavailable.** The PR #216 error came from one turn, and the same tools worked in the next. Governs R6, R7, R8, R9.

### Requirements

**Who waits**

- R1. Inside T3 Code, `ce-babysit-pr` runs every tick, but the wait between ticks moves to T3 Code's watch.
- R2. Wherever `ce-babysit-pr` would arm `pr-snapshot watch` or wait synchronously in pipeline mode, the agent calls `watch_pull_request` and ends its turn instead. Each T3 Code wake runs the next tick.
- R3. R1 and R2 hold on every path into babysitting: direct, `ce-commit-push-pr`'s babysit handoff, and `lfg` step 10.
- R4. The section lists the skill rules that give way to it, as `# Review findings` does. The list covers `ce-babysit-pr`'s default `pr-snapshot watch` sustain mode, its pipeline mode's synchronous wait and its rule never to wait on the settle window or human review, `lfg`'s stop at "CI decided", and `lfg`'s rule not to end the turn before `<promise>DONE</promise>`. The bridge watcher R7 arms is the one exception to the first item.

**`lfg` close-out**

- R5. Under T3 Code, `lfg` reports its result and prints `<promise>DONE</promise>` in the turn where `ce-babysit-pr mode:pipeline` reaches its CI-decided stop. That turn keeps the watch. Later wakes keep babysitting until looks-ready, a blocker, or the budget, and only then does the agent call `unwatch_pull_request`.

**Availability and failed calls**

- R6. T3 Code's pull request tools count as available when the session lists `link_pull_request`, `watch_pull_request`, and `unwatch_pull_request` by name, including as deferred tools whose schemas must be loaded before the first call.
- R7. When a T3 Code pull request tool call fails, the agent arms `ce-babysit-pr`'s watcher as a temporary bridge and retries the failed call at the next tick, not reporting T3 Code as unavailable.
- R8. Once `watch_pull_request` succeeds, the agent stops the bridge watcher, so only one wait runs.
- R9. When `unwatch_pull_request` fails at a babysit stop, the final report says T3 Code still watches the request.

**Checks**

- R10. `tests/agent-instructions.nix` pins each new or changed sentence of the section the way it pins the section's current sentences.

### Acceptance Examples

- AE1. **Covers R2, R3.** **Given** a T3 Code session where `lfg` has opened a PR, **when** step 10 runs, **then** `ce-babysit-pr` runs one tick, the agent calls `watch_pull_request` and ends the turn, and no `pr-snapshot watch` process runs.
- AE2. **Covers R5.** **Given** an `lfg` PR whose CI has passed, **when** a review comment arrives later, **then** a T3 Code wake runs a tick that handles the comment. `unwatch_pull_request` runs only once the PR looks ready.
- AE3. **Covers R7, R8.** **Given** a turn where `link_pull_request` fails with `The calling provider no longer owns an active thread run.`, **when** the agent continues, **then** it arms the bridge watcher. At the next tick it retries `link_pull_request` and `watch_pull_request`, and it stops the bridge once the watch succeeds. No report says T3 Code is unavailable.
- AE4. **Covers R6.** **Given** a session that lists `watch_pull_request` only as a deferred tool, **when** babysitting reaches its wait, **then** the agent loads the tool's schema and calls it.

### Scope Boundaries

- Fixing or reporting the run-ownership error in T3 Code itself.
- Editing the Compound Engineering plugin's skill files. The instruction section overrides them instead.
- GitLab-specific readiness rules, which already use the same ticks.
- The `AGENTS.md` settle-window paragraph (`AGENTS.md:69`), which already covers a T3 Code watch.

### Dependencies / Assumptions

- T3 tool calls fail only sometimes in turns that a background notification starts. In the PR #215 thread, such a turn called `list_thread_pull_requests` successfully. In the PR #216 thread, a similar turn's calls failed.

### Sources / Research

- `home/h82/agents/instructions/instructions.md.tmpl`: the `# Pull and merge requests` section, the deferred-tools sentence under `# Cross-model delegation`, and the override list in `# Review findings`.
- `tests/agent-instructions.nix:171-195`: `pullRequestSentences`, the pinned sentences of the section.
- `ce-commit-push-pr/references/apply-and-handoff.md:39-45`, `lfg/references/shipping.md:29-33`, and `ce-babysit-pr/SKILL.md:39` in the Compound Engineering plugin: the babysit handoff, the unconditional pipeline babysit, and the `pr-snapshot watch` default.
- [Forge-neutral PR babysitting plan](2026-10-15-1558-feat-forge-neutral-pr-babysitting-plan.md): the plan that introduced the section.

Product Contract preservation: changed: the two Deferred to Planning questions were removed, and KTD3, KTD4, and KTD6 now answer them. Document review then changed four requirements. R4 adds the bridge exception and the two skill rules that otherwise keep the turn open. R5 says when `lfg` prints DONE. R6 names the three tools. R9 drops the retry. Key Decisions and Acceptance Examples are unchanged.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Change only the instruction template and its pinned-sentence check.** The section's rules reach every harness through `home/h82/agents/instructions/instructions.md.tmpl`, and `tests/agent-instructions.nix` already guards that section with `requireSentences`, `onlyPinnedSentences`, and `sentencesInSection`. A new sentence that is not pinned fails the build, so the check and the template change together. Covers R1–R10.
- KTD2. **Keep every existing sentence, and add new ones beside it.** The current T3 Code link-then-watch sentence, the wake-tick sentence, and the two "T3 Code is unavailable" sentences stay true under R1–R9. The new sentences narrow what they mean rather than replacing them. So no sentence moves to `supersededDirectives`, and the risk that an old sentence comes back is avoided. Covers R1, R2, R6.
- KTD3. **Each wake continues the invocation the first tick started.** `ce-babysit-pr` starts its budget only on the first snapshot, with `--start-invocation`, and every later snapshot or watch arm must present the recorded `RUN_INVOCATION_ID`, `RUN_STARTED_AT`, and `RUN_BUDGET_SECONDS` (`ce-babysit-pr/references/tick.md`). A fresh invocation on each wake would restart the budget, so the budget stop would never come. So on each T3 Code wake, the agent runs the next tick under the recorded invocation and never passes `--start-invocation` again. This holds on every path, `lfg` step 10 included. Covers R2, R3, R5.
- KTD6. **`lfg` closes out at the CI-decided stop and keeps babysitting after DONE.** Pipeline mode stops once CI is decided and never waits on the settle window or human review (`ce-babysit-pr/references/watch-loop.md`). `lfg` forbids ending a turn before `<promise>DONE</promise>` (`lfg/references/task-visibility.md`). Under T3 Code, `lfg` prints its close-out and DONE in the turn where the pipeline stop returns, keeps the watch, and ends the turn. Later wakes run ticks under the same invocation with the sustain-mode stops (looks-ready, blocker, budget). Their delegates stay `mode:pipeline`, so nothing prompts the user. Covers R4, R5.
- KTD4. **The bridge watcher takes the 30-minute wait's place.** While the bridge watcher runs, it already wakes on every change, so no 30-minute wait starts beside it. Once `watch_pull_request` succeeds, the agent stops the bridge and starts the 30-minute wait the section already requires. Under the project's `AGENTS.md`, the bridge is `ce-babysit-pr`'s own watcher, so it is armed with `--settle-seconds 0`. Covers R7, R8.
- KTD5. **The new sentences avoid a period followed by a space inside a sentence.** The section checks split text on period-space. The run-ownership error is quoted with no trailing period, so a sentence that names it still reads as one pinned sentence. Covers R10.

### Assumptions

- A harness that cannot run a background command also cannot run the bridge. There the existing foreground-sleep sentence still applies: the agent relies on T3 Code's wakes, and when none can arrive it reports the open request.

### Sequencing

U1 is the only unit. The template and the check must land in one commit, or the build fails between them.

---

## Implementation Units

### U1. Amend the T3 Code babysitting rules and pin them

**Goal:** Inside T3 Code, the `# Pull and merge requests` section makes T3 Code's watch the wait on every babysitting path. It also defines availability and covers failed T3 Code calls.

**Requirements:** R1–R10, with KTD1–KTD6. It implements the session-settled Key Decisions that govern R1–R5.

**Dependencies:** None.

**Files:**

- `home/h82/agents/instructions/instructions.md.tmpl`
- `tests/agent-instructions.nix`

**Approach:**

1. In the template's `# Pull and merge requests` section, add these bullets after the existing `link_pull_request` bullet, in this order:
   - The availability rule (R6).
   - The wait-replacement rule (R1, R2).
   - The every-path rule (R3).
   - The `lfg` close-out rule and the post-DONE babysitting rule (R5, KTD6).
   - The failed-call bridge rule (R7, R8, KTD4).
   - The failed-`unwatch_pull_request` report rule (R9).
2. Close the T3 Code bullets with the give-way list (R4), shaped like `# Review findings`'s "These skill rules give way to this one" sentence.
3. Add each new sentence to `pullRequestSentences` in `tests/agent-instructions.nix`, in section order.
4. Keep the wording harness-neutral: name the T3 Code tools without a prefix, as the section already does.

**Technical design (directional wording, final text is the implementer's):**

- "The T3 Code pull request tools are available when the session lists `link_pull_request`, `watch_pull_request`, and `unwatch_pull_request` by name, even when the harness must load their schemas before the first call."
- "Inside T3 Code, `ce-babysit-pr` still runs every tick, but where it would arm `pr-snapshot watch` or wait between pipeline ticks, call `watch_pull_request` and end your turn instead."
- "This holds when you babysit a request directly, through `ce-commit-push-pr`'s babysit handoff, and in `lfg` step 10."
- "On each T3 Code wake, run the next tick under the invocation the first tick started, presenting its recorded token, start time, and budget, and never start a new invocation."
- "Under T3 Code, `lfg` prints its close-out and `<promise>DONE</promise>` in the turn where `ce-babysit-pr mode:pipeline` reaches its CI-decided stop, keeps the watch, and ends that turn."
- "Later wakes keep babysitting under the same invocation until looks-ready, a blocker, or the budget, with every delegate still in `mode:pipeline`."
- "A failed call to a T3 Code pull request tool, such as `The calling provider no longer owns an active thread run`, does not make T3 Code unavailable: arm `ce-babysit-pr`'s own watcher as a bridge in place of the 30-minute wait, and retry the failed call at the next tick."
- "Once `watch_pull_request` succeeds, stop the bridge watcher and start the 30-minute wait."
- "When `unwatch_pull_request` fails at a babysitting stop, say in your final report that T3 Code still watches the request."
- "Inside T3 Code, these skill rules give way to this section: `ce-babysit-pr`'s default `pr-snapshot watch` sustain mode, except for the bridge watcher above, its pipeline mode's wait between ticks and its rule never to wait on the settle window or human review, `lfg`'s stop once CI is decided, and `lfg`'s rule not to end the turn before `<promise>DONE</promise>`."

**Patterns to follow:**

- `# Review findings`' give-way sentence, for the shape of R4.
- The existing `pullRequestSentences` list and its three helpers in `tests/agent-instructions.nix`.

**Test scenarios:**

- Covers AE1. The rendered instructions for each harness carry the wait-replacement and every-path sentences, and `requireSentences` passes.
- Covers AE2. The rendered instructions carry the `lfg` close-out and post-DONE sentences, which name looks-ready as the stop, and the same-invocation sentence.
- Covers AE3. The rendered instructions carry the bridge and stop-the-bridge sentences.
- Covers AE4. The rendered instructions carry the availability sentence, which names deferred-schema loading.
- Mutation: delete each new sentence from the template, one at a time. The check fails and names that sentence.
- Mutation: reword one new sentence without updating the pin. `onlyPinnedSentences` reports it as unpinned.
- Mutation: move the give-way sentence into `# Review findings`. `sentencesInSection` fails.
- Mutation: add an unpinned contradicting sentence, such as "Inside T3 Code, arm `pr-snapshot watch` as usual." `onlyPinnedSentences` fails.

**Execution note:** Run the mutations in a scratch copy only after reading `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`, and confirm each mutation turns the check red for its own reason.

**Verification:** The `agent-instructions` check passes on the change and fails on each mutation above. The rendered Claude Code, Codex, and Antigravity instruction files each carry every new sentence under `# Pull and merge requests`.

---

## Verification Contract

| Gate | Command | Proves |
| --- | --- | --- |
| Instruction check | `nix build --no-link .#checks.x86_64-linux.agent-instructions` | R1–R10 sentences render for every harness and are pinned |
| Formatting | `nix fmt -- --ci` | Nix layout of the edited check |
| Flake checks | `nix flake check` | Nothing else regressed |
| Markdown lint | `mise run lint-staged-markdown` (pre-commit hook) | The plan and any edited Markdown |
| Host outputs | The `AGENTS.md` build loop over `nixosConfigurations`, `homeConfigurations`, `systemConfigs` | The rendered instructions still build into every host generation off a Mac |

VM tests are unaffected by an instruction-text change, but `AGENTS.md` requires them before shipping, so `nix build --no-link .#vmChecks.all` also runs. macOS outputs are left to CI's `build-darwin` job.

## Definition of Done

- Every new sentence is in the template's `# Pull and merge requests` section and in `pullRequestSentences`.
- Every mutation in U1's test scenarios turned the check red, and each was reverted.
- Every command in the Verification Contract passed.
- No scratch copy, mutation edit, or abandoned wording remains in the diff.
