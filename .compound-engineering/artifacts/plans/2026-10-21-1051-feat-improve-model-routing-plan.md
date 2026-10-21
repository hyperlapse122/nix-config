---
title: OmO-Aligned Implementation Worker Routing - Plan
type: feat
date: 2026-10-21
topic: improve-model-routing
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# OmO-Aligned Implementation Worker Routing - Plan

## Goal Capsule

- **Objective:** `ce-work` implementation units in T3 Code route to the model family and effort level best matched to each unit's category (`quick`, `writing`, `visual-engineering`, `unspecified-low`, `unspecified-high`, and `deep`) with an ordered primary-to-fallback chain instead of alternating tiers round-robin across providers.
- **Means:** Replace the three-tier round-robin worker rules in `home/h82/agents/instructions/instructions.md.tmpl` with `oh-my-openagent`-aligned category chains and update `tests/agent-instructions.nix`, `docs/provisioning.md`, and `docs/verification.md` to match (KTD1, KTD2, KTD3).
- **Authority hierarchy:** Product Requirements (`R1`-`R9`) govern what the instructions state; Key Technical Decisions (`KTD1`-`KTD3`) govern exact sentence structure and test constraints.
- **Execution profile:** 2 sequential units (`U1` template + test update, `U2` documentation sync + check verification).
- **Stop conditions:** Stop only if `nix build .#checks.x86_64-linux.agent-instructions` fails and cannot be resolved within the sentence and term rules of `tests/agent-instructions.nix`.
- **Who finishes and ships:** The autonomous `lfg` workflow executes `ce-work`, `ce-simplify-code`, `ce-code-review`, `ce-commit-push-pr`, and `ce-babysit-pr`.

---

## Product Contract

### Summary

Replace the three-tier round-robin `ce-work` worker alternation in `home/h82/agents/instructions/instructions.md.tmpl` with `oh-my-openagent`-aligned semantic task categories (`quick`, `writing`, `visual-engineering`, `unspecified-low`, `unspecified-high`, and `deep`), each backed by an ordered primary-to-fallback model chain across `claudeAgent` and `antigravity`, and synchronize the pinned sentence checks in `tests/agent-instructions.nix` and documentation in `docs/provisioning.md` and `docs/verification.md`.

### Problem Frame

The current `# Compound Engineering` instructions classify `ce-work` implementation units into three coarse difficulty tiers (`harder`, `default`, `lighter`) and alternate the `harder` and `default` tiers sequentially between Claude and Gemini in plan order, while giving `lighter` units no Gemini fallback and forcing `claude-haiku-5-5` to `xhigh` or `max` effort. Sequential alternation ignores qualitative differences between model families—such as Gemini 4 Argon's strength at prose and visual/UI engineering at low effort, Haiku 5.5 and Flash 3.8 Low's speed on mechanical edits, and Claude Opus 5.5's sustained reasoning on multi-file and architectural work—and leaves lighter units without a fast cross-provider fallback before dropping to the default tier.

### Key Decisions

- **Route `ce-work` units by `oh-my-openagent` task categories and ordered fallback chains rather than alternating per tier** (session-settled: user-directed — chosen over keeping three-tier round-robin alternation or a simple two-tier split: aligns worker selection with `oh-my-openagent`'s `agent-model-matching` category chains and matches each model family to its strength). Governs R1, R2, R3, R4, R5, R6.
- **Use `gemini-4-argon-low` as primary for `writing` and `visual-engineering` and `gemini-3.8-flash-low` as fallback for `quick`** (session-settled: user-approved — chosen over `gemini-4-argon-medium` and `gemini-3.8-flash-high`: matches `oh-my-openagent`'s speed and effort profile for prose, UI/UX, and mechanical tasks). Governs R2, R3, R4, R8.
- **Keep splittable mechanical work split and cohesive hard work whole** (session-settled: user-approved — chosen over uniform unit sizing: follows `oh-my-openagent`'s decomposition discipline so independent small edits fan out to `quick` or `unspecified-low` workers while tightly coupled design or debugging stays in one `unspecified-high` or `deep` unit). Governs R1.

### Requirements

**Category Classification and Decomposition**

- R1. In `ce-work`, classify each implementation unit into one category—`quick`, `writing`, `visual-engineering`, `unspecified-low`, `unspecified-high`, or `deep`—splitting independent mechanical or small edits into `quick` or `unspecified-low` units while keeping cohesive hard work whose reasoning would suffer if split as one `unspecified-high` or `deep` unit.
- R2. Route a `quick` unit (mechanical edits such as a rename, pinned-text sync, boilerplate, config tweak, or one-file copy fix, even across files) to `claude-haiku-5-5` on `claudeAgent` with `effort` `medium` as primary, and to `gemini-3.8-flash-low` on `antigravity` as fallback.
- R3. Route a `writing` unit (documentation, READMEs, guides, and prose authoring or revision beyond a mechanical one-line sync) to `gemini-4-argon-low` on `antigravity` as primary, and to `claude-opus-5-5` on `claudeAgent` with `effort` `low` as fallback.
- R4. Route a `visual-engineering` unit (frontend, UI/UX, styling, CSS, layout, animation, and design-system work) to `gemini-4-argon-low` on `antigravity` as primary, and to `claude-opus-5-5` on `claudeAgent` with `effort` `max` as fallback.
- R5. Route an `unspecified-low` unit (a small or moderate standard implementation unit that fits no specialized category above) to `claude-sonnet-5-5` on `claudeAgent` with `effort` `medium` as primary, and to `gemini-3.8-flash-high` on `antigravity` as fallback.
- R6. Route an `unspecified-high` unit (multi-file feature work across modules following known patterns) to `claude-opus-5-5` on `claudeAgent` with `effort` `medium` as primary, and a `deep` unit (hard new interface, data format, or concurrency design, subtle cross-module debugging, or work carrying a security or data-loss risk even when the edit is mechanical) to `claude-opus-5-5` on `claudeAgent` with `effort` `max` as primary, with `gemini-4-argon-medium` on `antigravity` as fallback for both.

**Fallback Resolution and Harness Constraints**

- R7. Inside T3 Code, launch each unit on its category's primary worker first and use the category's fallback worker when the primary worker is unavailable or its launch fails twice, preserving the existing `work_engine_mode: off` rule, the Grok/OpenCode implementation-unit rules, and the outside-T3-Code single-recipient fallback naming the `unspecified-low` category's candidates (`claude` with `claude-sonnet-5-5` and then `antigravity` with `gemini-3.8-flash-high` at effort `high`).
- R8. Update `tests/agent-instructions.nix` so `compoundEngineeringSentences`, `t3CodeSentences`, and `removedTerms` match the new category-chain sentences (removing `"flash-low"` from `removedTerms` while keeping unhyphenated display labels and unused model IDs forbidden), update `docs/provisioning.md` (`Shared agent instructions`) to describe the category-based routing and updated `removedTerms` list, and update `docs/verification.md` (lines 140 and 142) to verify the new worker models, explicit Claude efforts, and category-based `ce-work` delegation.
- R9. Ensure every sentence in `home/h82/agents/instructions/instructions.md.tmpl` contains no internal period-space sequence, no unescaped tilde outside code spans, and passes `nix build .#checks.x86_64-linux.agent-instructions`.

### Acceptance Examples

- AE1. **Covers R2, R7.** **Given** a `ce-work` unit that updates pinned sentence strings in `tests/agent-instructions.nix` and `docs/provisioning.md` to match template changes, **When** `ce-work` delegates the unit in T3 Code and `claudeAgent` is available, **Then** it classifies the unit as `quick` and launches it on `claudeAgent` with `claude-haiku-5-5` and `effort: "medium"`; if `claudeAgent` fails or is unavailable, it launches the unit on `antigravity` with `gemini-3.8-flash-low`.
- AE2. **Covers R3, R4.** **Given** a prose documentation rewrite unit (`writing`) and a frontend styling unit (`visual-engineering`), **When** `ce-work` delegates both in T3 Code, **Then** both launch on `antigravity` with `gemini-4-argon-low` as primary, and on fallback `writing` uses `claude-opus-5-5` with `effort: "low"` while `visual-engineering` uses `claude-opus-5-5` with `effort: "max"`.
- AE3. **Covers R6.** **Given** a unit that changes a SOPS encryption rule or concurrency invariant (`deep`) versus a multi-file feature across existing modules (`unspecified-high`), **When** `ce-work` delegates them on `claudeAgent`, **Then** both target `claude-opus-5-5`, with `effort: "max"` for `deep` and `effort: "medium"` for `unspecified-high`, and both fall back to `gemini-4-argon-medium` on `antigravity`.

### Scope Boundaries

- Cross-model review peer pairs (`{{ .peers.first }}` and `{{ .peers.second }}` for `ce-code-review`, `ce-doc-review`, `ce-pov`, and `ce-bakeoff`) and read-only subagent routing in `# T3 Code` (line 83) remain unchanged.
- No GPT/OpenAI/Codex or OpenCode Zen providers are introduced; routing uses only the configured `claudeAgent` and `antigravity` provider instances.

### Sources / Research

- `home/h82/agents/instructions/instructions.md.tmpl:63-91` — current `ce-work` implementation worker rules and `# T3 Code` subagent fallback wording.
- `tests/agent-instructions.nix:273-348,442-465` — pinned `compoundEngineeringSentences`, `t3CodeSentences`, and `removedTerms`.
- `docs/provisioning.md:288-307` — documentation of the shared agent instructions (`ce-work` worker rules at lines 299-301 and `agent-instructions` check at line 307).
- `docs/verification.md:140-142` — hardware verification checklist items for `orchestrator_capabilities` worker models and `ce-work` child thread delegation.
- `code-yeongyu/oh-my-openagent` (`https://omo.dev/ko/docs#agent-model-matching` and `packages/senpi-task/src/category/fallback-chains.ts`) — category definitions (`quick`, `writing`, `visual-engineering`, `unspecified-low`, `unspecified-high`, `deep-*`, `ultrabrain`) and ordered model chains.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Express the six categories, their primary/fallback chains, and the outside-T3-Code `unspecified-low` fallback in compact, period-safe sentences in `# Compound Engineering`** (session-settled: user-directed — chosen over keeping three-tier round-robin alternation: implements R1-R7 while respecting `tests/agent-instructions.nix`'s `sectionSentences` parser, which splits sentences on period-space). Replace lines 68-74 and update line 76 (`"the default tier"` to `"the unspecified-low category"`) in `home/h82/agents/instructions/instructions.md.tmpl`, avoiding internal period-space sequences and banned substrings from `removedTerms` (`"Model routing"`, `"another harness"`, `"Pick the model by harness"`, `"Flash low"`, `"flash-medium"`, etc.).
- KTD2. **Remove `"flash-low"` from `removedTerms` in `tests/agent-instructions.nix` and `docs/provisioning.md`** (session-settled: user-approved — chosen over keeping `gemini-3.8-flash-high` for `quick`: allows `gemini-3.8-flash-low` as the `quick` category fallback per R2 and R8 while continuing to forbid unhyphenated `"Flash low"` and unused `"flash-medium"`, `"flash-lite"`, `"flash-free"`, and `"gemini-4-argon-high"`).
- KTD3. **Update only line 87 in `# T3 Code` from `"a tier's other worker"` to `"a category's fallback worker"`, leaving line 83 unchanged**: keeps `# T3 Code` consistent with `# Compound Engineering` now that implementation units use category chains rather than two-worker tiers, without altering read-only subagent tier selection (R7, R8).

---

## Implementation Units

### U1. Update `instructions.md.tmpl` and `tests/agent-instructions.nix` for category-based worker routing

- **Goal:** Replace the three-tier alternation sentences in `home/h82/agents/instructions/instructions.md.tmpl` with `oh-my-openagent`-style category chains and update `tests/agent-instructions.nix` to pin the new sentences and allow `gemini-3.8-flash-low`.
- **Requirements:** R1, R2, R3, R4, R5, R6, R7, R8, R9, KTD1, KTD2, KTD3.
- **Files:**
  - `home/h82/agents/instructions/instructions.md.tmpl`
  - `tests/agent-instructions.nix`
- **Approach:**
  - In `home/h82/agents/instructions/instructions.md.tmpl` under `# Compound Engineering`, replace the 7 tier-classification, worker-mapping, and alternation sentences (lines 68-74) with category-classification, sizing, and primary/fallback worker sentences covering `quick`, `writing`, `visual-engineering`, `unspecified-low`, `unspecified-high`, and `deep`, plus the T3 Code primary-then-fallback rule, and update line 76 to name the `unspecified-low` category instead of `"the default tier"`.
  - In `home/h82/agents/instructions/instructions.md.tmpl` under `# T3 Code` (line 87), update `"such as a tier's other worker"` to `"such as a category's fallback worker"` (leaving line 83 unchanged).
  - In `tests/agent-instructions.nix`, update `compoundEngineeringSentences` and `t3CodeSentences` to match the exact sentences in `home/h82/agents/instructions/instructions.md.tmpl`, and remove `"flash-low"` from `removedTerms`.
- **Test Scenarios:**
  - Rendered files across all four harnesses (`claude-code`, `opencode`, `antigravity`, `grok`) match expected outputs byte-for-byte.
  - `sectionSentences` order check passes for `# Compound Engineering` and `# T3 Code`.
  - Self-test mutants in `tests/agent-instructions.nix` continue to fail as expected.
- **Verification:** `nix build .#checks.x86_64-linux.agent-instructions -L`

### U2. Synchronize `docs/provisioning.md` and `docs/verification.md` with category-based worker routing

- **Goal:** Update `docs/provisioning.md` and `docs/verification.md` so the prose describing `ce-work` implementation unit routing, the `agent-instructions` check's `removedTerms` list, and the hardware verification checklist match `home/h82/agents/instructions/instructions.md.tmpl` and `tests/agent-instructions.nix`.
- **Requirements:** R8, R9, KTD2, KTD3.
- **Dependencies:** U1.
- **Files:**
  - `docs/provisioning.md`
  - `docs/verification.md`
- **Approach:**
  - Update `docs/provisioning.md:299-301` to describe the six `ce-work` task categories (`quick`, `writing`, `visual-engineering`, `unspecified-low`, `unspecified-high`, and `deep`), the decomposition discipline (split independent mechanical pieces, keep cohesive hard work whole), each category's primary and fallback worker and effort, and the outside-T3-Code fallback (`unspecified-low` candidates).
  - Update `docs/provisioning.md:307` to remove `` `flash-low` `` from the list of forbidden terms checked by `agent-instructions`.
  - Update `docs/verification.md:140` and `docs/verification.md:142` to verify `gemini-3.8-flash-low`, `gemini-3.8-flash-high`, `gemini-4-argon-low`, and `gemini-4-argon-medium` on `antigravity`, explicit Claude worker efforts (`low`, `medium`, `max`), and category-based `ce-work` delegation across categories.
- **Test Scenarios:**
  - Documentation prose in `docs/provisioning.md` and `docs/verification.md` contains no retired tier terms (`two-worker tier`, `lighter unit`, `harder unit`, `default unit`) and no unescaped tildes outside code spans.
- **Verification:** `! grep -nE 'two-worker tier|lighter unit|harder unit|default unit' docs/provisioning.md docs/verification.md && nix build .#checks.x86_64-linux.agent-instructions -L`

---

## Verification Contract

| Command | Applicability | Units | Done Signal |
| --- | --- | --- | --- |
| `nix build .#checks.x86_64-linux.agent-instructions -L` | Required | U1, U2 | Exits 0 and produces `result` store path |
| `! grep -nE 'two-worker tier\|lighter unit\|harder unit\|default unit' docs/provisioning.md docs/verification.md` | Required | U2 | Exits 0 (no stale tier terminology remains in docs) |

---

## Definition of Done

- All requirements `R1`-`R9` and technical decisions `KTD1`-`KTD3` are satisfied in `home/h82/agents/instructions/instructions.md.tmpl`, `tests/agent-instructions.nix`, `docs/provisioning.md`, and `docs/verification.md`.
- `nix build .#checks.x86_64-linux.agent-instructions -L` passes with exit code 0.
- No sentence in `home/h82/agents/instructions/instructions.md.tmpl` contains an internal period-space sequence or an unescaped tilde outside a code span, and no stale tier terminology remains in `docs/provisioning.md` or `docs/verification.md`.
