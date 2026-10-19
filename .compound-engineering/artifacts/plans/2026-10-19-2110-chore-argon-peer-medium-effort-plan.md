---
title: Argon Review Peer at Medium Effort - Plan
type: chore
date: 2026-10-19
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Argon Review Peer at Medium Effort - Plan

## Goal Capsule

- **Objective:** Every cross-model step that runs the Antigravity peer asks for Gemini 4 Argon at agy's default effort, medium, and never at high.
- **Means:** Change the Antigravity peer's model id in the shared agent instructions from `gemini-4-argon-high` to `gemini-4-argon-medium`, and pin the new id in `tests/agent-instructions.nix` and the docs (KTD1).
- **Authority:** This plan, then `AGENTS.md`, then the session-settled decision in KTD1.
- **Stop conditions:** Stop if `agent-instructions` cannot pass without loosening an existing guard.
- **Execution profile:** Lightweight. One mechanical edit across the instruction data, its check, and two docs.
- **Finishes and ships:** `lfg` implements, reviews, and opens the PR. The user merges.

## Product Contract

### Summary

The Antigravity cross-model peer moves from `gemini-4-argon-high` to `gemini-4-argon-medium`. The change covers both places the instructions name it: the T3 Code peer launch and the Antigravity-route workaround. The `ce-work` worker tiers do not change.

### Problem Frame

The shared instructions run the Antigravity review peer at high effort. agy defaults Argon to medium, and the user wants the review peer to use that default.

### Requirements

- R1. Inside T3 Code, every rendering that names Antigravity as a peer (Claude Code and Grok Build) launches it on the `antigravity` instance with `gemini-4-argon-medium`.
- R2. The Antigravity-route workaround sentence asks for `gemini-4-argon-medium` for a cross-model peer.
- R3. No rendered instruction file names `gemini-4-argon-high`, and `agent-instructions` fails if one does.
- R4. `docs/provisioning.md` and `docs/verification.md` name `gemini-4-argon-medium` wherever they describe the review peer.

### Scope Boundaries

- The `ce-work` worker tiers stay unchanged: `gemini-3.8-flash-high` for a default unit and `gemini-4-argon-medium` for a harder unit.
- Past plans under `.compound-engineering/artifacts/plans/` that name `gemini-4-argon-high` are left as written. They are decision records.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **The Antigravity peer runs `gemini-4-argon-medium`.** The effort is part of the model id, because the runtime advertises only `-low`, `-medium`, and `-high` ids. (session-settled: user-directed — chosen over keeping `gemini-4-argon-high`: medium is agy's default effort)
- KTD2. **Add `gemini-4-argon-high` to `removedTerms` in `tests/agent-instructions.nix`.** Reverting either the peer data in `home/h82/agents/instructions/default.nix` or the workaround sentence in the template would put the high id back in a rendering, and `removedTerms` fails every rendering that contains a listed term. The check's own peer literal moves to the medium id too, so the pinned route sentence follows R1.

### Sources

- `home/h82/agents/instructions/default.nix`: `peerAntigravity.model`, which the template's T3 Code route sentence renders.
- `home/h82/agents/instructions/instructions.md.tmpl`: the "When the Antigravity route runs, request …" sentence.
- `tests/agent-instructions.nix`: the independent peer literals, the pinned workaround sentence, and `removedTerms`.
- `.compound-engineering/artifacts/plans/2026-10-14-2345-perf-argon-peer-medium-effort-plan.md`: an earlier move of the peer to medium, later replaced by the dual-peer plan's `-high` id.

---

## Implementation Units

### U1. Move the Antigravity peer to medium effort

**Goal:** Instructions, check, and docs all name `gemini-4-argon-medium` for the review peer.

**Requirements:** R1, R2, R3, R4. KTD1, KTD2.

**Dependencies:** None.

**Files:**

- `home/h82/agents/instructions/default.nix`
- `home/h82/agents/instructions/instructions.md.tmpl`
- `tests/agent-instructions.nix`
- `docs/provisioning.md`
- `docs/verification.md`

**Approach:**

1. Set `peerAntigravity.model` to `` `gemini-4-argon-medium` `` in both `default.nix` and the check's own literal.
2. In the template and the check's pinned copy, change the workaround sentence to request `gemini-4-argon-medium` for a cross-model peer.
3. Add `gemini-4-argon-high` to `removedTerms`.
4. In `docs/provisioning.md`, change the workaround paragraph and the T3 Code peer sentence, and add `gemini-4-argon-high` to the `agent-instructions` paragraph that lists the identifiers the check rejects. In `docs/verification.md`, change the expected `task_status` model. The runtime-advertisement sentence that names `gemini-4-argon-{low,medium,high}` stays: it describes the ids the runtime offers, not the peer.

**Patterns to follow:** The live `removedTerms` entries such as `flash-medium`, and the `compoundEngineeringSentences` pin of the workaround sentence. The 2026-10-14 plan stays under Sources as history. Do not copy its `delegationSentences`, `supersededDirectives`, or `Argon at high effort` guard. Those names are gone from `tests/agent-instructions.nix`.

**Test scenarios:**

- The Claude Code and Grok Build renderings contain the T3 Code route sentence with `gemini-4-argon-medium` on `antigravity`, and `agent-instructions` passes.
- Reverting `peerAntigravity.model` in `default.nix` to the high id makes `agent-instructions` fail on the removed term and on the pinned route sentence.
- Reverting only the template's workaround sentence to the high id makes `agent-instructions` fail.

**Verification:** `git grep gemini-4-argon-high` outside `.compound-engineering/` returns the `removedTerms` entry and the `docs/provisioning.md` sentence that lists identifiers `agent-instructions` rejects. It does not appear in a rendering source or in a sentence that names the review peer.

---

## Verification Contract

| Gate | Command | Proves |
| --- | --- | --- |
| Format | `nix fmt -- --ci` | Nix layout unchanged |
| Instruction check | `nix build --no-link .#checks.x86_64-linux.agent-instructions` | R1, R2, R3 |
| Flake checks | `nix flake check` | No other check regressed |
| Host outputs | Build every `nixosConfigurations` toplevel and every `homeConfigurations` activation package. Leave `darwinConfigurations` to CI's `build-darwin` job. | Those outputs, which carry the instruction renderings, still build |
| Mutation | Revert each of the two edits in a scratch commit and rebuild `agent-instructions` | KTD2's guard fails on each revert |

## Definition of Done

- Every gate above passes. A macOS output is left to CI's `build-darwin` job. `systemConfigs` and `.#vmChecks.all` are not gates of this plan: the edit does not change the system-manager layer or the VM tests, and `AGENTS.md`'s pre-ship list still applies to the pull request's CI.
- Each mutation fails `agent-instructions`, and the mutations are removed from the branch afterwards.
