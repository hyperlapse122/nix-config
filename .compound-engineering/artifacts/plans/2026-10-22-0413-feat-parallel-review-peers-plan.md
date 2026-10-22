---
title: Parallel Cross-Model Review Peers - Plan
type: feat
date: 2026-10-22
topic: parallel-review-peers
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Parallel Cross-Model Review Peers - Plan

## Goal Capsule

- **Objective:** a cross-model review that a Claude Code session runs inside T3 Code returns its peer findings in about 15 minutes instead of about 25, without covering fewer real problems than the single GLM-5.3 peer did on the one document measured so far.
- **Means:** two parallel OpenCode peers from different model families, GLM-5.3-Flash and Kimi K3, both at `high`, replace the one GLM-5.3 `max` peer for a `claude` host, with per-host defaults rewritten as separate pinned sentences (KTD1, KTD2).
- **Authority:** this plan's Product Contract owns behavior; KTDs own mechanism. The benchmark in Sources is the evidence the choice rests on.
- **Execution profile:** one branch, one pull request, units landed as separate commits in the order under Sequencing.
- **Stop conditions:** stop and report when a new or changed pin in `tests/agent-instructions.nix` cannot be made to fail under its listed mutation, or when the `synthetic-models` check rejects the `glmFlash` entry.

---

## Product Contract

Product Contract preservation: new contract (ce-plan-bootstrap).

### Summary

Change the reviewer candidates and the per-host default peer sets in the shared agent instructions. A `claude` host gets GLM-5.3-Flash and Kimi K3 at `high` in parallel; GLM-5.3 `max` stays available when the user names it. Outside T3 Code the one OpenCode pass is pinned to the first picked OpenCode peer's model. Every check, fixture expectation, and doc that names the old candidate list or the single GLM peer moves with it.

### Problem Frame

Every `ce-doc-review`, `ce-code-review`, `ce-pov` panel, and `ce-bakeoff` judge pass in a Claude Code session waits on one OpenCode peer, GLM-5.3 at `max`. A 2026-10-21 benchmark on one real doc-review prompt measured that peer at 24-25.5 minutes, longer than the 1210-second no-person deadline, so headless runs already lose it. The same benchmark showed single-peer coverage is noisy: GLM-5.3 `max` hit 4 and 6 of 10 key issues on two samples, and the two Kimi K3 `high` samples found nearly disjoint sets, one of them the only P1 any run found.

### Requirements

**Candidates and defaults**

- R1. The candidate list holds, in this order, Claude Code `claude-opus-5-5` at `effort` `medium`, OpenCode GLM-5.3-Flash at its `reviewer` variant, and OpenCode Kimi K3 at its `reviewer` variant as default candidates, and OpenCode GLM-5.3 at its `reviewer` variant as a candidate that runs only when the user names it.
- R2. A `claude` session runs the GLM Flash and Kimi candidates by default.
- R3. A `glm` session runs the Claude Code candidate alone by default.
- R4. A `kimi` session runs the Claude Code and GLM Flash candidates by default.
- R5. Every other session, `deepseek` and `unknown` ones included, runs the Claude Code and Kimi candidates by default.
- R6. Peers the user names replace the defaults, follow every other rule, and number at most two; a named peer the same-family rule leaves out is reported, not silently dropped.

**Efforts**

- R7. Kimi K3 reviews at `high` inside T3 Code while its OpenCode-wide effort stays `max`.
- R8. GLM-5.3-Flash reviews at `high`, both inside T3 Code and as its OpenCode-wide effort, and GLM-5.3 keeps `max` for every role it holds.

**Outside T3 Code**

- R9. Outside T3 Code, the OpenCode peers a host's rules pick run as one pass of Compound Engineering's own OpenCode route, pinned to the `synthetic/` model ID of the first of them in candidate order, at the effort OpenCode's settings pin for that model, and the review report names the model the route's receipt shows.

### Key Decisions

- **Two parallel smaller peers replace the single large peer for a `claude` host.** (session-settled: user-directed — chosen over only changing GLM-5.3's effort: the user allowed several small models when the evidence supports it.) Governs R1, R2.
- **The goal is lower wall-time without a material quality drop.** (session-settled: user-directed — chosen over keeping GLM-5.3 `max` regardless of time: the user's stated goal.) Governs R2, R7, R8.
- **Scope covers the model source, template, checks, and docs.** (session-settled: user-directed — chosen over changing only the reviewer effort value: the user said the scope is unrestricted.) Governs R1-R9.
- **Kimi's reviewer effort drops from `max` to `high`.** This supersedes the 2026-10-21 routing plan's user-directed "Kimi K3 runs at max effort" for the reviewer role only, on this session's request to compare and adopt `high` reviewers; no Kimi `max` review was measured, and `opencodeEffort` stays `max`. Governs R7.
- **GLM-5.3-Flash reviews at `high`, not `max`.** The benchmark split: `high` scored 3 of 10 key issues sequentially against 1 for `max`, and Kimi plus Flash `high` reach 6 of 10 on paper against 4 with Flash `max`, while the one concurrent run favored `max`; times overlapped (`high` 19:17 and 10:14, `max` 16:55 and 14:22). With no clear winner, the plan follows Compound Engineering's one-model-per-provider-at-high principle; the code-diff follow-up re-decides it. Governs R8.
- **`glm` hosts keep Claude Code alone.** No measurement shows Claude Code plus Kimi finishing sooner than Claude Code alone, and the user's goal is time. Governs R3.

### Scope Boundaries

- `CROSS_MODEL_HARD_SECS` and `CROSS_MODEL_MAX_PEERS` stay as they are; the measured `high` peers (608-1157 s) fit the 1210 s default.
- Considered and not built: a rule for two named peers of one family (only reachable by naming both GLM candidates; folding by family would merge them), and a rule for three or more named peers (the existing cap says two; the agent asks). Evidence of either happening would change the call.
- Considered and not built: automatic fallback to another candidate when Synthetic is down. The existing rule finishes with the remaining peers and never substitutes; a substitute would hide the outage.
- Qwen 3.8 27B, present in the catalog with efforts `low`, `medium`, and `xhigh` only, is not a candidate: the checks allow an OpenCode reviewer only `low`, `high`, or `max`, and it was not benchmarked.

#### Deferred to Follow-Up Work

- Measure the peers on a code-review diff, not only a plan document, and re-decide the GLM-5.3-Flash effort, the `glm` host default, and quality parity with that data.
- Run one Kimi K3 `max` review beside `high` on the same prompt to back or reverse the reviewer-effort change.

### Sources / Research

- Benchmark: one 25 KB doc-review peer prompt, 10 sequential runs and a 3-model concurrent run on 2026-10-21; key issues counted against 10 verified problems (11 after the concurrent run).

  | Run | Wall time | Key issues | Cost (USD) |
  | --- | --- | --- | --- |
  | GLM-5.3 `max` (two samples) | 24:04, 25:28 | 6, 4 | 0.77, 0.92 |
  | GLM-5.3 `high` | 20:29 | 3 | 1.31 |
  | GLM-5.3 `low` | stopped after 14:03 in a reasoning loop | 0 | - |
  | GLM-5.3-Flash `max` (sequential, concurrent) | 16:55, 14:22 | 1, 2 | 0.085, 0.085 |
  | GLM-5.3-Flash `high` (sequential, concurrent) | 19:17, 10:14 | 3, 1 | 0.11, 0.055 |
  | Kimi K3 `high` (sequential, concurrent) | 13:35, 10:08 | 3, 4 with the only P1 | 1.01, 1.62 |
  | DeepSeek V4.1 Flash 1017 `max`, `high` | 47:38, 100:42 | 5, 4 | 0.46, 1.03 |

  MiniMax M3 and Qwen3.6 27B returned "Model unavailable" and are absent from the live catalog. The concurrent Kimi, Flash `max`, and Flash `high` set finished in 15:22 with no slowdown from concurrency.
- Compound Engineering 3.31.0 picks one model per provider at high reasoning; its OpenCode route uses model `auto` unless `CROSS_MODEL_MODEL_OVERRIDE_TARGET` and `CROSS_MODEL_MODEL_OVERRIDE` pin one, accepts an `opencode:*/*` model there, and takes no effort override (`skills/ce-doc-review/scripts/cross-model-doc-review.sh`, `skills/ce-doc-review/references/cross-model-review.md`).
- The live Synthetic catalog lists `low`, `high`, `max` for `hf:zai-org/GLM-5.3-Flash` and `hf:moonshotai/Kimi-K3`; `tests/fixtures/synthetic-models/catalog-2026-10-21.json` already holds both.
- `delegate_task` accepted `variant` `high` for Kimi K3 and both `high` and `max` for GLM-5.3-Flash on 2026-10-21; `task_status` reported each.
- Learnings: `.compound-engineering/artifacts/solutions/integration-issues/opencode-config-file-model-variant-silently-dropped.md`, `.compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md`, `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`, `.compound-engineering/artifacts/solutions/logic-errors/go-text-template-missingkey-error-misses-index-and-printed-nulls.md`, `.compound-engineering/artifacts/solutions/integration-issues/t3-thread-wait-cannot-carry-in-turn-delegation-waits-alone.md`.
- Prior decisions: `.compound-engineering/artifacts/plans/2026-10-21-1714-feat-claude-opencode-agent-routing-plan.md` (candidate list, Kimi `max`, `CROSS_MODEL_MAX_PEERS` 2).

---

## Planning Contract

### Key Technical Decisions

- KTD1. **GLM-5.3-Flash is a new model-source entry `glmFlash`.** Its `family` is `glm`, its `lineage` is `hf:zai-org/GLM-([0-9]+([.][0-9]+)?)-Flash`, its only role is `reviewer = "high"`, and its `opencodeEffort` is `high`. The camelCase key lets the template read `.models.glmFlash.id` without `index`. The lineage does not match `GLM-5.3`, and the glm lineage does not match `-Flash`, so the two entries never claim each other's ids; the lineage does match the older `GLM-4.7-Flash`, which the watch script never reports as newer or as a replacement because its version is lower. `opencode.nix` derives the `reasoningEffort` leaf with no code change.
- KTD2. **Each host family's default set is its own pinned sentence.** Four sentences (R2-R5) replace the one compound "By default" sentence, so a removed, negated, or family-swapped sentence fails the check on its own. Candidates are named by role ("the GLM Flash candidate", "the Kimi candidate", "the GLM candidate") rather than ordinal, and no sentence writes `Flash` followed by an effort word, which `removedTerms` forbids.
- KTD3. **The named-only candidate moves from Kimi to GLM-5.3.** `glm.roles.reviewer` stays `max`, so its watch-script test and every other GLM role stay untouched. The "GLM candidate lowered to medium" mutant moves to the GLM candidate's new sentence.
- KTD4. **Outside T3 Code the OpenCode peers share one pinned pass.** The outside-T3 route sentence changes from one pass per peer to one pass per harness, and a new sentence tells the agent to run that pass with `CROSS_MODEL_MODEL_OVERRIDE_TARGET=opencode` and `CROSS_MODEL_MODEL_OVERRIDE` set to the first picked OpenCode peer's `synthetic/` ID and to name the model the receipt shows. This keeps "Run each peer on its pinned model ID only" true outside T3 Code, removes the duplicate `adversarial-opencode.json` output two passes would write, and moves a `claude` host's outside-T3 pass from GLM-5.3 `max`, which always overran the deadline, to GLM-5.3-Flash at `high`. `CROSS_MODEL_MODEL_OVERRIDE` joins `confinedTerms` beside `CROSS_MODEL_HARD_SECS`.
- KTD5. **A left-out named peer is reported.** One sentence after the named-peer rule says the report names any named peer the same-family rule left out. Without it a user naming only a same-family peer gets a review with no peer and no sign of why.

### Assumptions

- Kimi K3 `high` and GLM-5.3-Flash `high` keep finishing inside the 1210 s no-person deadline on larger diffs and as `delegate_task` children in freshly prepared worktrees; the benchmark measured one plan document, and worktree setup adds time.
- Claude Code `claude-opus-5-5` at `medium` finishes in time comparable to Kimi K3 `high` for `kimi` and other hosts; it was not measured.
- Compound Engineering's OpenCode route passes `CROSS_MODEL_MODEL_OVERRIDE` through `acpx --model` to `opencode acp`; the script accepts the value, and a live item confirms it reaches OpenCode.
- Outside T3 Code, a host whose first OpenCode peer is Kimi K3 runs it at its OpenCode-wide `max`, which was not measured.

### Risks & Dependencies

- Quality evidence is one document with one or two samples per model; the PR states that and the follow-up measures a code diff.
- A `claude` host review costs more Synthetic spend: about 1.1-1.7 USD for the pair against 0.77-0.92 USD for GLM-5.3 `max`, by OpenCode's accounting.
- `claude`, `kimi`, and other hosts now depend on Synthetic for one or both peers; a Synthetic outage leaves the existing finish-with-the-others rule to report it.
- Linux-only checks build from macOS only through the Podman Nix container learning or CI.

### Sequencing

U1, then U2, then U3. U2's template reads the `glmFlash` entry U1 adds, and U3's docs describe both.

---

## Implementation Units

### U1. Add GLM-5.3-Flash and lower Kimi's reviewer effort in the model source

- **Goal:** the model source carries the `glmFlash` entry and `kimi.roles.reviewer = "high"`, and every check that reads the source passes.
- **Requirements:** R1, R7, R8 (KTD1, KTD3).
- **Dependencies:** none.
- **Files:** `home/h82/agents/synthetic-models.nix`, `tests/opencode.nix`, `tests/test_synthetic_models_watch.py`; `tests/synthetic-models.nix` stays unchanged and gates the new entry.
- **Approach:**
  1. Add `glmFlash` per KTD1 between `glm` and `kimi`, and set `kimi.roles.reviewer` to `high`, leaving `visual-engineering-fallback` and `opencodeEffort` at `max`.
  2. Add the `glmFlash` id and its `high` `reasoningEffort` leaf to the hand-written expectations in `tests/opencode.nix`, in attribute order (`deepseek`, `glm`, `glmFlash`, `kimi`).
  3. Add a `GLM_FLASH` constant and watch tests in `tests/test_synthetic_models_watch.py`; re-read `test_suffixed_products_and_lower_versions_are_not_newer`, whose Flash row is now an entry's own id.
- **Patterns to follow:** the `glm` and `kimi` entries; `test_glm_without_max_is_changed_for_its_max_roles_only` and `test_missing_kimi_is_removed_with_its_roles`.
- **Test scenarios:**
  - The `synthetic-models` check accepts `glmFlash`: org `zai-org` maps to family `glm`, and the lineage matches its own id and captures `5.3`.
  - A catalog adding `hf:zai-org/GLM-5.4-Flash` reports a newer model for `glmFlash` only, and `hf:zai-org/GLM-5.4` reports one for `glm` only.
  - The fixture's `hf:zai-org/GLM-4.7-Flash` row is never reported as newer than `glmFlash` or as its replacement.
  - A catalog whose GLM-5.3-Flash row lacks `high` reports `glmFlash` as changed for its `reviewer` role and `opencodeEffort`.
  - A catalog missing GLM-5.3-Flash reports `glmFlash` removed with its `reviewer` role.
  - The 2026-10-21 fixture catalog stays clean against the real source.
  - The OpenCode settings check expects a `high` `reasoningEffort` leaf for GLM-5.3-Flash and still `max` for Kimi K3.
- **Verification:** `synthetic-models`, `synthetic-models-watch`, `synthetic-models-reconcile`, and `opencode-settings` pass, and removing the `glmFlash` leaf from `tests/opencode.nix`'s expectation turns `opencode-settings` red.

### U2. Rewrite the candidate and default-peer sentences and their pins

- **Goal:** the rendered instructions name the four candidates and the per-host defaults of R1-R6, the outside-T3 rule of R9, and nothing else about reviewer selection.
- **Requirements:** R1-R6, R9 (KTD2, KTD3, KTD4, KTD5).
- **Dependencies:** U1.
- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`, `tests/agent-instructions.nix`.
- **Approach:**
  1. In `# Compound Engineering`, replace the second and third candidate sentences with the GLM Flash default, Kimi default, and GLM named-only candidates in R1's order, each written as "`synthetic/<id>` on the `opencode` instance with `variant` `<role>`", reading ids through `{{ .models.<name>.id }}` and variants through `{{ index .models.<name>.roles "reviewer" }}`.
  2. Replace the compound "By default" sentence with the four host sentences (KTD2), and change "the third candidate included" in the named-peer rule to "the GLM candidate included"; add the KTD5 sentence after it.
  3. Change the outside-T3 route sentence and add the pinned one-pass sentence (KTD4).
  4. In `tests/agent-instructions.nix`, add `glmFlash` to `modelNames`, an id binding, and `actionValues`; add `CROSS_MODEL_MODEL_OVERRIDE` to `confinedTerms`; rewrite the pinned sentences in section order; name the new candidate and host sentences once for the mutants.
  5. Move "GLM candidate lowered to medium" onto the GLM named-only sentence, and add the mutants listed under Test scenarios.
- **Execution note:** read `copied-git-worktree-writes-the-real-index.md` before running mutation rounds, and run them in an `rsync -a --exclude .git` copy with its own `git init`.
- **Patterns to follow:** `glmCandidateSentence`, `writingSentence`, the "session_info-first sentence negated" mutant, and `assignmentRules` in `tests/agent-instructions.nix`.
- **Test scenarios:**
  - Rendered instructions hold each candidate sentence and each host sentence exactly once, in section order, with both default OpenCode variants `high` and the GLM variant `max` read from the source.
  - Setting `kimi.roles.reviewer` to `max` in the source changes the rendered Kimi variant and the check still passes, because the pin reads the role.
  - Each host sentence removed fails `sentencesInSection` with that sentence named.
  - Each host sentence prefixed with "Do not" fails the check.
  - The `claude` host sentence rewritten to run the GLM candidate fails the check.
  - The `kimi` host sentence rewritten to run the Kimi candidate fails the check.
  - The GLM Flash candidate sentence at `variant` `medium` fails `assignmentRules`.
  - The Kimi candidate sentence at `variant` `medium` fails `assignmentRules`.
  - The GLM named-only sentence at `variant` `medium` fails `assignmentRules`.
  - The KTD5 sentence removed or negated fails the check.
  - The pinned one-pass sentence removed or negated fails the check.
  - `CROSS_MODEL_MODEL_OVERRIDE` written in a section outside `# T3 Code` and `# Compound Engineering` fails `confinedTerms`.
  - An added sentence giving every host three default peers fails `onlyPinnedSentences`.
  - Every host output renders without a template error.
- **Verification:** `agent-instructions` passes on every host output, and each listed mutation turns it red.

### U3. Bring the docs in line with the new peer set

- **Goal:** no doc still says a `claude` session runs one GLM peer, that Kimi runs only when named, or that the model source has three entries.
- **Requirements:** R1-R9.
- **Dependencies:** U1, U2.
- **Files:** `docs/provisioning.md`, `docs/verification.md`, `CONCEPTS.md`.
- **Approach:**
  1. `docs/provisioning.md`: the template-action paragraph (including the existing "never `index`" claim the template already contradicts), the candidate and default paragraph, the outside-T3 route paragraph, the `agent-instructions` check paragraph with its mutant count and list, the Synthetic models table and entry count, and the watch paragraph's suffixed-product sentence.
  2. `docs/verification.md`: the check summary line, the opened `opencode.json` entry list, the per-host peer items (a `claude` host launches two peers, a `glm` host one, other hosts two), the deadline item, and live items for: Kimi `high` and GLM-5.3-Flash `high` arriving as `variant` in `delegate_task`; one timed two-peer review in T3 Code on a plan document, recording each peer's wall time against the 1210 s deadline; and one outside-T3 review whose OpenCode pass reports GLM-5.3-Flash as the served model.
  3. `CONCEPTS.md`: the cross-model peer entry.
- **Patterns to follow:** the current paragraphs those steps rewrite.
- **Test expectation:** none -- prose only; `nix fmt -- --ci` and the Markdown pre-commit lint cover formatting.
- **Verification:** a search of `docs/` and `CONCEPTS.md` finds no "only when the user names it" for Kimi, no "exactly one peer" for a `claude` session, and no "three entries".

---

## Verification Contract

| Gate | Command or evidence | Applies to |
| --- | --- | --- |
| Format | `nix fmt -- --ci` | all units |
| Source and watch checks | `nix build --no-link .#checks.x86_64-linux.synthetic-models`, `.synthetic-models-watch`, `.synthetic-models-reconcile`, `.opencode-settings` | U1 |
| Instructions check | `nix build --no-link .#checks.x86_64-linux.agent-instructions` | U2 |
| Flake checks | `nix flake check` | all units |
| Mutation rounds | each mutation under U1 and U2 Verification, in an `rsync -a --exclude .git` copy with its own `git init` | U1, U2 |
| Host outputs | every output under `nixosConfigurations`, `homeConfigurations`, `systemConfigs`, and `darwinConfigurations`, as `AGENTS.md` lists; Linux outputs through the Podman Nix container learning or CI when built from macOS | all units |
| Live items | the new `docs/verification.md` items, reported apart from build evidence | U3 |

---

## Definition of Done

- Every unit's Verification holds and its mutations were shown to fail.
- R1-R9 are each covered by a merged unit, and the rendered instructions contain no unpinned sentence.
- The PR body carries the benchmark table with wall times, key-issue counts, and costs, the one-document caveat, the per-review cost change, and the Kimi `max` to `high` reviewer change against the 2026-10-21 decision.
- No abandoned-attempt code, temporary probe, or mutation copy remains in the diff.
