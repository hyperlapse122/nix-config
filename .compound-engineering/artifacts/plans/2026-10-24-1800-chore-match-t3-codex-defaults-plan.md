---
title: Match T3 Code defaults to Codex
type: chore
status: ready
date: 2026-10-24
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
---

# Match T3 Code defaults to Codex

## Goal and scope

New T3 Code threads without project overrides should default to the same model
and reasoning effort as Codex without local overrides. Change the Home Manager declaration and its
existing configuration contract test. Preserve the text-generation selection.
Do not change existing threads or run a host activation as validation.

## Requirements

- R1: Select the `codex` provider instance and `gpt-6.1-sol` model by default.
- R2: Explicitly select `reasoningEffort = low`, Codex's model default.
- R3: Keep the selection owned as a whole so stale Claude options disappear.

## Evidence and technical decisions

`home/h82/agents/codex.nix` and the local Codex configuration declare no model
or effort override. Codex 0.164.0's model catalog places `gpt-6.1-sol` first
with priority 1 and `default_reasoning_level = low`. A fresh ephemeral
`codex app-server` thread with no model override reports `gpt-6.1-sol` and no
effort override. T3 Code's live
`orchestrator_capabilities` independently advertises that model and the
`reasoningEffort` option with default `low`. The current thread's `medium`
effort is a session override, not the model default.

The live catalog identifies the provider instance as `codex`, matching the
module's declared instance. Explicit effort avoids inheriting a stored effort:
the pinned T3 client bundle's `nX` resolver falls back to the matching model
selection's options when an option is absent. An empty options list therefore
does not always mean the model-advertised effort default.

Use the existing `modelSelections.defaultModelSelection` owned object in
`home/h82/t3code.nix`, with an option entry containing `id` and `value`.
The existing `tests/t3code-traits.nix` expectation owns this configuration
contract; extend it rather than adding another test or abstraction.
This snapshots the current default; future Codex default changes require a
corresponding declaration update.

## U1: Update the default selection and contract

Files: `home/h82/t3code.nix`, `tests/t3code-traits.nix`.

Update the independent expected selection first, confirm a mismatch against
the old rendered declaration, then change the module. Verify the generated
declaration agrees with the expectation and the text-generation selection
remains unchanged. Run the existing merger regression
`test_owned_model_selections_drop_an_effort_an_earlier_generation_wrote` in
`tests/test_agent_settings.py` for R3, and exercise the generated declaration
against a scratch settings file seeded with Claude's `effort = xhigh` option.
Confirm the result contains only Codex's `reasoningEffort = low` option and
preserves unrelated settings. No new merger behavior is needed.

## Verification and definition of done

On macOS, follow the existing learning
`../solutions/best-practices/verify-linux-only-nix-check-inputs-on-macos-through-derivation-show.md`
to compare Linux check text inputs and report that separately from a check build.
Run formatting, flake checks, available host builds, and attempt the required
VM and other-platform outputs; record platform limitations and let CI supply
the missing Linux evidence. Review the small diff, commit, push, open a PR,
and monitor current-head CI. Merge remains the user's action.

## Risks and open questions

No unresolved product decision. Home Manager writes the selection when a new
generation is activated, so this repository change alone does not alter the
running app. Existing project or thread overrides can retain their selections.
