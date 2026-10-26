---
title: Distinguish Synthetic Infinite Model Names - Plan
type: feat
date: 2026-10-26
topic: synthetic-infinite-model-suffix
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Distinguish Synthetic Infinite Model Names - Plan

## Goal Capsule

- **Objective:** Distinguish Synthetic `infinite:` models from standard Hugging Face models in OMP and ACP model lists when upstream assigns identical display names.
- **Means:** Append `" (infinite)"` to the rendered display name of Synthetic catalog rows whose ID starts with `infinite:` unless the upstream display name already ends with `" (infinite)"` (KTD1).
- **Product authority:** The user requested suffixing Synthetic `infinite` model display names with `(infinite)` and authorized an autonomous end-to-end LFG run.
- **Open blockers:** None.

## Product Contract

### Summary

Append `" (infinite)"` to the rendered display names of Synthetic `infinite:` models in OMP's managed model declarations.
Keep all other Synthetic and OpenRouter display names, model IDs, selectors, and raw catalog snapshots unchanged.

### Problem Frame

Synthetic's upstream catalog currently gives `infinite:small:vision` and `hf:deepseek-ai/DeepSeek-V4.1-Flash-1017` the same `display_name`, `DeepSeek V4.1 Flash 10/17`.
OMP and its ACP `model` configuration options render both selectors under identical visible labels, making the free `infinite:` alias indistinguishable from the paid dated Hugging Face model in model pickers.

### Requirements

- R1. Every Synthetic catalog row whose raw `id` starts with `infinite:` renders in OMP's managed model declarations with `" (infinite)"` at the end of its `name`, without duplicating the suffix when the upstream `display_name` already ends with `" (infinite)"`.
- R2. Non-`infinite:` Synthetic rows (`hf:*`, `syn:*`, and any other prefix) and all OpenRouter rows retain their upstream display names unchanged.
- R3. Model IDs, provider-qualified selectors (`synthetic/infinite:...`), T3 `customModels`, and the raw committed catalog snapshot (`home/h82/agents/synthetic-catalog.json`) remain unmodified.

### Acceptance Examples

- AE1. **Covers R1, R2, R3.** With the current catalog snapshot, `synthetic/infinite:small:vision` renders `name` as `DeepSeek V4.1 Flash 10/17 (infinite)` while `synthetic/hf:deepseek-ai/DeepSeek-V4.1-Flash-1017` renders `name` as `DeepSeek V4.1 Flash 10/17`, and both selectors remain selectable in OMP CLI and ACP.
- AE2. **Covers R1.** A Synthetic row with `id` `infinite:large:text` and `display_name` `Example (infinite)` renders as `Example (infinite)`, not `Example (infinite) (infinite)`.

### Scope Boundaries

- `syn:*` Synthetic rows already carry their raw ID as `display_name` upstream and receive no suffix.
- Raw catalog snapshot schema and `scripts/synthetic-models-watch` remain unchanged so upstream catalog refreshes continue recording verbatim upstream fields.
- Actual T3 GUI picker rendering is not asserted from headless/ACP protocol checks; repository checks prove OMP CLI and ACP metadata.

### Sources / Research

- `home/h82/agents/omp-declarations.py`: renders `models.yml` entries and `modelOverrides` from `synthetic-catalog.json` and `openrouter-catalog.json`.
- `home/h82/agents/synthetic-catalog.json`: contains `infinite:small:vision` and `hf:deepseek-ai/DeepSeek-V4.1-Flash-1017` with identical `display_name` `DeepSeek V4.1 Flash 10/17`.
- `tests/omp_models_load.py` and `tests/omp-acp.py`: exercise `omp models --json` and `omp --mode acp` against the rendered `models.yml`.
- `docs/provisioning.md`: documents `omp-declarations.py` rendering of the Synthetic snapshot.

## Planning Contract

### Key Technical Decisions

- KTD1. **Transform `infinite:` display names in `omp-declarations.py`.** Apply the `" (infinite)"` suffix when building `result["name"]` for `provider == "synthetic"` and `row["id"].startswith("infinite:")` (guarded against an existing `" (infinite)"` suffix). Because `omp-declarations.py` feeds both `models` and `modelOverrides` in `models.yml`, one rule covers bundled and unbundled `infinite:` rows alike while keeping `home/h82/agents/synthetic-catalog.json` a verbatim upstream snapshot for `model-catalogs.yml` refreshes.
- KTD2. **Verify rendered names at the real OMP CLI and ACP runtime boundaries.** Derive expected `name` values dynamically from each snapshot row in `tests/omp_models_load.py` (`omp models --json`) and `tests/omp-acp.py` (`session/new` `model` `configOptions`) so scheduled `.github/workflows/model-catalogs.yml` refreshes keep passing when Synthetic repoints `infinite:*` aliases, and verify literal `infinite:` suffixing, idempotence on an already-suffixed `" (infinite)"` row, and non-application on OpenRouter rows against synthetic fixture inputs passed via `tests/omp-models-load.nix`.

### Assumptions

- Matching the Synthetic ID prefix `infinite:` (`row["id"].startswith("infinite:")`) is the intended boundary for "infinite models", covering `infinite:small:vision` today and any future `infinite:*` tier Synthetic adds.
- A single ASCII space before `(infinite)` (`DeepSeek V4.1 Flash 10/17 (infinite)`) matches existing parenthetical labels in OMP's catalog such as `Auto Router (Beta)`.

## Implementation Units

### U1. Suffix `infinite:` display names in OMP model declarations and runtime checks

**Goal:** Render `" (infinite)"` on Synthetic `infinite:` model names and verify the loaded names through the pinned OMP runtime.

**Requirements:** R1, R2, R3, AE1, AE2.

**Dependencies:** None.

**Files:** `home/h82/agents/omp-declarations.py`, `tests/omp-models-load.nix`, `tests/omp_models_load.py`, `tests/omp-acp.py`, `docs/provisioning.md`.

**Approach:**

1. Update `entry()` in `home/h82/agents/omp-declarations.py` per KTD1 so Synthetic rows with `id` starting with `infinite:` append `" (infinite)"` when `display_name` does not already end with `" (infinite)"`.
2. Pass `${../home/h82/agents/omp-declarations.py}` from `tests/omp-models-load.nix` to `tests/omp_models_load.py`, assert dynamically derived `actual["name"]` values across all loaded snapshot rows in `tests/omp_models_load.py` (`omp models --json`) and `tests/omp-acp.py` (`catalog()` ACP `model` `configOptions`), and exercise controlled synthetic fixture rows in `tests/omp_models_load.py` for `infinite:` suffixing, idempotence on an existing `" (infinite)"` suffix, and non-application on OpenRouter rows.
3. Note the `(infinite)` display-name disambiguation for `infinite:` Synthetic rows in `docs/provisioning.md`.

**Patterns to follow:** `home/h82/agents/omp-declarations.py` (`hf:zai-org/GLM-5.3` Synthetic-specific metadata normalization), `tests/omp-models-load.nix` + `tests/omp_models_load.py` (passing store paths and per-row assertions against `omp models --json`), and `tests/omp-acp.py` (`catalog()` inspection of `option(state, "model")["options"]`).

**Test scenarios:**

- Loaded `omp models --json` and ACP `session/new` `model` `configOptions` list every `infinite:*` Synthetic snapshot row with `display_name + " (infinite)"` (unless already suffixed) and every `hf:*`, `syn:*`, and selected OpenRouter row with its exact upstream `display_name` or `name` (yielding `"DeepSeek V4.1 Flash 10/17 (infinite)"` for `synthetic/infinite:small:vision` and `"DeepSeek V4.1 Flash 10/17"` for `synthetic/hf:deepseek-ai/DeepSeek-V4.1-Flash-1017` on the current snapshot without pinning the floating alias across future refreshes).
- Running the declaration renderer on controlled fixture rows verifies that a Synthetic `infinite:` row without the suffix gains `" (infinite)"`, a Synthetic `infinite:` row already ending in `" (infinite)"` is not doubled, and an OpenRouter row whose ID starts with `infinite:` is not suffixed.

**Verification:** `omp-models-load`, `omp-acp`, and `omp-settings` pass, and mutation rounds removing the `infinite:` suffix branch fail both `omp-models-load` and `omp-acp` on their `name` assertions.

## Verification Contract

| Check | Command | Purpose |
| --- | --- | --- |
| OMP model declarations & runtime load | `nix build --no-link .#checks.x86_64-linux.omp-models-load` | Proves `omp models --json` loads suffixed `infinite:` names, preserves other names, and checks idempotence |
| OMP ACP catalog & session | `nix build --no-link .#checks.x86_64-linux.omp-acp` | Proves ACP `model` options carry suffixed `infinite:` names and selectors still load and select cleanly |
| OMP settings reconciliation | `nix build --no-link .#checks.x86_64-linux.omp-settings` | Proves activation reconciles updated `models.yml` |
| Formatting & diff | `git diff --check && nix fmt -- --ci` | Repository formatting and whitespace hygiene |
| Markdown lint | `mise run lint-staged-markdown` (or `markdownlint-cli2` on changed Markdown) | Proves changed Markdown files pass repository lint |

## Definition of Done

- `home/h82/agents/omp-declarations.py` appends `" (infinite)"` to Synthetic `infinite:` display names without duplicating an existing suffix or touching raw snapshots.
- `tests/omp_models_load.py` and `tests/omp-acp.py` assert loaded `name` metadata across CLI and ACP boundaries without brittle floating-alias pins, proven non-decorative by mutation rounds in a `.git`-free scratch copy.
- `docs/provisioning.md` accurately describes the `infinite:` display-name suffix.
- Relevant local checks (`omp-models-load`, `omp-acp`, `omp-settings`), Markdown lint, and `nix fmt -- --ci` pass, review findings are assessed and applied, and the PR reaches current-head CI readiness.
