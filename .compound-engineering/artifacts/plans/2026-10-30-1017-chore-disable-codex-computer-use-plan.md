---
title: Disable Codex Computer Use - Plan
type: chore
date: 2026-10-30
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Disable Codex Computer Use - Plan

## Goal Capsule

- **Objective:** A new Codex session on any host this flake configures cannot drive the desktop through Computer Use, whether it starts from the packaged `codex`, T3 Code's Codex provider, or the ChatGPT desktop app reading `~/.codex/config.toml`.
- **Means:** Turn off Codex's `computer_use` feature flag in both places that already turn off `apps`: the reconciled config key and the wrapper's startup flags (KTD1). Also disable the two bundled Computer Use plugins in the reconciled config (KTD3).
- **Authority:** This plan, then `AGENTS.md`, then `docs/codex.md` as the existing pattern.
- **Execution profile:** Lightweight; configuration plus the two existing checks that own these contracts.
- **Stop conditions:** Stop if the pinned Codex rejects `--disable computer_use` on a Linux build.
- **Finish and ship:** The LFG pipeline implements, reviews, and opens the PR; the user merges and runs `nr switch`.

## Product Contract

### Summary

Declare `features.computer_use = false` in the Codex settings activation and add `--disable computer_use` to the Codex wrapper, mirroring how `apps` is disabled today.
The same activation also sets `enabled = false` on the `computer-use@openai-bundled` and `unified-computer-use@openai-bundled` plugins.
Extend the `codex-settings` and `codex` checks and `docs/codex.md` to cover the new flag.

### Problem Frame

On the macOS host, the ChatGPT desktop app installed Codex Computer Use: `~/.codex/config.toml` enables the `computer-use@openai-bundled` and `unified-computer-use@openai-bundled` plugins, and `codex features list` reports `computer_use` as `stable true`.
The user wants Computer Use off for Codex.
Codex exposes `computer_use` as a feature flag, and `codex --disable computer_use features list` reports it false on the pinned 0.165.0.
The flag alone does not remove the `cua_repl` MCP server: with `--disable computer_use`, `codex mcp list --json` still reports it enabled with `CUA_REPL_ENABLED_SURFACES=browser,computer`. The server comes from the `unified-computer-use@openai-bundled` plugin's `.mcp.json`.

### Requirements

**Configuration**

- R1. Activation reconciles `features.computer_use = false` into `~/.codex/config.toml` on every host, leaving the rest of the file as Codex wrote it.
- R2. The packaged `codex` command disables `computer_use` at startup, so it stays off under any `CODEX_HOME`, including one whose config enables it.
- R6. Activation sets `plugins."computer-use@openai-bundled".enabled` and `plugins."unified-computer-use@openai-bundled".enabled` to `false`, so the plugin-provided `cua_repl` server no longer loads.

**Checks and docs**

- R3. `codex-settings` fails when the declared set omits `features.computer_use = false` or either plugin entry, or when activation leaves an enabled flag or plugin enabled.
- R4. `codex` fails when the wrapper leaves `computer_use` enabled under either home, given a config that enables it.
- R5. `docs/codex.md` states that Computer Use is disabled the same way as apps, with the same restart and unwrapped-binary caveats.

### Scope Boundaries

- The `notify` hook pointing at `SkyComputerUseClient` stays. The desktop app owns it, and it only reports turn ends.
- Removing `~/.codex/computer-use/` or the macOS Accessibility and Screen Recording grants is out of scope; it is user state outside this repository's declared settings.

## Planning Contract

### Key Technical Decisions

- KTD1. **Use the `computer_use` feature flag in config and wrapper, as `apps` does.** `docs/codex.md` already records why the feature switch beats per-entry toggles for apps, and the wrapper flag covers homes that never receive the declared settings, such as a T3 Code instance with its own `CODEX_HOME`. Governs R1, R2.
- KTD3. **Also disable the two bundled plugins by ID.** The flag leaves `cua_repl` enabled with the computer surface, so the plugins must be off too. If the desktop app renames them, the stale entries do nothing and a new ID shows up as a new `cua_repl` source. The wrapper gets no plugin override, because T3 Code's Codex provider shares `~/.codex/config.toml`. Governs R6.
- KTD2. **Seed the `codex` check's config with `computer_use = true` rather than relying on the unwrapped default.** Whether the Linux build enables Computer Use by default is unverified, so the raw-binary control that proves `apps` defaults on could fail or prove nothing there. A seeded enabled value makes the wrapper assertion meaningful on every platform. Governs R4.

### Assumptions

- The ChatGPT desktop app's bundled Codex (`0.165.0-alpha.1.2` at `CODEX_CLI_PATH`) honors `features.computer_use` from `config.toml`. Checked against a scratch `CODEX_HOME`: `true` by default, `false` when the config sets it.
- Plugin `enabled = false` stops Codex from loading the plugin's MCP servers. A scratch copy of `~/.codex` loads no plugins at all, so this could not be reproduced before apply. After `nr switch`, `codex mcp list` must no longer show `cua_repl`.
- Restarting Codex sessions after `nr switch` is enough; existing processes keep their loaded tools, as `docs/codex.md` already states for apps.

## Implementation Units

### U1. Disable computer_use in the declared settings

- **Goal:** Activation writes `features.computer_use = false` into `~/.codex/config.toml`.
- **Requirements:** R1, R3, R6
- **Dependencies:** none
- **Files:** `home/h82/agents/codex.nix`, `tests/codex-settings.nix`
- **Approach:**
  1. Add a `[ "features" "computer_use" ]` entry with value `false` to `declaredPaths` beside the `apps` entry.
  2. Add `[ "plugins" "computer-use@openai-bundled" "enabled" ]` and `[ "plugins" "unified-computer-use@openai-bundled" "enabled" ]` entries with value `false` (KTD3).
  3. In `tests/codex-settings.nix`, add the same entries to `declared.setPaths`, seed `computer_use = true` and both plugins as enabled, and expect them all false in `applied`.
- **Patterns to follow:** the `features.apps` entry in both files.
- **Test scenarios:**
  - A scratch home whose config has `[features] computer_use = true` and both plugins enabled ends with all three false after activation, with the unrelated `example@local` plugin, project, and MCP entries intact.
  - Removing the new `declaredPaths` entry makes the declared-file diff fail.
- **Verification:** `codex-settings` passes, and fails when the entry is dropped from `codex.nix`.

### U2. Disable computer_use in the Codex wrapper

- **Goal:** The packaged `codex` reports `computer_use` false under any home.
- **Requirements:** R2, R4
- **Dependencies:** none
- **Files:** `packages/codex.nix`, `tests/codex.nix`
- **Approach:**
  1. Append `--disable computer_use` to the wrapper's `--add-flags`, and mention the flag in the comment above it.
  2. In `tests/codex.nix`, add the flag to `wrapperFlags`, seed `computer_use = true` in both homes' `config.toml` per KTD2, add `computer_use` to the wrapped feature loop, and update the header comment.
- **Execution note:** Confirm on a Linux builder that the pinned binary accepts the flag; the macOS run already does.
- **Patterns to follow:** the `apps` handling in the same files.
- **Test scenarios:**
  - Under the default home and an alternate `CODEX_HOME`, each seeded with `computer_use = true`, `codex features list` reports `computer_use` false.
  - A wrapper without `--disable computer_use` fails both the feature loop and the wrapper-flag text check.
- **Verification:** `codex` passes, and fails when the flag is dropped from the wrapper.

### U3. Document the switch

- **Goal:** `docs/codex.md` covers Computer Use beside apps.
- **Requirements:** R5
- **Dependencies:** U1, U2
- **Files:** `docs/codex.md`
- **Approach:** Generalize the page from app connectors to both disabled features, naming `features.computer_use = false` and `--disable computer_use`, and extend the verification bullets and the local inspection line to the `computer_use` row.
- **Test expectation:** none -- documentation only.
- **Verification:** markdownlint passes on the file.

## Verification Contract

| Gate | Command | Applies to |
| --- | --- | --- |
| Formatting | `nix fmt -- --ci` (Linux CI on macOS) | U1, U2 |
| Settings check | `nix build --no-link .#checks.<system>.codex-settings` | U1 |
| Wrapper check | `nix build --no-link .#checks.<system>.codex` | U2 |
| Markdown | `mise run lint-staged-markdown` via the pre-commit hook | U3 |
| Flake evaluation and host outputs | CI `flake-check`, `check-shards`, `build-darwin` | all |
| Live desktop check (after the user applies) | `codex features list` shows `computer_use` false and `codex mcp list` has no `cua_repl` | R1, R6 |

## Definition of Done

- R1-R6 hold and every gate above passes locally where the platform supports it, with the rest recorded as deferred to CI.
- Each new assertion was shown to fail when its declaration is removed.
- No unused or experimental code remains in the diff.
