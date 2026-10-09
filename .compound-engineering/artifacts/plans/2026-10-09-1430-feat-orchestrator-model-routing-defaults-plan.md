---
title: User-Default Model Routing for Compound Engineering Work - Plan
type: feat
date: 2026-10-09
topic: orchestrator-model-routing-defaults
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# User-Default Model Routing for Compound Engineering Work - Plan

## Goal Capsule

- **Objective:** When an agent runs Compound Engineering (CE) work, the model behind each scout, worker, and reviewer is predictable and explainable. A project's own settings and the user's live instructions still decide whenever they speak.
- **Means:** A new `# Model routing` section, a rewritten `# Cross-model delegation` section, and a tools bullet that points at both, all in the shared template `home/h82/agents/instructions/instructions.md.tmpl`, which renders for Claude Code, Codex, and Antigravity (KTD1).
- **Authority:** Issue #185 and this plan's R-IDs govern behavior. `AGENTS.md` governs repository conventions and verification.
- **Open blockers:** None.
- **Stop conditions:** Stop if the wording cannot avoid a backticked native tool name from another harness's absent list in `tests/agent-instructions.nix`, a mention of Orca in any letter case, or a `{{`/`}}` sequence, because the check rejects each.
- **Execution profile:** Lightweight. One template edit and one check edit. They are verified by rendering the instructions locally, mutation-testing the new assertions, and building the x86_64-linux check in CI.
- **Product Contract preservation:** Clarified, no scope change. R4 names the table row each tier fills. R6 gains its fallback when Antigravity is not runnable. R8 counts the routing table among the namers of effort. R11 states which model a retried CE pass uses. R12 gains the inherit-and-say rule for a subagent tool that cannot select a model. R13's list follows these changes. The three questions deferred to planning are resolved in KTD2–KTD4.

---

## Product Contract

### Summary

The shared agent instructions gain a role table. It maps the abstract model tiers that CE skills ask for to concrete model classes for each orchestrating harness. The table is a default the agent may leave with a one-line reason, and it sits below project config, project instructions, and conversation. CE keeps full control of cross-model review: whether it runs, and on which model and effort. T3 Code only carries the run.

### Problem Frame

Inside T3 Code the orchestrator picks models case by case. On the Telegram cask change (a 9-line code diff), CE activated a cross-model pass for both the doc review and the code review. Both ran on Codex `gpt-6.1-sol` at xhigh because the instructions' latest-in-class rule overrode CE's own mapping of `gpt-6-luna`. After a 401 the review was retried on Gemini 3.1 Pro, and it returned no findings. Scouts and workers meanwhile inherit the session model (`opus[1m]`), so cheap retrieval and routine implementation run on the most expensive class.

One instruction sentence also reads as forcing: it tells the agent to delegate through T3 "before any of the skill's own discovery or launch steps". That can skip the skill's own gates, `cross_model_review_mode` among them. The issue asked for a stated policy. The user wants that policy as a default for CE, not a rule that overrides projects.

### Key Decisions

- **The policy is a user default for CE routing, not a general orchestration policy.** It does not say when the orchestrator should do work itself versus delegate. (session-settled: user-directed — chosen over a stated keep-or-delegate boundary: the instruction is only the user's default for compound-engineering.) Governs R1, R3.
- **A guide, not a rule.** (session-settled: user-directed — chosen over pure reference and over reporting every delegation: the table is the starting point, and leaving it costs one line of reason.) Governs R2.
- **One role table with per-harness same-provider alternatives.** (session-settled: user-directed — chosen over per-harness defaults only and over a single harness-blind table.) Governs R4, R5.
- **Scout split by urgency.** (session-settled: user-directed — chosen over Gemini Flash low everywhere and over native-only: a T3 child spins up a whole thread, so the #184 Flash scout took about 3.5 minutes.) Governs R6.
- **CE owns cross-model review end to end.** (session-settled: user-directed — chosen over downshifting the peer model and effort on small changes, which conflicts with CE's rule that a lower tier is adopted only after an eval, never from cost alone.) Governs R9, R10.
- **Use each model's default effort.** (session-settled: user-directed — chosen over the #165 rule to set effort instead of inheriting defaults: `gpt-6.1-sol` at its default low scores higher than `gpt-6-sol` at medium, so the harness default is respected.) Governs R8.
- **Exclude Gemini 3.1 Pro by version, and Codex Terra and Claude Fable by class.** (session-settled: user-directed — Gemini 3.8 Flash scores higher than 3.1 Pro. Excluding only the 3.1 version keeps a future Pro that beats Flash eligible. Terra and Fable are excluded as whole classes at the user's direction.) Governs R7.

### Requirements

**Authority and strength**

- R1. Each routing choice follows this order: the user's conversation, then the project's instructions and CE config (`.compound-engineering/config.local.yaml`, then `config.yaml`) in the order the invoked skill defines, then this user default, then the skill's own default mapping.
- R2. The agent may choose a model other than the table's default; when it does, it tells the user in one line which model it chose and why.
- R3. The instructions do not prescribe which work the orchestrator keeps and which it delegates.

**Role table**

- R4. The instructions map the tiers CE skills request to the role table's rows for each orchestrating harness. Cheapest capable (extraction) maps to the short-scout row. Mid-tier (the Sonnet class in CE's own Claude Code mapping) and the native ce-work worker both map to the worker row.
- R5. The default worker class is Sonnet when Claude orchestrates, Luna when Codex orchestrates, and Flash medium when Antigravity orchestrates.
- R6. A short scout whose result the orchestrator needs right away uses the orchestrator's own cheapest class; a broad scout that can run in the background goes to Gemini Flash low through T3 when Antigravity is runnable, and otherwise uses the orchestrator's own cheapest class.
- R7. Routing never selects Gemini 3.1 Pro (`gemini-pro-agent`, `gemini-3.1-pro-low`), any Codex Terra model, or any Claude Fable model.
- R8. A delegated or subagent run uses the chosen model's default effort unless the routing table, the skill, its config, the project, or the user names one. An Antigravity cell's effort suffix is how the table names it.

**Cross-model review**

- R9. Whether a cross-model pass runs is decided only by the invoking CE skill and its config, including `cross_model_review_mode`; the instructions never start one the skill would not run and never skip the skill's gates.
- R10. When a CE cross-model pass runs through T3, its model and effort come from `cross_model_model` and `cross_model_effort` when set, otherwise from the skill's own mapping. The latest-in-class rule does not replace a model the skill named.
- R11. When a delegated task fails, the retry goes to another runnable T3 provider. A retried CE cross-model pass uses the skill's mapping for that provider when the skill has one, and the latest Flash at high on Antigravity, which CE does not map.

**Reach and guard**

- R12. Same-provider choices in the table apply in every session; cross-provider routing applies only when the T3 Code MCP tools are available. When the native subagent tool cannot select the table's class and T3 is unavailable, the subagent inherits the session model, and the agent says so per R2.
- R13. The repository check that pins the instruction text fails when any of R1, R2, and R4–R12 is dropped or moved into one harness's branch.

### Acceptance Examples

- AE1. **Covers R9, R10.** **Given** a small diff for which `ce-code-review` selects the adversarial reviewer and no `cross_model_*` keys are set, **when** the pass runs through T3, **then** it runs on Codex `gpt-6-luna` at xhigh (the skill's mapping), not on `gpt-6.1-sol`.
- AE2. **Covers R9.** **Given** a project whose `config.yaml` sets `cross_model_review_mode: off` and a user who has not asked for a peer, **when** `ce-code-review` runs, **then** no T3 task is delegated and the local reviewers run as usual.
- AE3. **Covers R11, R7.** **Given** a Codex review task that fails with 401, **when** the agent retries on Antigravity, **then** it uses `gemini-3.8-flash-high`, not `gemini-pro-agent`.
- AE4. **Covers R5, R8, R2.** **Given** a Claude Code orchestrator dispatching a native ce-work worker, **when** nothing upstream names a model, **then** the worker runs on Sonnet at its default effort. If the agent instead picks Opus, it tells the user why in one line.
- AE5. **Covers R1.** **Given** a project whose config sets `work_engine_mode: prefer` with Codex first, **when** ce-work dispatches a unit, **then** the project's preference wins over the role table.
- AE6. **Covers R6.** **Given** a Claude Code orchestrator that needs a quick file lookup before its next step, **when** it scouts, **then** it uses a native Haiku subagent rather than a T3 child.

### Scope Boundaries

- No boundary between orchestrator work and delegated work (R3).
- No new cross-model triggers, size gates, or effort downshifts for small changes; CE owns those (R9).
- No change to how T3 Code lists or orders models in `orchestrator_capabilities`.
- No pinned model versions in the table except the excluded Gemini 3.1 Pro; the table names classes, and the existing latest-in-class rule picks the version.
- No change to CE plugin code or to any project's `.compound-engineering/config.yaml`.

### Dependencies / Assumptions

- The runnable catalog on 2026-10-09: Codex `gpt-6.1-sol`, `gpt-6-astra`, `gpt-6-luna`; Claude `claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5`; Antigravity `gemini-3.8-flash-{low,medium,high}`. No Flash-Lite id exists.
- T3 does not mark which model is newest; "latest" is read from the version in the id.
- Assumption (unverified): CE ce-work native workers set no model and so inherit the session model. CE's `execution-strategy.md` names no tier, but no CE text states inheritance outright.
- CE skills contain no T3 Code integration, so T3 delegation stays an instruction-level substitution for the skill's own launch route.

The questions this contract deferred to planning are resolved in KTD2 (shared table), KTD3 (Codex cheapest class), and KTD4 (class-example sentence).

### Sources / Research

- `home/h82/agents/instructions/instructions.md.tmpl` (Cross-model delegation section) and `tests/agent-instructions.nix` (`delegationSentences`).
- `.compound-engineering/artifacts/plans/2026-10-06-1412-feat-t3-mcp-cross-model-delegation-plan.md` (#163) and `.compound-engineering/artifacts/plans/2026-10-06-1741-feat-latest-model-in-class-plan.md` (#165).
- CE v3.30.4: `ce-code-review/references/cross-model-review.md` (gates, `cross_model_*` precedence, "never from cost alone"), `ce-code-review/scripts/cross-model-adversarial-review.sh` (codex `gpt-6-luna` xhigh, claude `claude-opus-5-5` high), `ce-doc-review/SKILL.md` (lens-triggered pass), `ce-work/references/execution-engines.md` (engine precedence), `ce-brainstorm/references/model-tiers.md` (tiers).
- `home/h82/t3code.nix` (`textGenerationModelSelection` is already `gemini-3.8-flash-low`).

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Two top-level sections replace the one.** A new `# Model routing` section carries R1–R8 and R12 and applies in every session. The existing `# Cross-model delegation` section keeps the T3 mechanics and gains R9–R11. The current delegation section opens by limiting itself to sessions with T3 tools, so same-provider routing placed inside it would vanish outside T3, which R12 forbids.
- KTD2. **One shared role table, with no harness branch.** Rows are roles (short scout, broad scout, worker), filled per R4's tier mapping, and columns are the orchestrating harness (Claude Code, Codex, Antigravity). Every harness renders the same table, so R13 can pin each row the same way in all three files. Cells name classes (Sonnet, Luna, Haiku) rather than version ids, so the #165 latest-in-class rule keeps picking the version. Flash cells carry their effort suffix (`low`, `medium`), because Antigravity puts effort in the model id. Governs R4–R6.
- KTD3. **Luna is the Codex orchestrator's cheapest class, for both scout and worker.** The catalog has no Codex class below Luna, and CE's own Codex review mapping uses Luna. This is an assumption: no price data was read. Governs R5, R6.
- KTD4. **The class-example sentence names only routable classes.** It becomes "Sol, Luna, or Astra for Codex; Opus, Sonnet, or Haiku for Claude; Flash for Gemini". R7's exclusions (Gemini 3.1 Pro by id, Terra, Fable) get one sentence of their own, so the rule has one owner.
- KTD5. **The effort sentence is replaced, and the version rules stay.** The #165 sentence that says to set effort instead of inheriting defaults gives way to R8. The latest-in-class, compare-within-class, and older-version sentences stay. One new sentence says that a model named by the skill, its config, the project, or the user wins over latest-in-class (R10). (session-settled: user-directed — chosen over the #165 effort rule: harness defaults are respected.) Governs R8, R10.
- KTD6. **The forcing sentence is rewritten so that T3 replaces only the launch.** The rewrite keeps the substitution of T3 for the skill's discovery and launch route. It drops "before any of the skill's own discovery or launch steps" and states that the skill's gates, `cross_model_review_mode` among them, decide first. Governs R9.
- KTD7. **The check pins whole sentences and whole table rows as fixed strings.** `delegationSentences` is updated in place, and a new `routingSentences` list holds the R1, R2, R4, R6, R7, R8, and R12 sentences plus each table row. The R10 and R11 sentences go in `delegationSentences`. A whole-row match fails when any cell changes. Clause-by-clause matching would miss that, as `.compound-engineering/artifacts/solutions/best-practices/compound-condition-clause-assertions-miss-connective-mutations.md` shows. No negative assertion is added for the removed sentences: a reintroduced old sentence would sit beside the new one and contradict it, and that is caught by review, not by a check.
- KTD8. **Local verification renders the macOS host's instructions.** This Mac has no x86_64-linux builder, and `checks.aarch64-darwin` holds only `darwin-outputs`. So the implementer renders the shared template through the macOS host's `darwinConfigurations` output and runs the check's fixed-string greps against the three rendered files from a scratch script. CI's `check-shards` job builds the real `agent-instructions` check.

### Assumptions

- Luna is the cheapest runnable Codex class (KTD3).
- ce-work native workers inherit the session model unless the orchestrator names one, so R5's worker default changes the model they run on.

---

## Implementation Units

### U1. Rewrite the routing and delegation instructions

- **Goal:** The shared template states the user-default routing guide and lets CE own cross-model review.
- **Requirements:** R1–R12, through KTD1, KTD2, KTD3, KTD4, KTD5, and KTD6.
- **Dependencies:** None.
- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`.
- **Approach:**
  1. Add `# Model routing` between the tools section and `# Cross-model delegation`. It holds one sentence each for R1, R2, R3 (no keep-or-delegate boundary), R4, R6's fallback, R7, R8, and R12, plus the KTD2 table. Name no native subagent tool in backticks: the table and sentences say "the native subagent tool".
  2. In `# Cross-model delegation`, rewrite the forcing sentence per KTD6. Replace the class-example sentence per KTD4 and the effort sentence per KTD5. Add the R10 sentence. Change the fallback sentence per R11.
  3. Point the tools bullet that says "When the work needs a different model, follow Cross-model delegation below instead" at both sections.
- **Patterns to follow:** The existing sections' style: one rule per bullet, an imperative voice, and identifiers in backticks only where a reader types them.
- **Test scenarios:** Covered by U2's check and the U2 mutation rounds.
- **Verification:** The three rendered files carry identical `# Model routing` and `# Cross-model delegation` sections. Each file names no tool from another harness's absent list and contains no `{{` or `}}`.

### U2. Pin the new rules in the agent-instructions check

- **Goal:** Dropping, rewording, or moving into one harness's branch any rule R13 names turns the check red.
- **Requirements:** R13, through KTD7.
- **Dependencies:** U1.
- **Files:** `tests/agent-instructions.nix`.
- **Approach:**
  1. Update `delegationSentences` to U1's final cross-model sentences.
  2. Add a `routingSentences` list and a `requireSentences` call for it, labeled as the model-routing rule.
  3. Update the header comment so it lists what the two lists protect.
- **Patterns to follow:** The existing `reviewFindingsSentences` and `branchNameSentences` lists and their `requireSentences` calls.
- **Test scenarios:**
  - Covers AE1. Rendering the KTD6 sentence and the R10 sentence makes the check pass. Removing either from the template makes it fail, naming that sentence.
  - Covers AE3. Changing the R11 fallback to name Gemini Pro instead of Flash makes the check fail.
  - Removing the R12 inherit-and-say sentence makes the check fail.
  - Covers AE4. Changing the Claude Code worker cell from Sonnet to Opus makes the check fail on that table row.
  - Moving the `# Model routing` section inside the Claude Code tools branch makes the check fail for the Codex and Antigravity files.
  - The unmutated tree passes.
- **Verification:** Each mutation is observed red in the KTD8 local render, and the tree is then restored and observed green. CI's `check-shards` builds `checks.x86_64-linux.agent-instructions` green.

---

## Verification Contract

| Gate | Command | Proves |
| --- | --- | --- |
| Format | `nix fmt -- --ci` | Nix formatting unchanged |
| Markdown lint | `mise run lint-staged-markdown` (pre-commit hook) | The plan passes `markdownlint-cli2`. The template is a `.tmpl` file outside the lint globs, so the KTD7 fixed-string assertions cover its table rows. |
| Local render | Build the macOS host's `darwinConfigurations.<host>.system` and grep the three rendered instruction files for every pinned sentence and row (KTD8) | R1–R12 text reaches every harness |
| Mutation | The U2 rounds against the local render | R13's assertions are not decorative |
| Darwin checks | `nix build --no-link .#checks.aarch64-darwin.darwin-outputs` | The macOS fixture still builds |
| Linux checks | CI `flake-check`, `check-shards`, `vm-checks`, and `build` jobs on the pull request | `agent-instructions` and every Linux output build |

The x86_64-linux check, the VM tests, and the Linux host outputs cannot build on this Mac. They stay pending until CI passes on the pull request.

## Definition of Done

- U1 and U2 have landed. The three rendered instruction files carry the new sections identically.
- Each U2 mutation was observed red, and the tree was then restored and observed green.
- The local gates in the Verification Contract pass, and CI is green on the pull request.
- No mutation edits or scratch scripts remain in the diff.
