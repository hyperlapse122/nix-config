---
title: Codex Sol Medium - Plan
type: chore
date: 2026-10-25
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Codex Sol Medium - Plan

## Goal Capsule

- **Objective:** Use medium effort for every Sol responsibility in the Codex-only orchestration policy.
- **Authority:** Update the repository policy, checks, and documentation; publish a PR. Leave merging and machine activation to the user.
- **Execution:** One bounded policy change, verified through the existing instruction checks and repository publishing gates.

## Product Contract

### Summary

Change the Codex P4 profile from high to medium effort while retaining its model and responsibility assignments.

### Problem Frame

The Codex orchestration policy assigns high effort to substantive review and complex diagnosis. The user requests medium effort for those Sol assignments.

### Requirements

- R1. Every Sol profile in the Codex-only orchestration policy uses medium effort.
- R2. Preserve model IDs, responsibility mappings, other profiles, and the non-Codex instruction deliveries.
- R3. Current documentation and check expectations agree with R1; historical execution evidence remains accurate.

## Planning Contract

### Key Technical Decisions

- KTD1. Update the P4 row in the existing conditional template and its independently declared test contract. The configured Sol ID is `gpt-6.1-sol`; this change concerns effort, not model selection.
- KTD2. Update current guidance in `docs/provisioning.md` and the responsibility-dispatch checklist in `docs/verification.md`. Preserve historical plans and recorded explicit-override probes, which describe earlier decisions and observations.

## Implementation Units

### U1. Align the Codex policy and its checks

**Goal:** Implement R1-R3 through KTD1-KTD2.

**Dependencies:** None.

**Files:** `home/h82/agents/instructions/instructions.md.tmpl`, `tests/agent-instructions.py`, `docs/provisioning.md`, `docs/verification.md`.

**Approach:** Retain the existing conditional delivery and check structure. Change the P4 effort in both test expectations, then align the current documentation.

**Patterns:** The existing P3 row already declares the requested model, effort, and service tier.

**Test scenarios:**

1. Rendered Codex instructions carry medium for P4 and preserve all other profile fields.
2. Existing checks continue to verify unchanged non-Codex deliveries.
3. Restoring high in the rendered P4 row causes the existing policy check to reject the output.

**Verification:** The existing `agent-instructions` check passes, and its P4 regression mutation fails for the intended reason.

## Verification Contract

Run `nix build --no-link .#checks.x86_64-linux.agent-instructions`, `git diff --check`, changed-Markdown lint, and `nix fmt -- --ci` locally. Follow `docs/verification.md` publishing requirements for the complete branch diff; record unsupported platform checks as pending until CI supplies them. This is runtime instruction policy, not inert documentation. No machine activation is required.

## Definition of Done

The policy, tests, and current guidance agree; authorized review fixes are applied; the PR records local and CI evidence separately. No experimental files remain in the diff.
