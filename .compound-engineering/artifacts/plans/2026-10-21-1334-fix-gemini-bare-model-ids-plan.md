---
title: Gemini Bare Model Ids After the ACP 1.4 Runtime - Plan
type: fix
date: 2026-10-21
topic: gemini-bare-model-ids
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# Gemini Bare Model Ids After the ACP 1.4 Runtime - Plan

## Goal Capsule

- **Objective:** Every Gemini route the shared agent instructions and the T3 Code settings name works on the Antigravity ACP 1.4 runtime, and each route's intended thinking level stays on record for when T3 Code can apply it.
- **Means:** Replace tier-suffixed Gemini ids with the bare ids the runtime advertises, keep the intended levels as recorded intent, and pass a level only where a route accepts one (KTD1, KTD2).
- **Product authority:** The Product Contract below, confirmed in the brainstorm. The Planning Contract decides how; it does not change product scope.
- **Execution profile:** Lightweight. Pinned instruction text, one T3 Code setting, their checks, and two docs.
- **Open blockers:** None.
- **Stop conditions:** Stop and report when a rendered instruction file still names a tier-suffixed Gemini id, or when the `agent-instructions` or `t3code-traits` check cannot be made to pass without weakening an assertion.
- **Finish:** The implementation pipeline opens the pull request. The user merges. Do not apply the generation on the live machine as validation.

---

## Product Contract

### Summary

The shared instructions and the T3 Code settings name `gemini-4-argon` and `gemini-3.8-flash` instead of tier-suffixed ids.
Inside T3 Code a Gemini task launches on the bare id with no options, because T3 Code cannot set a Gemini thinking level yet.
Each route's intended level stays written beside it, and the Compound Engineering route outside T3 Code receives that level for the Antigravity pass.

### Problem Frame

Since the Antigravity ACP runtime moved to the 1.4 line (the pin is 1.4.1), it advertises bare model ids and takes the thinking level as a separate `thinking_level` session option with `low`, `medium`, and `high`.
The tier-suffixed ids are gone.
The instructions still route `ce-work` fallbacks, the writing and visual-engineering primaries, and the cross-model peer to suffixed ids such as `gemini-4-argon-medium`, and the T3 Code text-generation model is `gemini-3.8-flash-low`.
Those requests name models the runtime no longer offers.

T3 Code nightly 20261020 selects an Antigravity model through the ACP `model` option alone and never sets `thinking_level`, so its catalog lists both Gemini models with no options.
Compound Engineering v3.31.0 already requests the bare `gemini-4-argon` and passes effort as `thinking_level`.
That makes two instruction rules false: the one that requests `gemini-4-argon-medium` for a peer because the runtime advertises only suffixed ids, and the one that says to remove that request once Compound Engineering requests advertised ids.

### Key Decisions

- **Bare ids now, intended levels kept as recorded intent.** (session-settled: user-directed — chosen over dropping the level distinctions entirely and over forcing one runtime default level per instance: the routing intent should survive until T3 Code can apply it.) Governs R1, R2, R3.
- **No rule that applies the level automatically once T3 Code exposes it.** (session-settled: user-approved — the user will update the instructions again when T3 Code supports a Gemini effort option; the synthesis stated this and the user confirmed.) Governs R3.
- **Outside T3 Code, the level applies to the Antigravity pass only.** (session-settled: user-approved — chosen over a repository-wide `cross_model_effort`, which would also change the Grok pass.) Governs R4.

### Requirements

**Model ids**

- R1. Every Antigravity model the shared instructions name, in each harness's rendering, is a bare id the runtime advertises: `gemini-4-argon` or `gemini-3.8-flash`.
- R2. The T3 Code text-generation model selection names `gemini-3.8-flash`.

**Thinking level**

- R3. The instructions record each Gemini route's intended thinking level and tell the agent to launch every Gemini task in T3 Code with no model options.
  The intended levels are: `gemini-4-argon` at `low` for the writing and visual-engineering primaries, `gemini-4-argon` at `medium` for the deep and unspecified-high fallback and for the cross-model peer, `gemini-3.8-flash` at `low` for the quick fallback, and `gemini-3.8-flash` at `high` for the unspecified-low fallback.
- R4. Outside T3 Code, a `ce-code-review` or `ce-doc-review` cross-model pass on the Antigravity route runs at thinking level `medium` on the skill's default `gemini-4-argon`, and the `ce-work` route keeps `gemini-3.8-flash` at that route's default effort, `high`.

**Stale rules**

- R5. The instructions no longer carry the rule that requests a suffixed id because the runtime advertises only suffixed ids, nor the rule that says to remove that request.

**Checks and docs**

- R6. The checks that pin the instruction sentences and the T3 Code settings expect the new text and fail on the old.
- R7. `docs/verification.md` and `docs/provisioning.md` name the bare ids and say that T3 Code does not apply a Gemini thinking level yet.

### Acceptance Examples

- AE1. **Covers R1, R3.** In T3 Code, `ce-work` classifies a unit as `writing`. The agent launches it on the `antigravity` instance with model `gemini-4-argon` and no `target.options`.
- AE2. **Covers R1, R3.** In T3 Code, the `claude-opus-5-5` launch for a `deep` unit fails. The agent relaunches it on `gemini-4-argon` with no options, not on a suffixed id.
- AE3. **Covers R4.** Outside T3 Code, `ce-code-review` runs its cross-model step. The Antigravity pass starts with `CROSS_MODEL_EFFORT_OVERRIDE=medium` and no model override, so it requests `gemini-4-argon` with `thinking_level=medium`, and the Grok pass keeps its own effort.
- AE4. **Covers R1.** A T3 Code session reports the Antigravity peer's model as `gemini-4-argon`, which maps to the `gemini` family.

### Scope Boundaries

- Changing the Antigravity ACP runtime pin or the T3 Code release.
- Forcing a default thinking level through an instance-home setting.
- Measuring which thinking level the runtime applies when none is set.
- Setting `cross_model_effort` or `work_engine_effort` in the repository's Compound Engineering config.
- The `ce-pov` oracle panel outside T3 Code: its Antigravity route hardcodes `thinking_level=high` and takes no effort override, so its peer runs at `high` there.
- Deferred for later: applying the recorded levels through `target.options` once T3 Code exposes a Gemini effort option. That is a separate instruction update.

### Dependencies / Assumptions

- With no `thinking_level` set, a Gemini task in T3 Code runs at the runtime's default level. This is unverified.
- Compound Engineering v3.31.0 requests bare `gemini-4-argon` and passes effort to its review and `ce-work` routes as `thinking_level`. Its review routes take a per-pass effort through `CROSS_MODEL_EFFORT_OVERRIDE` on the start invocation, and an agent runs each peer's route in its own pass, so an override on the Antigravity pass leaves the Grok pass alone.

### Sources / Research

- `home/h82/agents/instructions/instructions.md.tmpl` (the category routing, the outside-T3 Code route, and the two stale Antigravity rules) and `home/h82/agents/instructions/default.nix` (the peer model).
- `home/h82/t3code.nix` (`textGenerationModelSelection`).
- `tests/agent-instructions.nix` (pinned sentences, peer model, and `removedTerms`) and `tests/t3code-traits.nix` (the text-generation model).
- `docs/verification.md` and `docs/provisioning.md`.
- `packages/antigravity-acp-release.json` (runtime 1.4.1).
- `.compound-engineering/artifacts/plans/2026-10-21-1133-feat-antigravity-acp-latest-plan.md` (the runtime bump this change follows).
- The Compound Engineering v3.31.0 scripts `cross-model-adversarial-review.sh`, `cross-model-doc-review.sh`, and `cross-model-work.sh` (bare id and `--config-option thinking_level=<effort>`).
- T3 Code nightly 20261020 `buildAntigravityModelsFromSession` and `applyAntigravityAcpModelSelection` (the model is set through `setModel`, and the models carry empty capabilities).

---

## Planning Contract

**Product Contract preservation:** changed: R3 — dropped the clause that limited the no-options launch to models whose catalog lists no option, because the second Key Decision rules out a catalog-dependent rule; R4 — narrowed from every Compound Engineering cross-model pass to the `ce-code-review` and `ce-doc-review` passes, because the `ce-pov` route hardcodes `thinking_level=high` and takes no effort override (recorded under Scope Boundaries), and restated as a thinking level on the skill's default model. The rest is unchanged; the two questions deferred to planning are resolved by KTD3 and KTD4.

### Key Technical Decisions

- KTD1. **A thinking level is written beside its Gemini model in the same sentence.** Each route names the bare id followed by its intended level, for example `gemini-4-argon` at thinking level `low`. The Antigravity peer literal carries the level the same way, so the peer sentence reads with `gemini-4-argon` at thinking level `medium`. Implements R1, R3; inherits the first Key Decision through its `Governs` links.
- KTD2. **One unconditional rule says how to read those levels in T3 Code.** It tells the agent that T3 Code does not set a Gemini thinking level yet, to launch every Gemini task on the `antigravity` instance with no `target.options`, and that the level named beside a Gemini model is the level meant for it. It does not say what to do once T3 Code exposes an option. Implements R3; inherits the second Key Decision.
- KTD3. **The outside-T3 Code peer rule names the mechanism directly.** The two stale Antigravity rules are replaced by one rule: when `ce-code-review` or `ce-doc-review` runs its Antigravity pass outside T3 Code, add `CROSS_MODEL_EFFORT_OVERRIDE=medium` to that pass's start invocation and pass no model override. Naming the variable keeps an agent from reading the rule as a preference the skill may ignore, since the skill adds the override only for a resolved model or effort. Leaving the model to the skill keeps its `gemini-4-argon` default and its one-time fallback to `gemini-3.8-flash`, which an explicit model override disables. The `ce-pov` route stays at `high` (Scope Boundaries). Implements R4, R5; inherits the third Key Decision.
- KTD4. **The retired suffixed ids join `removedTerms`.** `gemini-4-argon-low`, `gemini-4-argon-medium`, `gemini-3.8-flash-low`, and `gemini-3.8-flash-high` are added beside `gemini-4-argon-high`, so a reintroduced suffixed id fails the `agent-instructions` check in every rendering. The terms match without regard to case, so new wording must also avoid `Flash low`, `Flash medium`, `Flash high`, `flash-medium`, and the sentence fragment `for that pass only`. Implements R6.

### Assumptions

- The pipeline ran without a scoping confirmation for this plan. The inferred bet is KTD4's choice to guard the retired ids.

### Sequencing

U1 and U2 are independent. U3 describes the text U1 and U2 produce, so it lands after both.

---

## Implementation Units

### U1. Bare Gemini ids and recorded levels in the shared instructions

**Goal:** Every rendering of the shared instructions names only bare Gemini ids, carries each route's intended thinking level, and drops the two stale Antigravity rules.

**Requirements:** R1, R3, R4, R5, R6; KTD1, KTD2, KTD3, KTD4.

**Dependencies:** None.

**Files:**

- `home/h82/agents/instructions/instructions.md.tmpl`
- `home/h82/agents/instructions/default.nix`
- `tests/agent-instructions.nix`

**Approach:**

1. In the `ce-work` category sentences, replace each suffixed id with its bare id and level per KTD1: `writing` and `visual-engineering` primaries `gemini-4-argon` at `low`, the `deep` and `unspecified-high` fallback `gemini-4-argon` at `medium`, the `quick` fallback `gemini-3.8-flash` at `low`, the `unspecified-low` fallback `gemini-3.8-flash` at `high`.
2. In the outside-T3 Code `ce-work` sentence, name `antigravity` with `gemini-3.8-flash`, keeping the route's default effort, `high`.
3. Add the KTD2 rule next to the rule that launches each unit through `delegate_task`.
4. Replace the two Antigravity route rules with the KTD3 rule, worded without the retired terms KTD4 lists.
5. Set the Antigravity peer model in `default.nix` to the bare id with its `medium` level per KTD1.
6. Mirror every change in `tests/agent-instructions.nix`: the peer literal, the pinned `compoundEngineeringSentences`, and the KTD4 `removedTerms` entries.

**Patterns to follow:** The existing pinned-sentence list in `tests/agent-instructions.nix` and its comment on keeping peer literals out of the module. Before editing the template or the check, read `.compound-engineering/artifacts/solutions/logic-errors/go-text-template-missingkey-error-misses-index-and-printed-nulls.md` and `.compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md`.

**Test scenarios:**

- Covers AE1, AE2. The Claude Code rendering holds the `writing`, `visual-engineering`, `deep`, `quick`, and `unspecified-low` sentences with bare ids and their levels, each exactly once at a sentence start.
- Covers AE4. The Claude Code and Grok renderings name the Antigravity peer as `gemini-4-argon` at thinking level `medium`; the Antigravity rendering names no Antigravity peer.
- Covers AE3. Every rendering holds the KTD3 rule, naming `CROSS_MODEL_EFFORT_OVERRIDE=medium`, exactly once and neither stale rule.
- A rendering that still contains `gemini-4-argon-medium` (or any other KTD4 id) fails the check with the removed-term message.
- Removing the KTD2 rule from the template fails the check with a missing-sentence message.

**Verification:** The `agent-instructions` check passes on every host rendering, and fails when the template is mutated back to a suffixed id or the KTD2 rule is removed.

### U2. Bare Gemini id for T3 Code text generation

**Goal:** T3 Code's text-generation selection names a model the Antigravity runtime advertises.

**Requirements:** R2.

**Dependencies:** None.

**Files:**

- `home/h82/t3code.nix`
- `tests/t3code-traits.nix`

**Approach:** Change `textGenerationModelSelection.model` to `gemini-3.8-flash` and the expected value in `tests/t3code-traits.nix` to match. The selection is owned whole, so no stale option survives the change.

**Patterns to follow:** The `own` block in `tests/t3code-traits.nix` that already pins `defaultModelSelection`.

**Test scenarios:**

- A host with a T3 Code trait declares `textGenerationModelSelection` with instance `antigravity` and model `gemini-3.8-flash`.
- A declaration that still names `gemini-3.8-flash-low` fails `t3code-traits`.

**Verification:** `t3code-traits` passes, and fails when the module is mutated back to the suffixed id.

### U3. Docs describe bare ids and the unset thinking level

**Goal:** The provisioning and verification docs match the new instructions and settings.

**Requirements:** R7.

**Dependencies:** U1, U2.

**Files:**

- `docs/provisioning.md`
- `docs/verification.md`

**Approach:**

1. In `docs/provisioning.md`, rewrite the Antigravity route paragraph that describes runtime 1.3.0 advertising suffixed ids: the 1.4 runtime advertises bare ids, takes `thinking_level` separately, and the stale rules are gone.
2. Update the peer and `ce-work` routing paragraph to the bare ids, their levels, and the KTD2 rule.
3. Add the KTD4 terms to the `agent-instructions` check description.
4. In `docs/verification.md`, change the `orchestrator_capabilities` item to expect `gemini-4-argon` and `gemini-3.8-flash` with no options on `antigravity`, and the peer item to `gemini-4-argon`.

**Test expectation:** none -- prose only; markdownlint runs on the staged files.

**Verification:** No doc outside `.compound-engineering/artifacts/` names a tier-suffixed Gemini id except as a retired term in the check description, and markdownlint passes.

---

## Verification Contract

- `nix fmt -- --ci` passes.
- `nix flake check` passes, including `agent-instructions` and `t3code-traits`.
- Build every output under `nixosConfigurations`, `homeConfigurations`, `systemConfigs`, and `darwinConfigurations` that this builder can build, per `AGENTS.md`; leave aarch64 and macOS outputs to CI.
- `markdownlint-cli2` passes on the changed Markdown.
- A search of the repository, excluding `.compound-engineering/artifacts/` and the `removedTerms` list and its description, finds no `gemini-4-argon-low`, `gemini-4-argon-medium`, `gemini-3.8-flash-low`, or `gemini-3.8-flash-high`.
- `nix build --no-link .#vmChecks.all` passes on a builder with `/dev/kvm`.

---

## Definition of Done

- U1 through U3 are complete and each unit's verification holds.
- Each mutation named in U1 and U2 was run once in a scratch copy and turned its check red; see `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md` before making the copy.
- The Verification Contract passes.
- No abandoned-attempt code or scratch files remain in the diff.
