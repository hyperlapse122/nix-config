---
title: Argon Peer at Medium Effort - Plan
type: perf
date: 2026-10-14
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Argon Peer at Medium Effort - Plan

## Goal Capsule

- **Objective:** A cross-model review that runs through T3 Code returns sooner, because its Antigravity peer no longer runs at the slowest reasoning level.
- **Means:** The shared agent instructions name Argon at medium effort for the Antigravity peer and its retry, and the instruction check pins the new wording (KTD1, KTD2).
- **Authority:** This plan, then `AGENTS.md`, then the session-settled decision in Key Decisions.
- **Stop conditions:** Stop if the instruction check cannot be made to pass without loosening an existing guard.
- **Execution profile:** Lightweight; two implementation files plus this plan file, in one commit.
- **Finishes and ships:** `lfg` implements, reviews, opens the PR, and merges after CI passes.

## Product Contract

### Summary

Change the Antigravity peer of every T3 Code cross-model pass from `gemini-4-argon-high` to `gemini-4-argon-medium`, for both the first dispatch and the retry rule. Update `tests/agent-instructions.nix` so it pins the new sentences and fails if the high-effort wording returns.

### Problem Frame

Cross-model review is slow, and the Argon peer at high effort is the slowest part of it. Artificial Analysis measured Argon only at high, where it spent about 62k output tokens per index task, more than twice what a model with the same score used. No public benchmark covers low or medium.

### Key Decisions

- **The Argon peer runs at medium effort.** Medium is Google's documented default and the level it recommends for coding and agentic tool use. Governs R1, R2. (session-settled: user-directed — chosen over low, high, and measuring first: low skipped reasoning entirely on short prompts in an independent test, measuring first costs time, and high is the slowness being fixed)

### Requirements

**Instructions**

- R1. The delegation rule tells the agent to run the Antigravity peer on the latest runnable Argon at medium effort, naming `gemini-4-argon-medium` as today's id.
- R2. The retry rule names the latest Argon at medium effort on Antigravity.
- R3. The model-class sentence that places Argon at the Opus tier stays as it is.

**Guard**

- R4. The instruction check requires the new R1 and R2 sentences in every rendered harness file.
- R5. The instruction check fails when any rendered harness file still says "Argon at high effort".

### Scope Boundaries

- Flash routing, the role table, and the skills' own cross-model effort mapping (`cross_model_effort`) do not change.
- Measuring low, medium, and high on real reviews was considered and not done; the user chose medium without it. A measured regression in Argon findings would reopen the choice.

### Sources

- Artificial Analysis, Gemini 4 Argon: Intelligence Index 53 at high, about 62k output tokens per task, no low or medium entry.
- Google AI for Developers, "What's new in Gemini 4 Argon": medium is the default thinking level, recommended for coding and agentic tool use.
- `.compound-engineering/artifacts/plans/2026-10-14-0201-feat-gemini-argon-cross-model-review-plan.md`: the plan that introduced the Argon peer at high effort.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Edit the two template sentences in place.** Replace "high" with "medium" and the model id in the existing sentences instead of adding a new sentence, so `onlyPinnedSentences` still sees only pinned Antigravity and Argon sentences. Implements R1, R2 under the session-settled Key Decision.
- KTD2. **Guard the old wording through `supersededDirectives`.** Add the fragment `Argon at high effort`. The pinned-sentence check only covers the Cross-model delegation section; the superseded list scans the whole rendered file, so a high-effort sentence elsewhere also fails. Implements R5.

### Assumptions

- Each rendered harness file comes from the one template, so editing the template covers Claude, Codex, and Antigravity outputs.

### Sources & Research

- `tests/agent-instructions.nix`: `delegationSentences` pins both sentences verbatim, `onlyPinnedSentences` rejects any other sentence that names Antigravity or Argon in the Cross-model delegation section, and `supersededDirectives` is checked with `grep -qF` against the whole file.
- `.compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md`: why the pinned-sentence check exists and how it splits sentences.
- `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`: a check counts as a guard only after a mutation turns it red.

---

## Implementation Units

### U1. Instructions and check at medium effort

- **Goal:** The rendered instructions name Argon at medium effort, and the check pins that wording.
- **Requirements:** R1, R2, R3, R4, R5; KTD1, KTD2.
- **Dependencies:** none.
- **Files:**
  - `home/h82/agents/instructions/instructions.md.tmpl`
  - `tests/agent-instructions.nix`
- **Approach:**
  1. In the template's Cross-model delegation section, change the delegation sentence to "at medium effort (today `gemini-4-argon-medium` on provider instance `antigravity`)" and the retry sentence to "the latest Argon at medium effort on Antigravity".
  2. In `delegationSentences`, change the same two entries so they match the template exactly.
  3. Append `"Argon at high effort"` to `supersededDirectives`.
  4. In the header comment's superseded-directive list, add the Argon peer at high effort.
- **Patterns to follow:** The existing `"the latest Flash at high effort on Antigravity"` entry in `supersededDirectives` and its mention in the header comment.
- **Test scenarios:**
  - The rendered instructions contain both new sentences, and the check passes for every harness file.
  - Mutation: with the template's delegation sentence alone reverted to high, the check fails with "lacks the cross-model delegation rule" and "carries a superseded directive".
  - Mutation: with a sentence containing "Argon at high effort" added outside the Cross-model delegation section, the check fails with "carries a superseded directive".
  - The model-class sentence with "Argon, at the Opus tier" is still present and still required.
- **Verification:** The check builds green on the change and red on each mutation, and each mutation is reverted afterward.

---

## Verification Contract

| Gate | Command | Proves |
| --- | --- | --- |
| Instruction check | `nix build --no-link .#checks.x86_64-linux.agent-instructions` | R1 to R5 |
| Flake checks | `nix flake check` | Nothing else regressed |
| Formatting | `nix fmt -- --ci` | Nix layout |
| Markdown lint | `.githooks/pre-commit` at commit time | Plan file lint |

Run each mutation in the working tree on top of the finished U1 edits, and undo only that mutation before the next, so the U1 edits stay in place. Do not restore the whole file from git, which would also discard the unstaged U1 edits, and do not copy the checkout to run them.

## Definition of Done

- Both template sentences name Argon at medium effort, and the Opus-tier sentence is unchanged.
- The check pins the new sentences and lists `Argon at high effort` as superseded.
- Every gate in the Verification Contract passes, and both mutations turned the check red before being reverted.
- No mutation or experimental edit remains in the diff.
