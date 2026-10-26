---
title: Sol defaults - Plan
type: chore
date: 2026-10-26
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Sol defaults - Plan

## Goal Capsule

Set native Codex and T3 Code defaults to the latest Sol model with low effort, and adjust Codex orchestration efforts.
Use the existing settings declarations and regression checks. The user's requested values govern scope; repository instructions govern verification and publication. LFG owns review, publication, and CI monitoring. Stop if the requested configuration cannot be supported. Missing platform evidence remains pending on the PR and blocks readiness, not publication.

## Product Contract

### Summary

Use `gpt-6.1-sol` with `low` effort for native Codex and T3 Code's default Codex selection. Set P5 to low and P6 to medium.

### Problem Frame

Both applications currently default to Astra. The orchestration template assigns more effort to P5 and P6 than requested.

### Requirements

- R1. Native Codex defaults to `gpt-6.1-sol` with `low` effort.
- R2. T3 Code defaults to its Codex instance using `gpt-6.1-sol` with `low` effort.
- R3. The Codex orchestration table uses `gpt-6.1-sol` with `low` for P5 and `medium` for P6.
- R4. Preserve other profiles, service tiers, OMP defaults, T3 project overrides, and existing conversation selections. The managed default settings are intentionally replaced during activation.

## Planning Contract

- KTD1. Update the existing owned settings and profile table in place. The current [OpenAI model documentation](https://developers.openai.com/api/docs/models/gpt-6.1-sol) confirms the model and low effort support.
- KTD2. Update existing independent configuration expectations rather than adding tests. Keep platform-specific activation coverage and profile mutation coverage.

## Implementation Units

### U1. Update defaults and their existing contracts

- Requirements: R1-R4.
- Files: `home/h82/agents/codex.nix`, `home/h82/t3code.nix`, `home/h82/agents/instructions/instructions.md.tmpl`, `tests/codex-settings.nix`, `tests/t3code-traits.nix`, `tests/darwin-outputs.nix`, `tests/agent-instructions.py`, `docs/verification.md`.
- Approach: change only the requested default model and effort values and align existing expectations. The merger always replaces the owned native Codex model and effort keys and T3 default selection. In `docs/verification.md`, update the native Codex entry to expect Sol low and correct its stale subagent effort to low; preserve other verification gates.
- Test scenarios: merging stale native Codex settings restores Sol low while preserving unrelated fields; T3 replaces a stale default selection while preserving project overrides; profile validation accepts P5 low and P6 medium and rejects mutations.
- Verification: run the existing Codex settings, T3 traits, and agent instruction checks; record Darwin execution separately. Inspect the pinned clients' support for Sol low before declaring readiness.

## Verification Contract

Run `git diff --check`, changed Markdown lint, `nix fmt -- --ci`, and relevant existing checks. Before readiness, require current-head CI and the complete platform evidence defined by `docs/verification.md`; unavailable builds are pending evidence. Live application selection and operator-authorized activation remain separate from build evidence.

## Definition of Done

R1-R4 are reflected in declarations, expectations, and the relevant verification instructions. Required checks pass or their blockers are reported. Review findings are assessed, no experimental changes remain, and the PR is left for the user to merge.
