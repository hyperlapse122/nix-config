---
title: Named ce-work Implementation Workers - Plan
type: feat
date: 2026-10-19
topic: ce-work-named-workers
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Named ce-work Implementation Workers - Plan

## Goal Capsule

- **Objective:** When an agent on any host runs `ce-work`, each implementation unit goes to a Claude or Gemini model the user chose for that unit's difficulty, at the effort the user chose, never to Grok or OpenCode, so the user no longer has to stop a run and redirect the work.
- **Means:** Replace the harness-to-model guide in the shared agent instructions with named workers in three tiers, and move the pinned-sentence check and the docs with it (KTD1, KTD2, KTD3, KTD6).
- **Product authority:** The user, through issue #262 and the 2026-10-19 `lfg` invocation. The Product Contract wins on behavior; the Planning Contract wins on mechanism.
- **Execution profile:** Instructions prose, one Nix check's literals, and docs. No runtime code.
- **Stop conditions:** Stop if a worker sentence cannot be written without an internal `". "`, or if `orchestrator_capabilities` no longer lists a model id this plan names.
- **Open blockers:** None.
- **Who finishes:** `lfg` implements, reviews, and opens the pull request; the user merges.

---

## Product Contract

### Summary

The Compound Engineering section of `home/h82/agents/instructions/instructions.md.tmpl` names the `ce-work` workers by tier: a default pair, a harder-unit pair, and a lighter-unit worker, each with its T3 Code instance, model id, and effort.
It says Grok and OpenCode do no implementation work, how a unit picks a tier and a worker, and what Compound Engineering's own route runs outside T3 Code.
`tests/agent-instructions.nix` pins the new sentences, and `docs/provisioning.md` and `docs/verification.md` describe the new guide.

### Problem Frame

While implementing #261, an agent read "prefer delegating implementation to another harness" with a guide that maps each of four harnesses to a model, and sent the units to Grok at `xhigh` effort.
The user had to stop it and ask for Claude Sonnet and Gemini Flash instead.
The current guide says which model each harness runs, not which harness gets a unit, and names no effort for Claude Code.

### Key Decisions

- **Default workers are Claude Sonnet 5.5 at its default effort and Gemini 3.8 Flash at high effort.** (session-settled: user-directed — chosen over a fixed `effort: high` pin for Sonnet and `gemini-4-argon-high` as the Antigravity worker: the user chose Sonnet's default effort and the latest Flash at high effort.) Governs R1, R2.
- **Harder units go to Claude Opus 5.5 at its default effort or Gemini 4 Argon at medium effort.** (session-settled: user-directed — chosen over Opus or Haiku "when the unit needs it" with no rule, and `gemini-4-argon-high`: the user chose these tiers.) Governs R3.
- **Lighter units go to Claude Haiku 5.5 at `xhigh` or `max` effort, with no Gemini worker.** (session-settled: user-directed — chosen over naming a Gemini Flash Lite id: the user made Flash Lite conditional on T3 Code offering it, and T3 Code's catalog on 2026-10-19 lists none.) Governs R4.
- **Grok and OpenCode do no implementation work; Opus 5.5 and `gemini-4-argon-high` keep their review-peer roles.** (session-settled: user-directed — chosen over leaving all four harnesses eligible: the issue asks for it after the #261 run went to Grok.) Governs R5, R9.

### Requirements

**Workers**

- R1. A default unit goes to `claude-sonnet-5-5` on the `claudeAgent` instance at the effort `orchestrator_capabilities` marks as its default, or to `gemini-3.8-flash-high` on the `antigravity` instance.
- R2. The instructions state each worker's instance, model id, and effort, and every Claude launch sets its effort explicitly, so no worker runs at an effort the guide does not name.
- R3. A harder unit goes to `claude-opus-5-5` on the `claudeAgent` instance at the effort `orchestrator_capabilities` marks as its default, or to `gemini-4-argon-medium` on the `antigravity` instance.
- R4. A lighter unit goes to `claude-haiku-5-5` on the `claudeAgent` instance at `effort` `xhigh`, or `max` when the unit spans more than one file.
- R5. No implementation unit is delegated to Grok or OpenCode, inside or outside T3 Code, and a Grok or OpenCode session delegates every unit instead of writing it.

**Choosing a tier and a worker**

- R6. A unit is harder when its own design is hard, such as a new interface, data format, or concurrency rule, or when it carries a security or data-loss risk, even when the edit is mechanical, or when it changes many modules in a way that is not a mechanical edit. A unit is lighter when it is a mechanical edit, such as a rename, a pinned-text update, or a one-file docs change, even across files. Every other unit is a default unit.
- R7. Inside T3 Code, the units of each two-worker tier alternate between that tier's Claude and Gemini worker in plan order across the whole plan, counted per tier.
- R8. Inside T3 Code, when a worker is unavailable or its launch fails, the unit goes to the other worker of its tier; a lighter unit goes to the default tier and takes whichever of its workers is available.

**Routes and pins**

- R9. Inside T3 Code the unit launches through `delegate_task` on the worker's instance, model, and effort. Outside T3 Code, Compound Engineering's own route keeps one recipient and one effort for a whole run, so the agent gives it the default tier as ordered candidates, `claude` with `claude-sonnet-5-5` and then `antigravity` with `gemini-3.8-flash-high`, at that route's default effort, `high`.
- R10. The Antigravity-route workaround requests `gemini-4-argon-high` for a cross-model peer and the worker's own model id for an implementation unit. The Linux sign-in rule also keeps the Gemini worker off Compound Engineering's own route on a Linux host with no person present, and its removal condition stays.
- R11. `agent-instructions` pins every new sentence in order and fails when one is removed, doubled, negated, or contradicted by an extra sentence in the section.
- R12. `docs/provisioning.md` describes the new guide and the narrowed banned terms wherever it describes the old ones, including the OpenCode section that calls OpenCode a `ce-work` implementation harness, and `docs/verification.md` checks that T3 Code still lists every worker's model id.

### Acceptance Examples

- AE1. **Covers R1, R7.** Given a plan whose first dependency layer has three default units inside T3 Code, the agent launches the first and third on `claude-sonnet-5-5` at `effort` `high` and the second on `gemini-3.8-flash-high`.
- AE2. **Covers R5, R8.** Given the `antigravity` instance is unavailable, a default unit goes to `claude-sonnet-5-5`, never to Grok or OpenCode.
- AE3. **Covers R4, R8.** Given a rename unit and an unavailable `claudeAgent` instance, the unit goes to `gemini-3.8-flash-high`.
- AE4. **Covers R9, R10.** Given a terminal Claude Code session outside T3 Code on an unattended Linux host, the agent passes Compound Engineering's route only the `claude` candidate with `claude-sonnet-5-5`.

### Scope Boundaries

- The cross-model review rules, peer pair, and `CROSS_MODEL_PEERS` stay as they are. A peer's independence is still judged against the reviewing session's model family, not the family of the worker that wrote a unit, so a Gemini peer reviewing a Gemini-written unit still counts as independent of a Claude session. Changing that is a review-rule change for a later issue.
- `work_engine_mode: off` keeps turning delegation off, and the session then implements inline on its own model, whatever that is.
- Tiers, alternation, and per-unit fallback apply only inside T3 Code, because Compound Engineering 3.31.0's own route fixes one recipient and one effort per run (`ce-work`'s `references/cross-model-execution.md`).
- T3 Code's Antigravity instance loads no instructions file, so a `ce-work` run started in an Antigravity thread does not see this guide; that is existing behavior `docs/provisioning.md` already records.
- Considered and not built: a check that the named model ids exist in T3 Code's live catalog. The catalog is per machine and per login, so no build can read it; the Goal Capsule's stop condition and the hardware check U3 adds to `docs/verification.md` cover a renamed id.
- Considered and not built: changing the top-level `effortLevel = "medium"` in `home/h82/agents/claude.nix`. R2's explicit effort on every Claude launch already decides the worker's effort, so the session default never reaches a worker.

### Deferred to Follow-Up Work

- A Gemini lighter-tier worker, once T3 Code's `antigravity` instance lists a Flash Lite model; the user asked for its highest effort.

---

## Planning Contract

### Key Technical Decisions

- KTD1. Name each worker by T3 Code instance and exact model id, not by "latest" class. T3 Code's `delegate_task` takes an exact id, the Antigravity runtime advertises only effort-suffixed ids, and a literal id lets the check pin it. Moving to a newer model is a one-line template edit plus its pinned literal. Governs R1–R4.
- KTD2. Express "default effort" as an explicit effort equal to the value `orchestrator_capabilities` marks as the model's default, `high` for Sonnet 5.5 and `medium` for Opus 5.5 on 2026-10-19. Omitting the option does not give the model's default: `delegate_task` inherits the parent's model options, and `home/h82/agents/claude.nix` sets a top-level `effortLevel` of `medium` for every Claude model. Reading the default from the catalog at launch still follows it if it moves. Instantiates R1, R2, R3 (session-settled: user-directed — chosen over a fixed `effort: high` pin for Sonnet: the user chose the default effort).
- KTD3. Narrow the check's banned term `Flash` to the retired text it guarded. `removedTerms` bans `Flash` case-insensitively since commit `1b075b5` dropped the old model-routing table, so `gemini-3.8-flash-high` would fail the check. Replace it with `Flash low`, `Flash medium`, and `flash-free`, which still catch every Flash row that table had (`Flash low` twice, `Flash medium` once) and the retired `glm-5.3-flash-free` id, and keep `Model routing`. Governs R11.
- KTD4. Alternate the two workers of a tier across the whole plan, counted per tier. Alternating spreads units across two providers and their rate limits, and counting across layers keeps a plan of single-unit layers from sending every unit to Claude. The issue left the rule open; kind-of-work splits (code versus docs) have no evidence that either model is better at one kind. Governs R7.
- KTD5. Keep the Antigravity-route workaround sentences and change only what they request and cover, per R10. Compound Engineering 3.31.0 still requests unsuffixed ids on that route, so an implementation unit outside T3 Code would otherwise stall the same way a review peer did.
- KTD6. Outside T3 Code, hand Compound Engineering's route only the default tier. Its preflight makes the first qualified candidate the run's one fixed recipient and records one effort at `init` for every unit, so it cannot carry tiers or alternation. Its Claude and Antigravity adapters default to `high`, which matches Sonnet 5.5's catalog default and `gemini-3.8-flash-high`'s suffix, so no `work_engine_effort` is needed. Governs R9.

### High-Level Technical Design

How one unit reaches a worker inside T3 Code:

| Unit (R6) | Claude worker | Gemini worker | Fallback (R8) |
| --- | --- | --- | --- |
| Harder: a hard design of its own (new interface, data format, or concurrency rule), a security or data-loss risk, or a non-mechanical change across many modules | `claude-opus-5-5`, catalog default effort | `gemini-4-argon-medium` | the other worker of the tier |
| Default: every other unit | `claude-sonnet-5-5`, catalog default effort | `gemini-3.8-flash-high` | the other worker of the tier |
| Lighter: mechanical edit such as a rename, a pinned-text update, or a one-file docs change | `claude-haiku-5-5`, `effort` `xhigh`, or `max` across files | none | the default tier's available worker |

Each two-worker tier's units alternate Claude, Gemini, Claude, in plan order across the whole plan (KTD4); a fallback launch uses the receiving worker's own effort rule.
Outside T3 Code, every unit takes the default tier through Compound Engineering's route, with the Gemini worker left out on an unattended Linux host (KTD6, R10).

### Assumptions

- The instructions keep "prefer delegating", so `ce-work`'s own judgment to run a unit inline stays; only the worker choice is fixed.
- Compound Engineering reads the ordered candidates from the instructions as contextual intent, which `ce-work`'s `references/cross-model-execution.md` honors in order.
- Directional wording for the new sentences, for the implementer to refine without changing meaning:
  - In `ce-work`, prefer delegating each implementation unit to a worker named below unless the repository's Compound Engineering config sets `work_engine_mode: off`.
  - Never delegate an implementation unit to Grok or OpenCode.
  - One sentence each for what makes a unit harder and lighter (R6).
  - One sentence each for the default, harder, and lighter tier, naming instance, model id, and effort as the table above does.
  - One sentence for the alternation rule and one for the fallback.
  - The T3 Code route sentence and the outside-T3 Code route sentence (R9).
  - The reworded Antigravity-route sentence and Linux sentence (R10).

### Sources

- Issue #262 and the current guide at `home/h82/agents/instructions/instructions.md.tmpl` (Compound Engineering section).
- `tests/agent-instructions.nix`: `compoundEngineeringSentences`, `pinnedSentences`, `removedTerms`, and the section split on `". "`.
- Compound Engineering 3.31.0 `ce-work`: `references/cross-model-execution.md` (one fixed recipient, effort recorded at `init`) and `scripts/cross-model-work.sh` (Claude and Antigravity effort default `high`).
- `home/h82/agents/claude.nix`: the top-level `effortLevel`.
- `.compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md` for why sentences are anchored and the section is allowlisted.
- `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md` for the mutation proof.

---

## Implementation Units

### U1. Rewrite the ce-work worker guide

**Goal:** The template's Compound Engineering section names the workers, tiers, selection rule, fallback, and routes.

**Requirements:** R1–R10.

**Dependencies:** None.

**Files:**

- `home/h82/agents/instructions/instructions.md.tmpl`

**Approach:**

1. Replace the three `ce-work` sentences ("In `ce-work`, prefer delegating…", "When the session lists T3 Code's delegation tools, delegate that unit…", "Pick the model by harness…") with the sentences under Assumptions.
2. Reword "When the Antigravity route runs, request `gemini-4-argon-high`…" and the Linux sentence per KTD5 and R10.
3. Leave the removal sentence in place and last.
4. Keep every new sentence free of `". "` and of the remaining banned terms.

**Patterns to follow:** The peer-route sentences above it in the same section, which name instance and model the same way.

**Test scenarios:** Covered by U2.

**Verification:** The rendered file names each worker's instance, model id, and effort, says outside T3 Code the route gets the default tier only, and names no Grok or OpenCode implementation route.

### U2. Pin the new sentences and narrow the banned term

**Goal:** `agent-instructions` passes on the new template and fails on each mutation below.

**Requirements:** R11.

**Dependencies:** U1.

**Files:**

- `tests/agent-instructions.nix`

**Approach:**

1. Replace the old `ce-work` and Antigravity-route literals in `compoundEngineeringSentences` with U1's sentences, in file order.
2. Replace `Flash` in `removedTerms` per KTD3.
3. Update the header comment only if it names the old guide.

**Execution note:** Prove each pin by mutation in a scratch copy, following the copied-worktree learning, not by a green build alone.

**Test scenarios:**

- The check builds green on the new template.
- Deleting the Grok and OpenCode sentence turns it red, naming that sentence.
- Prefixing a worker sentence with "Do not " turns it red.
- Adding "Delegate implementation units to Grok." to the Compound Engineering section turns it red as an unpinned sentence.
- Changing `gemini-3.8-flash-high` to `gemini-3.8-flash-low` in the template turns it red on the pinned sentence.
- Adding each of `Flash low`, `Flash medium`, and `flash-free` under `# Git`, outside every allowlisted section, turns it red with the removed-term diagnostic, so `removedTerms` itself is proven.

**Verification:** Every scenario above produces the expected result on `checks.x86_64-linux.agent-instructions`.

### U3. Describe the new guide in the docs

**Goal:** `docs/provisioning.md` and `docs/verification.md` match the template and the check.

**Requirements:** R12.

**Dependencies:** U1, U2.

**Files:**

- `docs/provisioning.md`
- `docs/verification.md`

**Approach:**

1. In "Shared agent instructions", replace the description of the old model guide with the tiers, selection rule, fallback, explicit effort, the outside-T3 Code default tier, and the Grok and OpenCode exclusion.
2. In the `agent-instructions` check paragraph, replace `Flash` in the list of banned names with the KTD3 terms.
3. In the Antigravity CLI section, say the workaround requests `gemini-4-argon-high` for cross-model peers and the worker's id for implementation units, and that the Linux rule also keeps the Gemini worker off the route.
4. In the OpenCode section, drop "It remains a `ce-work` implementation harness"; OpenCode stays a T3 Code provider.
5. Record that T3 Code offered no Flash Lite model on 2026-10-19, so the lighter tier has no Gemini worker.
6. In `docs/verification.md`, add a hardware item: after a T3 Code restart, confirm `orchestrator_capabilities` lists `claude-sonnet-5-5`, `claude-opus-5-5`, and `claude-haiku-5-5` on `claudeAgent` and `gemini-3.8-flash-high` and `gemini-4-argon-medium` on `antigravity`, with the effort levels the guide names.

**Test expectation:** none -- docs only; `nix fmt -- --ci` and the Markdown lint hook cover format.

**Verification:** No sentence in the docs still calls OpenCode or Grok an implementation harness, names `gemini-4-argon-high` as the `ce-work` model, or says the check bans bare `Flash`.

---

## Verification Contract

- `nix build --no-link .#checks.x86_64-linux.agent-instructions`, plus the U2 mutations in a scratch copy.
- `nix flake check` and `nix fmt -- --ci`.
- The full build list in `AGENTS.md`: `.#vmChecks.all` and every `nixosConfigurations`, `homeConfigurations`, and `systemConfigs` output. macOS outputs build in CI's `build-darwin` job.
- `mise run lint-staged-markdown` through the pre-commit hook for the Markdown files.

## Definition of Done

- U1–U3 are complete and each unit's verification holds.
- Every U2 mutation turns the check red, and the restored file turns it green.
- No experimental or abandoned edits remain in the diff.
