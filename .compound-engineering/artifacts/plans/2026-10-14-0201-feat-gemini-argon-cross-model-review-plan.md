---
title: Gemini Argon in T3 Cross-Model Review - Plan
type: feat
date: 2026-10-14
topic: gemini-argon-cross-model-review
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Gemini Argon in T3 Cross-Model Review - Plan

## Goal Capsule

- **Objective:** When a Compound Engineering skill runs its cross-model review through T3 Code, an Opus-tier Gemini model reviews the change as well, and every harness's instructions say where each Gemini class sits against the Claude classes.
- **Means:** Edit the shared agent instructions in `home/h82/agents/instructions/instructions.md.tmpl` and the sentences `tests/agent-instructions.nix` pins (KTD1-KTD4).
- **Product authority:** Issue #206, then this Product Contract, then the Planning Contract.
- **Open blockers:** None.
- **Execution profile:** Lightweight; two units in one PR (U1, U2).
- **Stop conditions:** Stop if the render check cannot be made to fail when a new sentence is removed, negated, or reverted to its old wording.
- **Who finishes:** `ce-work` implements and verifies; `lfg` reviews, opens the PR, and watches CI. Merging stays with the user.

## Product Contract

### Summary

The shared agent instructions gain Gemini 4 Argon as a Gemini model class at the Opus tier and place Flash between Sonnet and Haiku. A cross-model review delegated through T3 Code also runs on Antigravity with the latest Argon at high effort, and a retried cross-model pass on Antigravity uses Argon high instead of Flash high. The Model routing table stays as it is.

### Problem Frame

Compound Engineering's cross-model reviewer accepts only the `codex`, `claude`, `grok`, `composer`, and `cursor` targets, and its model mapping has no Gemini entry. The instructions name only Flash as a Gemini class and send Antigravity work only through the retry path at Flash high. So Gemini never reviews a change, even though Argon at high effort scores the same as `gpt-6-astra` at max effort on Artificial Analysis.

### Key Decisions

- **Change only the instructions.** (session-settled: user-directed — chosen over also changing Antigravity runtime, plugin, or instance-home wiring in this plan: that work runs in the `feat/antigravity-agent-parity` worktree.) Governs R1-R5.
- **Keep the Model routing table as is.** (session-settled: user-directed — chosen over adding an Argon row: Flash, between Sonnet and Haiku, already fits the scout and worker roles.) Governs R6.
- **Argon at the Opus tier, Flash between Sonnet and Haiku.** (session-settled: user-directed — chosen over Flash as the only Gemini class: Argon high matches `gpt-6-astra` max.) Governs R1.
- **Antigravity runs Argon high as an added review peer.** (session-settled: user-directed — chosen over leaving Antigravity on the retry path only: the skill's mapping has no Gemini entry, so the instructions must bring Argon in.) Governs R2, R3.
- **A retried pass on Antigravity uses Argon high.** (session-settled: user-directed — chosen over Flash high: the reviewer should be Opus tier.) Governs R4.

### Requirements

**Model classes**

- R1. The class list in Cross-model delegation names Argon and Flash for Gemini, places Argon at the Opus tier, and places Flash between Sonnet and Haiku.

**Cross-model review**

- R2. When a skill's cross-model pass runs through T3 Code, the instructions also delegate that pass to Antigravity on the latest runnable Argon at high effort, today `gemini-4-argon-high` on provider instance `antigravity`, with the effort carried in the id.
- R3. The Antigravity peer is part of the pass the skill already runs, not an added pass: it runs only when the skill's own peer runs, it obeys the skill's recipient restrictions and disclosure, and the rule never to add a pass the skill would not run stays.
- R4. A retried cross-model pass on Antigravity uses the latest Argon at high effort, and a retry never goes to a provider that already runs a peer of the same pass.

**Unchanged and guarded**

- R5. The rendered instructions for Claude Code, Codex, and Antigravity all carry R1-R4, and `tests/agent-instructions.nix` pins each new sentence so removing, negating, or reverting it fails.
- R6. The Model routing table and its three rows stay as they are.

### Scope Boundaries

- Antigravity runtime, plugin delivery, and T3 Code instance-home links are out of scope; `feat/antigravity-agent-parity` owns them.
- No change to the compound-engineering skills or their cross-model worker; the instructions adapt around them.
- Considered and not built: any fallback for a skipped or failed Antigravity peer beyond saying why in one line and keeping the skill's own peer. The skill's own peer still reviews the change, and evidence that T3 Code often lists Antigravity as unrunnable would change the call.

## Planning Contract

### Key Technical Decisions

- KTD1. **Rewrite the class-list sentence in place.** The parenthetical becomes `(Sol, Luna, or Astra for Codex; Opus, Sonnet, or Haiku for Claude; Argon, at the Opus tier, or Flash, between Sonnet and Haiku, for Gemini)`, the wording issue #206 proposes, and the rest of the sentence stays. Governs R1.
- KTD2. **Add one bullet after the `cross_model_model` bullet for the Antigravity peer.** Its sentences, each starting a sentence so U2 can pin it:
  1. When the session itself does not run on Antigravity, delegate the pass to Antigravity as well, on the latest runnable Argon at high effort (today `gemini-4-argon-high` on provider instance `antigravity`), even though the skill's mapping has no Gemini entry.
  2. The Antigravity peer belongs to the pass the skill already runs, not a pass of its own, so it runs only when the skill's own peer runs.
  3. It mirrors every job the skill's peer runs, with the same brief, scope, and output shape, and its findings fold in beside that peer's with `antigravity` as the provider name.
  4. It obeys the skill's recipient restrictions, such as `CROSS_MODEL_PEERS` or a user's refusal of a provider, and is announced before dispatch as a further recipient that receives the reviewed content.
  5. When a gate or restriction excludes it, or Antigravity is not runnable, skip it and say why in one line.

  The existing bullet's "never add a cross-model pass the skill would not run" stays word for word; sentence 2 is what keeps the two consistent. Governs R2, R3.
- KTD3. **Change the model clause of the retry sentence and add one exclusion.** "the latest Flash at high effort on Antigravity" becomes "the latest Argon at high effort on Antigravity"; "which the skills do not map" stays. A new sentence after it: a retried cross-model pass never goes to a provider that already runs a peer of the same pass, so a failed Antigravity peer is not retried elsewhere and a failed skill peer does not land beside a running Argon peer. Governs R4.
- KTD4. **Pin with `requireSentences` and add the old wording to `supersededDirectives`.** Sentence-start matching already catches a negated sentence (`.compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md`). The superseded list catches a revert that sits beside the new sentence: add `Flash for Gemini)` and `the latest Flash at high effort on Antigravity`. Governs R5.

### Assumptions

- "Add Antigravity as a review peer" means an extra peer beside the skill's own target, not a replacement for it, because the skill's mapping still picks its own target.
- An Antigravity session skips the added peer, because the class rule sends delegation to a provider other than the session's own.

## Implementation Units

### U1. Instruction text

- **Goal:** The template carries the Argon class, the Antigravity review peer, and the Argon retry.
- **Requirements:** R1-R4, R6; KTD1-KTD3.
- **Dependencies:** None.
- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`.
- **Approach:**
  1. Rewrite the class-list bullet per KTD1.
  2. Insert the Antigravity peer bullet after the `cross_model_model` bullet per KTD2.
  3. Change the retry clause and add the exclusion sentence per KTD3.
  4. Leave the Model routing table untouched.
- **Patterns to follow:** The surrounding bullets' voice: imperative, one rule per sentence, identifiers in backticks.
- **Test expectation:** Covered by U2.
- **Verification:** Each rendered instructions file shows the new text; the role table rows are byte-identical to before.

### U2. Pinned sentences

- **Goal:** The render check fails when any new sentence is dropped, negated, or reverted.
- **Requirements:** R5, R6; KTD4.
- **Dependencies:** U1.
- **Files:** `tests/agent-instructions.nix`.
- **Approach:**
  1. Replace the two pinned `delegationSentences` entries for the class list and the retry with the new wording.
  2. Add each KTD2 sentence and the KTD3 exclusion sentence to `delegationSentences`.
  3. Add the two superseded fragments to `supersededDirectives`.
  4. Update the header comment's cross-model delegation item to mention the Gemini classes and the Antigravity review peer.
- **Test scenarios:**
  - Unchanged template: the check passes on every host and harness.
  - Deleting the Antigravity peer sentence from the template makes the check fail naming it.
  - Prefixing that sentence with "Do not " makes the check fail.
  - Deleting the sentence that makes the Antigravity peer part of the skill's pass, or the retry exclusion sentence, makes the check fail.
  - Restoring `Flash for Gemini)` in the class list makes the check fail, both as a missing pin and as a superseded directive.
  - Restoring "the latest Flash at high effort on Antigravity" in the retry sentence makes the check fail.
  - Changing a role-table cell still fails (existing pins).
- **Verification:** `nix build --no-link .#checks.x86_64-linux.agent-instructions` passes on the change and fails on each mutation above, run in a scratch copy per `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`.

## Verification Contract

| Gate | Command | Proves |
| --- | --- | --- |
| Format | `nix fmt -- --ci` | Nix layout |
| Render check | `nix build --no-link .#checks.x86_64-linux.agent-instructions` | R1-R6 in every harness file |
| Mutation | the U2 scenarios against a scratch copy | the pins can fail |
| Flake checks | `nix flake check` | nothing else regressed |
| Host outputs | every `nixosConfigurations`, `homeConfigurations`, `systemConfigs` output per `AGENTS.md`; darwin and aarch64 outputs left to CI | the template still renders |

## Definition of Done

- U1 and U2 are in place and every gate above passes.
- Each U2 mutation was shown to fail, and the scratch copy is gone.
- No abandoned attempt remains in the diff.
