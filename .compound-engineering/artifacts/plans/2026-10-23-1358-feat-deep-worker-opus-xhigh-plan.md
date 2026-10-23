---
title: Deep Worker on Opus at xhigh - Plan
type: feat
date: 2026-10-23
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Deep Worker on Opus at xhigh - Plan

## Goal Capsule

- **Objective:** When `ce-work` launches a `deep` implementation unit through a session's own Claude-capable subagent tool or through T3 Code's `delegate_task`, the unit runs on Claude Opus 5.5 at `xhigh` effort, while every other Claude role keeps running at its model's own default effort.
- **Means:** Rewrite the `deep` worker sentence and the two unit-launch sentences in the shared instructions template, and narrow the two effort guards to accept exactly that one assignment (KTD1, KTD2).
- **Authority:** This plan's R-IDs win on behavior; KTDs win on mechanism.
- **Stop conditions:** Stop if a check can only pass by accepting a Claude effort outside the `deep` sentence and its launch clauses.
- **Execution profile:** Nix template plus Nix/shell checks and docs; verified by `nix flake check` and the `agent-instructions` and `claude-effort-absent` checks.
- **Who finishes:** `ce-work` implements; `lfg` reviews and ships.

## Product Contract

### Summary

The `deep` category of `ce-work` moves from `fable` (`claude-fable-5-1`) to `opus` (`claude-opus-5-5`) with effort `xhigh`. The worker launch rules pass that effort on the native `Agent` route and the `delegate_task` route. The repository's checks keep refusing any other Claude effort.

### Problem Frame

The user wants hard-design and unknown-cause debugging units to run on Opus at `xhigh` rather than on Fable. The repository retired every Claude effort declaration earlier, and two checks (`tests/agent-instructions.nix` assignment rules, `tests/claude-effort-absent.nix` sentence scan) fail on any sentence that gives a Claude model an effort. This request is the user's decision to reintroduce one effort, for the `deep` worker only.

### Key Decisions

- **`deep` goes to Opus 5.5 at `xhigh`.** (session-settled: user-directed — chosen over `fable`, `claude-fable-5-1` with no effort: the user asked for Opus at xhigh for deep units.) Governs R1, R2.

### Requirements

**Instructions**

- R1. The `deep` category sentence assigns `opus`, `claude-opus-5-5` on the `claudeAgent` instance with `effort` `xhigh`.
- R2. The unit-launch rules pass a worker's effort, when its category names one, as the `Agent` tool's `effort` argument natively and as `effort` in `target.options` through `delegate_task`; a worker with no effort still launches with no effort and no `target.options`.
- R3. Every other Claude role (other categories, scouts, review peer, unassigned subagents, settings) stays effort-free.

**Guards**

- R4. The `agent-instructions` check accepts `claude-opus-5-5` with `effort` `xhigh` only inside the `deep` sentence, and still fails an effort on any other Claude assignment, including `xhigh` on the Claude Code candidate or the `unspecified-high` sentence.
- R5. The `claude-effort-absent` check accepts the exact `deep` sentence and the exact rewritten launch sentences, and still fails any other sentence naming Claude with an effort.

**Docs**

- R6. `docs/provisioning.md` and `docs/verification.md` describe the `deep` worker as Opus at `xhigh` and state that this is the one Claude effort the instructions name.

### Scope Boundaries

- No Claude Code settings change: `effortLevel` stays retired and absent from `~/.claude/settings.json`; the effort is per launch, not a session default.
- `claude-fable-5-1` stays in `home/h82/agents/tokscale.nix` pricing and in the unassigned-subagent sentence, because skills (for example `plan_model: fable`) may still name it.
- Unchanged routes: outside T3 Code, a session whose own subagent tool cannot run Claude models still hands the whole run to Compound Engineering's own route with one `claude-sonnet-5-5` recipient, because that route keeps one recipient per run; and a unit whose launch fails twice still runs on the orchestrator at its own model and effort.
- Considered and not built: a generic per-category effort table. One category takes an effort; a table would widen what the guards must accept. Evidence that would change this: a second category needing an effort.

## Planning Contract

### Key Technical Decisions

- KTD1. **Effort travels with the assignment phrase.** The `deep` sentence ends ``on the `claudeAgent` instance with `effort` `xhigh` ``, the same shape the Codex candidate uses for `reasoningEffort`, so the existing `assignmentRules` parser reads it without a new pattern. (session-settled: user-directed — chosen over `fable`, `claude-fable-5-1` with no effort: the user asked for Opus at xhigh for deep units.) Implements R1.
- KTD2. **Guards accept the exception by sentence, not by model and value.** A rule keyed only on `claude-opus-5-5:effort:xhigh` would let the existing "Claude Code candidate given the effort xhigh" mutation pass. `assignmentRules` must accept that tuple only on the line holding the `deep` sentence, and `claude-effort-absent` must exempt only exact pinned sentences. Implements R4, R5.
- KTD3. **Launch sentences name the effort conditionally.** `unitLaunchSentence` (template line with "launch each unit through that tool with the worker's alias as `model`") gains "and its effort, when its category names one, as `effort`" on the native route and "`effort` in `target.options` when its category names one, and no other `target.options`" on the `delegate_task` route. The Subagents `delegateRouteSentence` ("with the model ID and no `target.options`") gets the same exception so a Codex, OpenCode, or Pi session launching a `deep` unit carries it. Implements R2.

### Assumptions

- Verified: the Claude Code `Agent` tool's `effort` parameter lists `xhigh` among its values, and T3 Code's live catalog lists `xhigh` among `claude-opus-5-5`'s `effort` values on `claudeAgent`.
- An effort-free worker cannot inherit the parent's effort: a Claude session launches Claude workers only through its own `Agent` tool, whose omitted `effort` means the agent's usual effort, and only a Codex, OpenCode, or Pi session launches them through `delegate_task`, where options inherit only for the same instance and model, which a `claudeAgent` target never shares with those parents.

## Implementation Units

### U1. Instructions template

- **Goal:** Render the new `deep` assignment and the effort-carrying launch rules.
- **Requirements:** R1, R2, R3; KTD1, KTD3.
- **Dependencies:** none.
- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`.
- **Approach:**
  1. Replace the `deep` sentence's worker clause with `` `opus`, `claude-opus-5-5` on the `claudeAgent` instance with `effort` `xhigh` ``.
  2. Amend the unit-launch sentence and the Subagents `delegate_task` route sentence per KTD3.
  3. Leave the unassigned-subagent sentence ("use `opus` and `fable` only where...") unchanged.
- **Test scenarios:** covered by U2.
- **Verification:** the rendered `~/.claude/CLAUDE.md` holds the new sentences exactly once.

### U2. Instruction and effort guards

- **Goal:** Pin the new sentences and keep every other Claude effort refused.
- **Requirements:** R4, R5; KTD2.
- **Dependencies:** U1.
- **Files:** `tests/agent-instructions.nix`, `tests/claude-effort-absent.nix`.
- **Approach:**
  1. Update `deepSentence`, `unitLaunchSentence`, and `delegateRouteSentence` to the U1 text.
  2. Make `assignmentRules` accept `instance:claudeAgent:effort:claude-opus-5-5:xhigh` only for an assignment found on the `deep` sentence's line; update its header and inline comments, which say no Claude model carries an effort.
  3. In `claude-effort-absent.nix`, exempt the exact `deep` and launch sentences (pinned strings, not a pattern) and update its header comment.
  4. Replace the `withEffort "deep category"` fable mutations and the `withModel "deep category" ... fableModel opusModel` mutation per the scenarios below; drop `fableModel` if unused.
  5. Update the `releaseNotesDocTerms` comment ("Nothing declares a Claude effort").
- **Execution note:** Mutation-test each guard change per `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`; run it in a separate worktree, not a copied checkout.
- **Test scenarios:**
  - The `deep` sentence with `effort` `xhigh` passes both checks.
  - The `deep` sentence with `effort` `high` or `max` fails `agent-instructions` with "assigns a model an instance, knob, or effort it does not take: claude-opus-5-5 on claudeAgent with effort high".
  - The `deep` sentence with its effort clause removed fails the pin.
  - The `deep` sentence moved back to `fable`, `claude-fable-5-1` fails the pin.
  - The Claude Code candidate and the `unspecified-high` sentence given `effort` `xhigh` still fail `agent-instructions`.
  - A non-exempt sentence naming `opus` and the word `effort` still fails `claude-effort-absent`.
  - The launch sentences with the effort clause removed fail their pins.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.agent-instructions .#checks.x86_64-linux.claude-effort-absent` passes, and each listed mutation fails as described.

### U3. Docs

- **Goal:** Describe the new `deep` worker and its effort.
- **Requirements:** R6.
- **Dependencies:** U1.
- **Files:** `docs/provisioning.md`, `docs/verification.md`.
- **Approach:**
  1. In `docs/provisioning.md`, change the worker table's `deep` row to `opus`, `claude-opus-5-5`, effort `xhigh`.
  2. In the worker-table paragraph after it, scope every effort claim to the `deep` exception: "The table carries no effort ...", "with the model ID and no `target.options`", "Because a `delegate_task` launch for a Claude model passes no `target.options`", "retiring them is why `claude-opus-5-5` no longer appears at `xhigh` anywhere", and the claim that the `agent-instructions` check fails a Claude model assigned with any knob.
  3. Scope the settings paragraph's "No tier declares a Claude effort any more" and any "carry no Claude effort" sentence so they stay true about settings while naming the per-launch `deep` effort.
  4. Rewrite the Claude Code version-bump paragraph and the Subagents narrative to name the `deep` exception, keeping the pinned phrase "check the release notes of the new version for a changed default effort" word for word.
  5. In `docs/verification.md`, change the `ce-work` category item to expect `deep` on `opus` with effort `xhigh`, launched with `effort` natively and in `target.options` through `delegate_task`, and qualify the `orchestrator_capabilities` item's "pass no `target.options`" with the `deep` exception.
- **Test scenarios:** Test expectation: none -- prose only; the doc-term lists in `tests/agent-instructions.nix` must still pass unchanged.
- **Verification:** `nix flake check` passes, no doc line still says `deep` runs on `fable`, and no doc line still says the instructions name no Claude effort or that every Claude `delegate_task` launch carries no `target.options`.

## Verification Contract

| Gate | Command |
| --- | --- |
| Format | `nix fmt -- --ci` |
| Checks | `nix flake check` |
| Focused | `nix build --no-link .#checks.x86_64-linux.agent-instructions .#checks.x86_64-linux.claude-effort-absent` |
| Hosts | build every `nixosConfigurations` toplevel per `AGENTS.md` |

## Definition of Done

- R1-R6 hold, and the U2 mutation scenarios each fail as stated.
- No sentence outside the `deep` sentence and the launch sentences gives a Claude model an effort.
- No abandoned-attempt code remains in the diff.
