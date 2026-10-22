---
title: Haiku Scouts in Claude Code Sessions - Plan
type: feat
date: 2026-10-22
topic: haiku-scouts-in-claude-code
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Haiku Scouts in Claude Code Sessions - Plan

## Goal Capsule

- **Objective:** `ce-plan`'s research scouts return faster when the user plans from a Claude Code session in T3 Code, because they no longer wait on DeepSeek V4.1 Flash, which the user finds too slow.
- **Means:** the scout assignment sentence in the shared instructions sends scouts to `claude-haiku-5-5` on `claudeAgent` when the harness is Claude Code, keeps DeepSeek for every other harness, and keeps Sonnet `medium` as the one fallback (KTD1, KTD2).
- **Authority:** this plan's Product Contract owns behavior; KTDs own mechanism.
- **Execution profile:** one branch, one pull request.
- **Stop conditions:** stop and report when a new mutant in `tests/agent-instructions.nix` cannot be made to fail with its expected message.

---

## Product Contract

Product Contract preservation: new contract (ce-plan-bootstrap).

### Summary

Change one pinned sentence in `home/h82/agents/instructions/instructions.md.tmpl` so a Claude Code session launches every `ce-plan` scout on Haiku, and move the `agent-instructions` check, its self-test mutants, and the docs with it.

### Problem Frame

Inside T3 Code, every `ce-plan` scout (repository, learnings, framework-docs, best-practices, and web researchers) goes to `synthetic/hf:deepseek-ai/DeepSeek-V4.1-Flash-1017` at `variant` `high`. From a Claude Code session the user waits on those scouts before any plan is written, and DeepSeek V4.1 Flash is too slow for that. Haiku runs on the same provider as the session and is the small Claude model the instructions already use as the `quick` fallback.

### Requirements

- R1. When the harness is Claude Code and the session lists T3 Code's delegation tools, each scout goes to `claude-haiku-5-5` on the `claudeAgent` instance with `effort` `medium` as primary.
- R2. In any other harness, each scout keeps going to the DeepSeek entry's `scout` role on the `opencode` instance as primary.
- R3. In both cases, the fallback stays `claude-sonnet-5-5` on `claudeAgent` at `effort` `medium`, and the relaunch-on-no-findings, research-yourself handoff, scout definition, and scout safeguard rules stay as they are.
- R4. The `agent-instructions` check pins the new sentence and fails when the Claude Code branch loses Haiku, when Haiku becomes unconditional, or when Haiku gets an effort the assignment rule forbids.
- R5. `docs/provisioning.md`, `docs/verification.md`, and `CONCEPTS.md` describe the new routing, and every mutant count they state matches the check.

### Key Decisions

- **Haiku is the primary scout model in a Claude Code session.** (session-settled: user-directed — chosen over keeping DeepSeek V4.1 Flash for Claude Code sessions: it is too slow for the user.) Governs R1.

### Scope Boundaries

- Scouts of OpenCode and other harnesses are unchanged (R2).
- The DeepSeek `scout` role in `home/h82/agents/synthetic-models.nix` stays, because the non-Claude-Code branch still reads it.
- `ce-work` units, cross-model peers, and other subagents are not touched. The user asked about scouting only; `ce-work`'s `quick` and `unspecified-low` units still start on DeepSeek from a Claude Code session, and moving them is a follow-up the user can request if the same slowness matters there.
- Outside T3 Code nothing changes, as today.

### Sources / Research

- `home/h82/agents/instructions/instructions.md.tmpl` line 97: the scout assignment sentence.
- `tests/agent-instructions.nix`: `scoutAssignmentSentence` and its clauses near line 300, the scout mutants near line 1048, and `assignmentRules`, which allows `low`, `medium`, or `high` for a non-Opus Claude model on `claudeAgent`.
- `docs/provisioning.md` lines 287, 302, and 319 (mutant counts), `docs/verification.md` lines 35 and 149, `CONCEPTS.md` line 83 (Scout).
- No solution under `.compound-engineering/artifacts/solutions/` covers scout routing. The mutation-testing and substring-sentence learnings named in `AGENTS.md` apply to the new mutants.

## Planning Contract

### Key Technical Decisions

- **KTD1. The harness condition is prose, not a template branch.** The template is rendered once and read by Claude Code, OpenCode, and Antigravity, and it uses no `if`, so the sentence states "when your harness is Claude Code" and each harness applies it at runtime. The instructions already speak of "your harness" in other rules.
- **KTD2. One sentence with a shared fallback.** The sentence names the Haiku primary for Claude Code, then "otherwise" the DeepSeek primary, then the one Sonnet fallback for both, so `scoutFallbackClause`, `scoutRelaunchClause` ("that fallback"), and `scoutFailedLaunchClause` keep their wording and existing mutants keep working. The sentence must not contain `another harness` or `Pick the model by harness`: the check's removed-terms guard rejects both retired phrases case-insensitively anywhere in the file, and that guard stays. Directional shape: "... a scout goes to `claude-haiku-5-5` on the `claudeAgent` instance with `effort` `medium` as primary when your harness is Claude Code and otherwise to `synthetic/<deepseek>` on the `opencode` instance with `variant` `<scout role>` as primary, and in either case to (fallback clause)(failed-launch clause)."
- **KTD3. Haiku runs at `effort` `medium`.** It matches the `quick` fallback's Haiku effort and the effort `docs/verification.md` line 144 already lists for `claude-haiku-5-5`, and the assignment rule accepts it.

### Assumptions

- Haiku is fast and capable enough for read-and-summarize scouting; Sonnet stays the fallback when it returns no findings. A Haiku scout that often returns no findings would pay for a Sonnet relaunch and could end slower than DeepSeek, which the post-deploy timing step counts.
- The safeguard sentence's provider notice ("Synthetic for OpenCode and Anthropic for Claude Code") already covers a Haiku scout.

### Risks & Dependencies

- A rewording can leave a mutant passing; each new mutant must be seen to fail with its expected message before shipping.

### Sequencing

U1 then U2; one commit each or one together.

## Implementation Units

### U1. Rewrite the scout assignment sentence and its pins

- **Goal:** R1-R4.
- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`, `tests/agent-instructions.nix`.
- **Approach:** rewrite the sentence per KTD2 in the template; mirror it in `scoutAssignmentSentence` (add a named `scoutHaikuClause` for the Claude Code primary so mutants can edit it); add mutants: (a) the Claude Code branch rewritten to the DeepSeek primary, expecting the pinned-sentence message; (b) the harness condition removed so Haiku reads as unconditional, expecting the pinned-sentence message; (c) Haiku at `effort` `max`, expecting `assigns a model an instance, knob, or effort it does not take: claude-haiku-5-5 on claudeAgent with effort max`. Update the header comment's mutant list if it names scout mutants by kind.
- **Patterns:** existing scout mutants and `replaceInLine`.
- **Test scenarios:** the check passes on the rendered file; each new mutant fails with its expected message; the existing scout mutants still fail as expected.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.agent-instructions`.

### U2. Bring the docs in line

- **Goal:** R5.
- **Files:** `docs/provisioning.md`, `docs/verification.md`, `CONCEPTS.md`.
- **Approach:** describe the Haiku primary for Claude Code sessions and the DeepSeek primary otherwise at provisioning line 287 (Compound Engineering summary) and 302 (scout routing), and at line 302 limit the #291 web-search caveat to scouts that route to the `opencode` instance; update the mutant counts at provisioning 319 and verification 35 to the check's real counts; rewrite verification 149 so a Claude Code session expects a `claudeAgent` Haiku scout at `effort` `medium` and the turn naming the scout and Anthropic before launching, and add a step that an OpenCode session still sends scouts to DeepSeek and names Synthetic; move the closing `ce-brainstorm` check (its scouts do not move to the `opencode` instance) into that OpenCode step, where the DeepSeek primary can still tell a misrouted brainstorm scout apart; add a timing step: from a Claude Code session, run the repository research scout on the same small feature at least twice on Haiku and twice on DeepSeek, record each scout's wall-clock time and any fallback relaunch, and report them; update the Scout entry in `CONCEPTS.md`.
- **Test scenarios:** `nix flake check` passes, including markdown lint via the pre-commit hook.
- **Verification:** counts in docs equal the number of entries in `selfTestMutants`.

## Verification Contract

- `nix fmt -- --ci`, `nix flake check`.
- `nix build --no-link .#checks.x86_64-linux.agent-instructions` with the new mutants.
- The rendered `~/.claude/CLAUDE.md` for every host holds the new sentence exactly once.
- After deploy (manual, `docs/verification.md`): the timed Haiku-versus-DeepSeek scout comparison, at least two samples each, with fallback relaunches counted. The rendered instructions reach a session only after the user applies the generation, so the PR lists this as pending hardware verification rather than claiming the speed-up.

## Definition of Done

- R1-R5 hold, the checks pass, and the PR reports the check results.
