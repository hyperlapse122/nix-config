---
title: Claude Code You Should Know Plugin - Plan
type: feat
date: 2026-10-03
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Claude Code You Should Know Plugin - Plan

## Goal Capsule

- **Objective:** On every host, Claude Code starts with the built-in "You should know" side agent turned on, without the user running `/plugin enable` by hand, and every other plugin the user enabled stays as it was.
- **Means:** declare one nested leaf, `enabledPlugins."cc-plugin-you-should-know@builtin" = true`, in the existing Claude Code settings merge (KTD1).
- **Authority:** this plan, then `AGENTS.md`, then existing patterns in `home/h82/agents/codex.nix` and `home/h82/agents/claude.nix`.
- **Stop conditions:** stop if the pinned Claude Code binary no longer ships `cc-plugin-you-should-know` as a built-in plugin, or if the merger refuses a declaration that combines `set` and `setPaths`.
- **Execution profile:** one small Home Manager change plus its regression check; no hardware, no VM test changes.
- **Who finishes:** the implementing agent ships it as a pull request; merging stays with the user.

## Product Contract

### Summary

Turn on Claude Code's bundled `cc-plugin-you-should-know` plugin declaratively. Activation writes only that plugin's entry in `~/.claude/settings.json`, and `tests/claude.nix` asserts the entry reaches the rendered declaration.

### Problem Frame

Claude Code 2.1.287 bundles a built-in plugin, `cc-plugin-you-should-know`, that runs a side agent during longer tasks and surfaces things the user might miss above the prompt. It ships with `defaultEnabled: false`, so it stays off until someone runs `/plugin enable cc-plugin-you-should-know@builtin`. That command only changes the machine it runs on. This repository declares Claude Code settings so every host behaves the same after a rebuild, and a plugin toggled by hand is the kind of drift it exists to remove.

### Requirements

- R1. Activation on every configuration (production and bootstrap, NixOS and non-NixOS) sets `enabledPlugins["cc-plugin-you-should-know@builtin"]` to `true` in `~/.claude/settings.json`.
- R2. Activation leaves every other `enabledPlugins` entry untouched, including `compound-engineering@compound-engineering-plugin`, which `agent-plugin-sync` manages.
- R3. `nix flake check` fails when the declaration of R1 is removed or its value changes.

### Scope Boundaries

- Other built-in plugins (`cc-plugin-responsive-mode`, `cc-plugin-tips`, and so on) stay at Claude Code's defaults.
- The plugin's own settings, such as its `CLAUDE_CODE_YOU_SHOULD_KNOW_DEBUG` variable, are not declared.
- Not built: a check that the pinned Claude Code binary still contains `cc-plugin-you-should-know`. It would scan a binary of more than 200 MB in a flake check, and a renamed id leaves a harmless unused key. Revisit if a Claude Code bump renames built-in plugins (the binary's own description of `cc-plugin-sec-default`, formerly `sec-default@builtin`, shows one such rename).

## Planning Contract

### Key Technical Decisions

- KTD1. **Declare the entry as a `setPaths` leaf in the existing `claudeSettings` merge.** `scripts/agent-settings` refuses object values in `set`, and a whole-object assignment would wipe the user's other enabled plugins (R2). `setPaths` assigns one nested leaf and creates `enabledPlugins` when it is absent. `home/h82/agents/codex.nix` already uses it this way.
- KTD2. **Do not route the plugin through `agent-plugin-sync`.** That helper materializes a pinned source tree and registers a marketplace. A built-in plugin has neither; its only state is the `enabledPlugins` entry.
- KTD3. **`settings.json` is the right file.** In the 2.1.287 binary, built-in plugin enablement reads `enabledPlugins` from the settings sources (`EWt`, walking each source's `enabledPlugins`), not from `~/.claude.json`. The plugin sets neither `enabledFromPolicyOnly` nor `enabledFromTrustedSettingsOnly`, so the user settings tier is honoured. This answers the check that `.compound-engineering/artifacts/solutions/integration-issues/claude-code-global-config-keys-ignored-in-settings-json.md` requires before declaring a Claude Code key.

### Assumptions

- The plugin's own availability gate (a feature flag that is off under HIPAA, ZDR, or LDR organizations) is accepted as is. Where it is unavailable, the declared entry has no effect and causes no error.
- Like every key in `settingsTier`, a user who turns the plugin off with `/plugin disable` keeps it off until the next activation that produces a new generation re-asserts `true`.

## Implementation Units

### U1. Declare the plugin entry in the Claude settings merge

- **Goal:** the rendered `claude-declared-settings.json` carries a `setPaths` entry that enables the plugin.
- **Requirements:** R1, R2
- **Dependencies:** none
- **Files:** `home/h82/agents/claude.nix`
- **Approach:**
  1. Add a list of nested paths beside `settingsTier`, holding the one entry `[ "enabledPlugins" "cc-plugin-you-should-know@builtin" ]` with value `true`, with a short comment stating why it is a path rather than a `settingsTier` key (KTD1).
  2. Pass that list as `setPaths` in the declaration rendered for `claudeSettings`; the global-config declaration stays without one.
- **Patterns to follow:** `declaredPaths` and the `setPaths` rendering in `home/h82/agents/codex.nix`.
- **Test scenarios:** covered by U2.
- **Verification:** the rendered declaration contains `set`, `remove`, and `setPaths`, and the merger accepts it.

### U2. Assert the declaration in the Claude check

- **Goal:** `tests/claude.nix` fails when the plugin entry disappears or changes.
- **Requirements:** R3
- **Dependencies:** U1
- **Files:** `tests/claude.nix`, `tests/test_agent_settings.py`
- **Approach:**
  1. Let the expected declaration for the `claudeSettings` merge carry the same `setPaths` list, so the existing `diff` against the rendered file covers it; the `claudeGlobalConfig` expectation stays without `setPaths`.
  2. Update the check's header comment to name the nested plugin entry.
  3. Correct the comment in `test_flat_declarations_behave_as_before` that says the Claude declaration carries no `setPaths`.
- **Test scenarios:**
  - The honest module: `nix build .#checks.x86_64-linux.claude` passes on every configuration.
  - Mutation: removing the `setPaths` entry from `home/h82/agents/claude.nix` turns the check red with the "drifted from the asserted values" message.
  - Mutation: setting the value to `false` turns the check red.
- **Verification:** both mutations fail the check and the restored module passes, confirmed in a scratch copy per `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`.

## Verification Contract

| Gate | Command | Proves |
| --- | --- | --- |
| Format | `nix fmt -- --ci` | Nix layout is clean |
| Checks | `nix flake check` | `claude` and `agent-settings` checks pass with the new declaration |
| Outputs | build every `nixosConfigurations`, `homeConfigurations`, and `systemConfigs` output as `AGENTS.md` lists | the change evaluates and builds on every host |
| Merge behaviour | run the built merger against a scratch copy of a settings file that already enables `compound-engineering@compound-engineering-plugin` | the plugin entry is added and the existing entry is kept (R2) |

VM tests are unaffected by this change; `AGENTS.md` still lists `.#vmChecks.all` as a pre-ship gate.

## Definition of Done

- R1 to R3 hold, and every gate in the Verification Contract passed.
- The U2 mutations were each observed to fail the check.
- No scratch copies or abandoned edits remain in the diff.
