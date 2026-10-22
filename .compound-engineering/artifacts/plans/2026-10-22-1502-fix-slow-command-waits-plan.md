---
title: Wait for Slow Commands Instead of Rerunning Them - Plan
type: fix
date: 2026-10-22
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Wait for Slow Commands Instead of Rerunning Them - Plan

## Goal Capsule

- **Objective:** A delegated task that runs a slow test suite, build, or flake check runs it once and reports its result in the same turn, on Claude Code, OpenCode, and Antigravity alike.
- **Means:** Four new pinned sentences in the `# T3 Code` section of the shared agent instructions, next to the #301 foreground sentence (KTD1, KTD2).
- **Authority:** This plan, then issue [#303](https://github.com/hyperlapse122/nix-config/issues/303), then `AGENTS.md`.
- **Stop conditions:** Stop when a rule would need a term the check confines outside `# T3 Code` and `# Compound Engineering`, or when a U3 live run shows a harness behavior that contradicts KTD3; then revise the sentence before shipping.
- **Execution profile:** Lightweight; one template edit, its pins and mutants, one doc paragraph, and five live runs.
- **Who finishes:** `ce-work` implements and verifies; `lfg` reviews and ships.

## Product Contract

### Summary

Add four sentences to `home/h82/agents/instructions/instructions.md.tmpl` after the #301 foreground sentence. They tell each delegated task to set a timeout before a slow command, to wait inside the turn for a command the harness moved to the background, never to stop and rerun such a command except in named cases, and to start a command longer than the foreground limit in the background on purpose and wait for it. `tests/agent-instructions.nix` pins each sentence with a removal and a negation mutant, `docs/provisioning.md` describes them, and live T3 Code runs on all three harnesses show the rules hold.

### Problem Frame

The #301 rule tells a delegated task to run the commands its report depends on in the foreground and to wait inside the turn for one that outlasts the timeout, but it does not say how. A Claude Code child ran a pytest suite with no `timeout`, the Bash tool moved it to the background at 120000 ms, and the child stopped it with `TaskStop` and ran it again with a longer timeout. The first two minutes were wasted and the suite ran twice. A command longer than 600000 ms cannot run in Claude Code's foreground at all, so obeying "run in the foreground" leaves the child two bad moves: end the turn (#301) or rerun (#303). Claude Code's own Bash tool description adds a third pull: it tells the agent to wait with `Monitor`, which does not hold the turn.

### Requirements

**Timeouts up front**

- R1. Before a command that can take more than a minute, such as a test suite, a build, or a flake check, a delegated task gives it a timeout that covers its expected run, up to its shell tool's limit, with Claude Code's Bash tool as the example.

**Waiting for a backgrounded command**

- R2. When the harness moves a command the task waits on to the background, the task waits for it inside the turn with blocking foreground calls, each within the tool's limit, until the command's process has exited or the harness reports that it finished, and then reads its output and exit status.
- R3. The rule gives a Claude Code wait that holds the turn and cannot match itself, and says that `Monitor` and background notifications do not hold the turn, whatever the tool descriptions advise.
- R4. The task never stops and reruns a command the harness moved to the background. A missing or short timeout does not make a command wrong. It stops one only when it was the wrong command, or when it is still running at twice its expected time with no new output. A command the harness killed at its timeout is rerun once with a timeout that covers it, or with none where the tool allows that.

**Commands over the foreground limit**

- R5. A command expected to outlast the shell tool's foreground limit starts in the background on purpose, with its exit status written to a file, and the task waits for it the same way, never ending its turn while it runs. A time limit set in the task prompt still applies: at that limit the task reports what it has. A server the task keeps running for its own work, which the #301 sentence lets stay in the background, is not such a command.

**Guards and evidence**

- R6. `tests/agent-instructions.nix` pins each new sentence in `# T3 Code` order and fails a mutant that removes it and one that negates it, each with the expected message.
- R7. `docs/provisioning.md` describes the new rules and the harness facts behind them, and the check's doc-term list keeps that prose from dropping them.
- R8. Live T3 Code runs show each of R1, R2-R4, and R5 holding on Claude Code, and R1 on OpenCode and R2 on Antigravity.

### Scope Boundaries

- No rule against running two test suites in one checkout. The existing shared-checkout sentence already tells tasks that share a checkout to leave builds and checks to the parent while another task edits there, and R4 already rules out stopping a run because another run shares the machine. Evidence that would change this: a delegated task whose suite fails or corrupts results because another task's suite ran in the same checkout while nothing edited it.
- No rule for the top-level session. With a person present, its turn end is resumed by the background notification, so only the delegated task loses its result. Evidence that would change this: a top-level run that reruns a backgrounded suite.
- The #301 foreground sentence stays as written. The new sentences refine it, and rewording it would churn its pins and doc terms for no behavior change.
- Claude Code's Bash timeouts are not raised through provisioning (KTD5).

### Assumptions

- The run proceeds without the scoping confirmation because `lfg` runs it hands-off.
- The rules sit in `# T3 Code` as "Tell each delegated task" sentences, like the #301 sentence, because the parent's task prompt is the channel that reaches every child harness. Children on this machine also read the rendered instructions file. Whether the #303 child's prompt carried the #301 sentence is unknown; U3's prompts carry the new sentences, as a parent following the rules would send them.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Place the rules after the #301 foreground sentence, as four sentences the parent passes to each task.** The #301 sentence is the rule they complete, and the parent's task prompt is what a child on any provider reads. One sentence per requirement group (R1, R2-R3, R4, R5) keeps each pin and mutant independent.
- KTD2. **Write the sentences harness-neutrally with Claude Code as the only example.** Issue #303 asks for Claude Code tool names as the example. OpenCode and Antigravity facts change with their versions, so they live in `docs/provisioning.md` (U2) rather than in pinned strings; each child knows its own shell tool.
- KTD3. **Rest the rules on harness behavior read from the installed tools on 2026-10-22, and confirm it live in U3.**
  - Claude Code 2.1.308's Bash tool defaults to 120000 ms, takes at most 600000 ms in the foreground, and moves a longer command to the background with a task ID and an output file. It reports the end of a background command as a notification between tool calls. Its validator blocks a call whose first segment is `sleep N`, and its description tells the agent to wait with `Monitor` instead. `Monitor` does not block: it streams events while the agent keeps working, expires after at most 1800000 ms, and holds nothing open when the agent ends its turn. A foreground loop that starts with a process test, such as `until ! pgrep -f '[u]v run pytest' >/dev/null; do sleep 5; done` with a `timeout` under 600000 ms, passes the validator and holds the turn. The bracket keeps `pgrep -f` from matching the loop's own command line.
  - OpenCode 2.1.2's shell tool defaults to 120000 ms for a foreground command and kills it at the timeout (`status: "timeout"`); `timeout: 0` disables the limit, and `background: true` returns at once with a notification later. Its description tells the agent to end its response and be resumed, which is the #301 failure in T3 Code; R5's "never ending its turn" overrides it.
  - Antigravity CLI 1.4.5's `run_command` waits at most `WaitMsBeforeAsync` (500 to 10000 ms) before it backgrounds the command, and `command_status` waits for a background command by its ID. Every Antigravity command longer than 10 seconds lands under R2.
- KTD4. **Define the stop cases so a child can check them.** "Wrong" means the wrong command, never a missing or short timeout, which was the #303 child's reason. "Hung" means still running at twice the time the task expected when it set its R1 timeout, with no new output; a quiet but healthy build stays below that bar. The rerun of a killed command (R4) exists because OpenCode kills rather than backgrounds, so a killed run has no result to wait for.
- KTD5. **Keep the fix in instructions, not in Claude Code's `BASH_DEFAULT_TIMEOUT_MS` or `BASH_MAX_TIMEOUT_MS`.** Raising them covers Claude Code only: OpenCode kills at its own timeout and Antigravity backgrounds after 10 seconds whatever Claude Code's settings say. A larger default also makes every hung command in every session hold the foreground longer. The waiting and no-rerun rules are needed on all three harnesses either way.

### Sources

- Issue [#303](https://github.com/hyperlapse122/nix-config/issues/303) and its parent [#301](https://github.com/hyperlapse122/nix-config/issues/301).
- `.compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md`: why each pin needs a negation mutant.
- `.compound-engineering/artifacts/solutions/integration-issues/t3-thread-wait-cannot-carry-in-turn-delegation-waits-alone.md`: why a delegated task's turn end is its result.
- `tests/agent-instructions.nix`: `foregroundSentence`, `t3CodeSentences`, the `foreground sentence removed` and `foreground sentence negated` mutants, and `laterTurnDocTerms`.

---

## Implementation Units

### U1. Add the slow-command sentences and their pins

- **Goal:** The rendered instructions carry the four sentences, and the check fails when any of them is removed or negated.
- **Requirements:** R1, R2, R3, R4, R5, R6 (KTD1, KTD2, KTD3, KTD4).
- **Dependencies:** none.
- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`, `tests/agent-instructions.nix`.
- **Approach:**
  1. Insert the four sentences as bullets right after the #301 foreground bullet in `# T3 Code`, in the order R1, R2-R3, R4, R5.
  2. Name each sentence as a `let` binding beside `foregroundSentence` and list them after it in `t3CodeSentences`, in template order.
  3. Add a removal and a negation mutant for each, shaped like the foreground mutants, and add them to the header comment's list of mutants.
  4. Keep every term the check confines (`timeoutMs`, `t3_thread_wait`, `runtimeMode`, and the rest) out of the new sentences, so the confinement rule does not change.
- **Patterns to follow:** `foregroundSentence` and its two mutants in `tests/agent-instructions.nix`.
- **Test scenarios:**
  - The rendered Claude Code, OpenCode, and Antigravity files for every host hold each new sentence exactly once, where a sentence starts, in section order.
  - A mutant that deletes the R1 bullet fails with "does not hold this sentence exactly once, where a sentence starts:".
  - A mutant that prefixes the R1 bullet with "Do not" fails with the same message.
  - The same removal and negation mutants for the R2-R3, R4, and R5 bullets each fail with that message.
  - An unmutated rendering passes the self-test.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.agent-instructions` passes, and its self-test reports every new mutant as failing with its expected message.

### U2. Describe the rules in the provisioning guide

- **Goal:** `docs/provisioning.md` explains what the new sentences tell a task, the harness facts behind them, and why, and the check keeps that prose.
- **Requirements:** R7 (KTD2, KTD3, KTD5).
- **Dependencies:** U1.
- **Files:** `docs/provisioning.md`, `tests/agent-instructions.nix`.
- **Approach:**
  1. After the #301 sentence in the T3 Code paragraph, add prose naming the four rules, the per-harness facts from KTD3 with the versions they were read from, the reason for KTD5, and the #303 incident, linked.
  2. Add a short phrase from each new rule to a doc-term list in the check, beside `laterTurnDocTerms`, so a doc edit that drops a rule fails.
- **Patterns to follow:** how the #301 rule and `laterTurnDocTerms` pair the provisioning prose with the check.
- **Test scenarios:**
  - The check passes with the new prose in place.
  - Deleting one of the new doc phrases from `docs/provisioning.md` fails the check with "docs/provisioning.md no longer describes" and the phrase.
- **Verification:** the `agent-instructions` check passes, and `markdownlint-cli2` passes on `docs/provisioning.md` through the pre-commit hook.

### U3. Run the rules live in T3 Code

- **Goal:** Live evidence, on each harness, that a delegated task given the new sentences runs a slow command once and reports in the same turn.
- **Requirements:** R8 (KTD3).
- **Dependencies:** U1.
- **Files:** none.
- **Approach:** Launch five read-only delegated tasks in parallel. Each prompt carries the four sentences and asks the task to run a stand-in suite (a shell command that sleeps, then prints a pass line and exits 0) and report the pass line and exit status. Judge each from its session's `activity` view in T3 Code, which shows every tool call:
  1. Claude Code, stand-in of about 150 seconds, duration stated: proves R1 (a `timeout` over 150000 ms, one run).
  2. Claude Code, stand-in of about 150 seconds, described as usually under a minute: proves R2-R4 (the Bash tool backgrounds it, the task waits in the turn with foreground calls the validator accepts, no `Monitor` wait ending the turn, no `TaskStop`, one run).
  3. Claude Code, stand-in of about 660 seconds, duration stated: proves R5 (started in the background on purpose with an exit-status file, waited for across several foreground calls, reported in the same turn).
  4. OpenCode, stand-in of about 150 seconds, duration stated: proves R1 on OpenCode (a `timeout` that covers the run, or `0`; one run, not killed).
  5. Antigravity, stand-in of about 60 seconds: proves R2 on Antigravity (backgrounded after at most 10 seconds, waited for with `command_status`, one run).
- **Test expectation:** none -- this unit gathers live evidence and adds no code.
- **Verification:** each session shows one run of its command and a final report, in the same turn, holding the pass line and exit status. A run that contradicts KTD3 triggers the stop condition. The PR reports these results as live evidence, separate from the check results.

---

## Verification Contract

| Gate | Command | Proves |
| --- | --- | --- |
| Pins and mutants | `nix build --no-link .#checks.x86_64-linux.agent-instructions` | R1-R7 as text |
| Formatting | `nix fmt -- --ci` | Nix layout |
| Flake checks | `nix flake check` | No other check broke |
| Host outputs | the build loop in `AGENTS.md` for every `nixosConfigurations` and `homeConfigurations` output this builder can build | The instructions still render on every host |
| Live runs | U3, runs 1 to 5 | R1 (run 1), R2-R4 (run 2), R5 (run 3) on Claude Code; R1 on OpenCode (run 4); R2 on Antigravity (run 5) |

macOS and aarch64 outputs build in CI.

## Definition of Done

- U1 and U2 land, and every gate in the Verification Contract passes on this builder.
- U3's five live runs are reported, each with its outcome, in the PR body.
- No abandoned attempt or scratch file is left in the diff.
