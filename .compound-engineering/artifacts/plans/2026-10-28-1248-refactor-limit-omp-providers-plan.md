---
title: "refactor: limit OMP to three providers"
date: 2026-10-28
type: refactor
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# refactor: limit OMP to three providers

## Goal Capsule

- **Objective:** The user can keep Codex work in native Codex and use OMP for Synthetic, Antigravity, and OpenRouter without accidentally selecting OMP's Codex route.
- **Means:** Apply the existing OMP model-selection settings to standalone OMP and its T3 Code launch (KTD1, KTD2).
- **Authority:** The current request and Product Contract govern behavior; Planning Contract decisions govern implementation within that scope.
- **Execution profile:** Configuration and existing runtime-check updates; use fake credentials and isolated homes for verification.
- **Stop conditions:** Stop for evidence that the pinned runtime cannot enforce the required exclusion, or that implementation would require deleting user state or changing native Codex behavior.
- **Delivery:** This artifact authorizes planning only. An implementation handoff executes U1-U3; publication requires the applicable workflow and repository checks. Leave merging to the user.

## Product Contract

### Summary

Restrict managed OMP sessions to the existing Synthetic, Antigravity, and OpenRouter selections, and disable OMP's `openai-codex` provider.
Keep native Codex available through its own CLI and T3 Code provider.

### Problem Frame

The user finds native Codex more stable than Codex through OMP and better integrated with T3 Code.
OMP currently includes `openai-codex/*` in its managed model scope, leaving a second Codex route available even though its default and internal roles already use Antigravity.

### Requirements

**OMP provider selection**

- R1. Under the managed standalone configuration and T3 Code OMP launch, available session models belong only to `synthetic`, `google-antigravity`, and `openrouter`, retaining their existing curated model selections.
- R2. OMP's `openai-codex` models are unavailable even with stored Codex OAuth credentials or a widened model scope; explicitly selecting that provider fails before a model request.
- R3. Preserve the existing Antigravity startup model, role assignments, thinking levels, and Synthetic/OpenRouter catalog behavior.

**Existing state and native Codex**

- R4. Preserve native Codex installation, settings, authentication, usage reporting, and T3 Code's native `codex` instance and routing.
- R5. Preserve OMP authentication, conversation history, and other user state; provider exclusion does not delete or rewrite those records.
- R6. OMP orchestration instructions describe only the remaining providers as OMP execution routes and continue to allow sanctioned external Codex reviews through native Codex.

### Scope Boundaries

- Apply R1-R2 through the repository's existing configuration and activation ownership. Deliberate user or project overrides of managed policy are outside this change's enforcement boundary.
- Do not patch the upstream executable, remove its bundled provider implementation, or redesign its authentication commands.
- Do not remove GPT models supplied by the retained providers, replace native Codex, change the OMP release pin, or rewrite historical plans.
- Do not clean historical provider names out of usage fixtures, saved T3 model ordering, or conversation records where those names are data rather than active routing.
- No new provider-policy framework, wrapper interception, or automatic session migration is needed; revisit only if the existing runtime settings cannot satisfy R1-R2.

## Planning Contract

### Key Technical Decisions

- KTD1. **Keep model scope and provider disabling distinct.** Remove `openai-codex/*` from the existing shared `patterns` selection and export the disabled-provider policy from that same selection module, retaining `omp-managed` and adding `openai-codex`. `enabledModels` governs curation; `disabledProviders` also prevents explicit CLI selection. Do not use `enabledProviders`, which controls foreign configuration discovery. Governs R1-R3.
- KTD2. **Use the shared policy in both configuration consumers.** The common document in `home/h82/agents/omp.nix` and the existing T3 `ompScope` overlay in `home/h82/t3code.nix` must consume the policy. Keep the T3 model-scope arguments and overlay so runtime drift in the writable common document does not widen a T3 session. Governs R1-R3.
- KTD3. **Extend the existing behavioral owners.** `tests/omp-acp.py` owns session availability and rejection through the pinned executable; settings and VM checks own restoration and state preservation. Update their obsolete Codex-positive expectations rather than creating a separate flake check or production testing seam. Governs R1-R5.
- KTD4. **Keep native Codex references where they remain valid.** Update the OMP-specific delegation sentence and its instruction checks without changing the native Codex or T3 routing tables. Document the OMP provider boundary in `docs/agent-routing.md` in the same change. Governs R4, R6.

### Evidence and Constraints

The pinned runtime is OMP `18.13.2`, commit `e996e1c7ac476f60e02b8ed9764cf30fa8c00a8e`, from `packages/omp-release.json`.
Its [provider documentation](https://github.com/can1357/oh-my-pi/blob/e996e1c7ac476f60e02b8ed9764cf30fa8c00a8e/docs/providers.md) distinguishes discovery opt-ins from model-provider disabling and states that disabling preserves stored credentials.
Its [CLI model resolver](https://github.com/can1357/oh-my-pi/blob/e996e1c7ac476f60e02b8ed9764cf30fa8c00a8e/packages/coding-agent/src/config/model-resolver.ts) rejects explicitly selected disabled providers.

`omp models --json` reads registry availability and does not enforce the session's `enabledModels` curation; it is not the owner of R1.
Adding provider disabling will also remove Codex from that diagnostic's available results, so its current Codex-positive control must use an isolated baseline with the exclusion removed.
`tests/omp-acp.py` already imports fake OAuth credentials and reads real ACP model options; retain that boundary for KTD3.

Existing settings restoration uses `scripts/omp-config-reconcile` and the NixOS system activation hook in `modules/nixos/system/omp.nix`.
Reuse those paths without changing their credential handling.
The [unchanged-generation activation learning](../solutions/best-practices/home-manager-activation-does-not-run-on-every-rebuild.md) requires verifying the NixOS system hook, rather than assuming Home Manager alone reruns on every switch.

The policy uses existing settings, not a new exported CLI or downstream interface.
Runtime execution remains implementation-time evidence; source inspection is not a test pass.

## Implementation Units

### U1. Apply the shared provider policy

**Goal:** Make both managed OMP entry points consume the same exclusion.

**Requirements:** R1-R3; KTD1-KTD2.

**Dependencies:** None.

**Files:** `home/h82/agents/omp-model-catalogs.nix`, `home/h82/agents/omp.nix`, `home/h82/t3code.nix`, `tests/omp_models_load.py`, `tests/omp_settings_applied.py`, `tests/omp-activation.nix`.

**Approach:**

1. Extend the existing selection module and wire both consumers per KTD1-KTD2.
2. Update catalog, materialized-settings, and activation fixture expectations that currently permit Codex.
3. Keep the existing reconciler and NixOS activation hook; use their current restoration scenarios for the changed settings.

**Patterns to follow:** The shared `catalogs.patterns` consumers, complete common-document reconciliation, and isolated activation fixtures.

**Execution note:** Prefer materialized configuration and activation evidence; avoid source-text assertions.

**Test scenarios:**

1. Seed the old Codex-permitting model scope and provider settings in an isolated home; applying the real declared documents restores the new scope and disabled-provider policy.
2. Repeat the NixOS switch with an unchanged Home Manager generation; the existing system hook still restores drift, and the seeded state records remain unchanged.
3. Controlled catalog fixtures retain their existing Synthetic/OpenRouter selection behavior and all three Antigravity model-family patterns after the Codex pattern is removed.

**Verification:** Existing `omp-settings`, `omp-models-load`, and `vmChecks.omp-activation` checks establish the changed outputs and restoration behavior.

### U2. Verify model exclusion at the runtime boundary

**Goal:** Establish R1-R2 without relying on missing authentication or a static expected list alone.

**Requirements:** R1-R5; KTD3.

**Dependencies:** U1.

**Files:** `tests/omp-acp.py`, `tests/omp_models_load.py`.

**Approach:**

1. Replace the standalone Codex-positive session expectation with the retained-provider contract.
2. Separate the unfiltered Codex catalog control from managed configurations, and keep fake Codex OAuth present in the exclusion cases.
3. Exercise T3's rendered ACP command and standalone OMP; keep existing prompt/tool/cancel/resume coverage intact.
4. Remove stale test messages claiming that managed OMP retains Codex; preserve historical Codex data fixtures unrelated to selection.

**Patterns to follow:** `import_fake_oauth`, `raw_bundled_models`, `catalog`, and `standalone_cli_scope` in the existing ACP test.

**Execution note:** Use only fake credentials, isolated homes, and the existing offline network controls. Never test a rejection by sending a real provider request.

**Test scenarios:**

1. In an isolated control configuration without the provider exclusion, fake Codex OAuth exposes a bundled Codex selector; the same credentials under managed policy do not expose it.
2. Standalone and T3 ACP sessions advertise exactly the retained curated models; attempting to select the known Codex selector fails rather than changing the active model.
3. An explicit standalone CLI Codex selector fails as a disabled provider before a model request, even when a widened model scope includes Codex.
4. Widen both common `enabledModels` and common `disabledProviders` at runtime; T3's rendered overlay still excludes Codex while keeping the retained provider selections.
5. Reconciliation preserves the fake authentication and conversation state used by the existing settings tests; native T3 Codex settings remain outside the OMP changes.

**Verification:** `omp-acp` passes against the pinned executable. A scratch mutation reintroducing Codex selection fails the intended runtime assertion; removing provider disabling while keeping model curation fails the explicit-selection assertion. Follow the repository's mutation-testing and copied-worktree index guidance before running those controls.

### U3. Align OMP instructions and routing documentation

**Goal:** Remove the instruction that still permits OMP's Codex provider on explicit request.

**Requirements:** R4, R6; KTD4.

**Dependencies:** U1.

**Files:** `home/h82/agents/instructions/instructions.md.tmpl`, `tests/agent-instructions.py`, `docs/agent-routing.md`.

**Approach:** Update the OMP-only provider guidance and its rendered-instruction expectations per KTD4. Preserve all native Codex delegation rows and the external cross-model review permission.

**Patterns to follow:** Harness-specific instruction sections and the existing rendered-instruction check.

**Test scenarios:**

1. Rendered OMP instructions describe only the retained execution providers, preserve paid-provider opt-in rules, and retain the native Codex cross-model review route.
2. Rendered native Codex and T3 routing retain their current models, effort levels, and provider identities.

**Verification:** `agent-instructions` passes and `docs/agent-routing.md` agrees with the OMP instruction change.

## Verification Contract

Planning runs no tests or builds. Implementation records local and CI evidence separately.

| Gate | Implementation evidence |
| --- | --- |
| Formatting and prose | `git diff --check`, lint changed Markdown, and `nix fmt -- --ci` where the platform exposes it. |
| OMP contract | Build `.#checks.x86_64-linux.omp-settings`, `.#checks.x86_64-linux.omp-models-load`, and `.#checks.x86_64-linux.omp-acp` on Linux; use corresponding native Darwin checks on macOS. |
| Instructions | Build the affected `agent-instructions` check on a supported platform. |
| Activation | Build `.#vmChecks.omp-activation` on Linux with KVM; do not apply a generation to the developer's host for validation. |
| Regression strength | Run U2's bounded negative controls in a safe scratch copy with an independent Git index; report any unavailable baseline evidence. |
| Publication readiness | Require current-head CI, flake evaluation, all declared checks, all VM tests, and every production/bootstrap host output on supported builders, as required by `AGENTS.md`. |

Keep the strongest runtime assertion in `tests/omp-acp.py`; configuration restoration assertions cover a separate lifecycle contract.
Read the required check-design learnings before changing tests or trusting a guard, and add no new flake check for this change.
Repository protocol checks do not prove live T3 app orchestration or authenticated provider behavior; report those separately if performed, without claiming them from builds.

## Definition of Done

- U1 produces the shared policy and restores it through the existing activation paths.
- U2 verifies the retained model set and rejects authenticated Codex selection without network egress to real providers.
- U3 aligns the instructions and routing documentation while preserving native Codex and sanctioned reviews.
- R1-R6 are covered by the unit evidence and repository verification requirements above.
- No user credentials, history, upstream binaries, release pins, or unrelated routing choices were changed; abandoned experimental code is removed.
- Any unsupported platform or unavailable live check is reported as pending evidence rather than a pass.
