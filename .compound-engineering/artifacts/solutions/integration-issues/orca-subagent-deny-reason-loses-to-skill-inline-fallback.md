---
title: A PreToolUse deny reason loses to a skill's inline fallback, so denied subagents run inline instead of on Orca workers
date: "2026-09-28"
category: integration-issues
module: "Orca subagent guard (Claude Code hooks and session-start guide)"
problem_type: integration_issue
component: tooling
symptoms:
  - "Inside an Orca terminal, scripts/orca-subagent-guard denies Claude Code's Agent tool, yet the model does the delegated work in its own session"
  - "ce-doc-review's reviewer Agent calls end denied with 0 tool uses, then the model says it will apply both reviewer lenses itself per the fallback"
  - "The model justifies skipping Orca workers by saying the user did not ask for supervision"
root_cause: logic_error
resolution_type: code_fix
severity: medium
related_components:
  - development_workflow
tags: ["orca", "claude-code", "pretooluse", "subagent", "orchestration", "hooks", "deny-reason", "live-probe"]
---

# A PreToolUse deny reason loses to a skill's inline fallback, so denied subagents run inline instead of on Orca workers

## Problem

Inside an Orca terminal (`ORCA_PANE_KEY` set), `scripts/orca-subagent-guard` denies Claude Code's `Agent`/`Task` tools so that delegation goes to Orca workers. The model read the denial as "subagents unavailable" and did the delegated work itself, so no Orca worker ever started.

## Symptoms

- With `ce-doc-review`, two reviewer `Agent` calls were denied and shown as "0 tool uses / Done". Claude then said it would apply both reviewer lenses itself, "per the fallback".
- In probes, the model cited the Orca guide's role table: the user had not asked for supervision, so it took the fallback.
- No `orca orchestration worker-start` call was made.

## What Didn't Work

- **The original deny reason.** It ended "... or do the work yourself in this session" (`git show 7ad1411:scripts/orca-subagent-guard`), so the hook itself offered the inline path. Live probes: 5/5 runs went inline.
- **Rewording the deny reason alone.** The new reason said delegation was still available, offered no inline path, and named `worker-start`. Probes still went inline 2/5 times. The model treated the prompt's own "otherwise run inline" clause as a user instruction that outranks a hook message, and one run judged a three-line document too small to be worth workers.
- **Trusting single runs.** Outcomes varied from run to run. Only repeated probes, three or more per variant, told the variants apart.

## Solution

Two changes that state one rule, on branch `hyperlapse122/fix-orca-orchestration-inline` (PR pending, unmerged as of this writing).

**1. The deny reason** (`REASON`, `scripts/orca-subagent-guard:24`; the same text is emitted for Antigravity at `scripts/orca-subagent-guard:66`). It now:

- says the denial does not mean delegation is unavailable;
- says the denied call is itself the request to supervise, "however small it is", so the guide's Coordinator role applies;
- gives the re-dispatch: load `/orchestration`, run `orca orchestration worker-start --spec "<that subagent's full prompt>"` once per denied subagent, wait for each `worker_done`, and use its report as the subagent's result;
- forbids "a skill's or prompt's inline or serial fallback" and doing the delegated work in the session;
- allows in-session work only when `worker-start` refuses because the session is at Orca's nesting depth limit. Any other Orca failure means report the error and stop.

**2. A standing rule in the session-start guide** (`DELEGATION_NOTE`, `scripts/orca-orchestration-context:50`). It is appended to the last delivered part, before the takeover note, for Claude Code (`:136`) and Antigravity (`:146`). It says that any skill, prompt, or plan calling for subagents is a request to supervise, and that the inline or serial fallback "never applies here". `PART_BYTES` dropped from 8000 to 7500 (`scripts/orca-orchestration-context:33`) so the last Claude part, which now carries three notes, stays under Claude Code's 10,000-character hook-output cap.

Both texts are asserted by `check_reason` in `tests/orca-subagent-guard.sh:103` (run against the Claude output at `:113` and the Antigravity output at `:129`) and by the delegation-note assertions in `tests/orca-orchestration-context.sh`. In this session, both tests were run against the pre-fix sources and failed on the missing wording.

## Why This Works

Three things combined:

1. The old reason handed the model an inline alternative.
2. Compound Engineering skills say to "otherwise run the work inline or serially" when subagents are unavailable (for example line 3 of `skills/ce-doc-review/references/dispatch.md` in the compound-engineering plugin v3.29.0, outside this repository), and a denial reads as unavailability.
3. The session-start Orca guide reserves the Coordinator role for an explicit user request to supervise, which gave the model a stated reason to decline Orca.

A deny reason arrives at the decision point, but it competes with fallback text in the prompt or skill, and the model weighs that text as an instruction. The reworded reason alone brought the inline rate from 5/5 to 2/5. The fix closes each gap. The reason rules out the "unavailable" reading, turns the denied call into the authorization the role table asks for, and offers no inline path except the depth-limit case. The session-start note makes the same rule standing context, so it is more than a late tool-result message.

Probe setup (this session; not reproducible from the repo alone): `claude -p --dangerously-skip-permissions --settings <file>` in a scratch directory, with the PreToolUse guard and the SessionStart context hooks, `ORCA_PANE_KEY` set, and a fake `orca` on `PATH` that forwarded `skills get` to the real CLI and logged and failed every other call. The prompt mimicked a skill with an "otherwise run inline" clause.

| Variant | Inline runs |
| --- | --- |
| Old reason | 5/5 |
| Reworded reason only | 2/5 |
| Reworded reason and `DELEGATION_NOTE` | 0/3 (each tried the Orca path and stopped on the stub's error) |

The samples are small, especially the last row. They show the combination held in these runs, not a guaranteed rate.

## Prevention

A harness-level refusal that must redirect the model to another path needs all four of these:

- **Deny "unavailable".** Say the capability still exists on another path, so a skill's "if subagents are unavailable" branch does not fire.
- **Turn the denied call into the authorization** the other path requires; here, the explicit request to supervise that the guide's role table asks for.
- **Offer no inline alternative** except a narrow, checkable one (here, `worker-start` refusing at the nesting depth limit), with "report and stop" for every other failure. The depth-limit exception came from review: without it, a worker already at the cap had no way to finish work that used to succeed.
- **Back it with a standing session-start rule.** The deny message alone loses to explicit fallback text.

Also:

- Measure with repeated live probes, three or more per variant, using a stub CLI that logs calls. Count attempts at the target path against inline work.
- `REASON` and `DELEGATION_NOTE` state the same rule in two files; change them together. Read the mutation-testing solutions that `AGENTS.md` lists before changing their assertions.
- Any addition to the session-start guide competes with the hook-output cap. `PART_BYTES` had to shrink to make room, and the context test checks the worst case.

## Related Issues

- [Antigravity PreToolUse hook contract and how to probe it safely](antigravity-pretooluse-hook-contract-and-probing.md): the same guard's payload and decision contract, and how to probe a hook without breaking the user's setup.
- Plan: `.compound-engineering/artifacts/plans/2026-09-28-1704-feat-orca-harness-subagent-deny-plan.md`, which introduced the guard and scoped compound-engineering skills' subagent steps as simply refused inside Orca.
