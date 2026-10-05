---
title: Disable claude.ai Connectors in Claude Code - Plan
type: feat
date: 2026-10-06
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Disable claude.ai Connectors in Claude Code - Plan

## Goal Capsule

- **Objective:** Claude Code sessions on every host start without the user's claude.ai connectors (Claude Docs, Gmail, Google Calendar, Google Drive, Figma, Spotify) in their MCP server list, however the session was launched.
- **Means:** Declare `disableClaudeAiConnectors = true` in the activation-merged settings tier (KTD1).
- **Authority:** This plan's R-IDs govern behavior; KTD1 governs mechanism. `AGENTS.md` governs repository conventions and verification.
- **Stop conditions:** Stop if the installed Claude Code no longer carries `disableClaudeAiConnectors` in its settings schema.
- **Execution profile:** One small Nix change plus its mirrored check; smoke verification through `nix flake check` and host builds.
- **Finishing:** The implementer lands the change; the user confirms on a real host after their own `nr switch`.

## Product Contract

### Summary

Add `disableClaudeAiConnectors = true` to the Claude Code settings this repository declares, so activation writes it into `~/.claude/settings.json` on every host. Mirror the key in the `claude` check so it asserts the rendered declaration.

### Problem Frame

Claude Code auto-loads every connector the user has authorized on claude.ai. Those connectors add MCP tools and authentication prompts to every local session, though the user does not use them from Claude Code.

### Key Decisions

- **Disable every claude.ai connector, not a subset.** The request was to turn off the connector feature in Claude Code. Governs R1. (session-settled: user-approved — chosen over a per-connector deny list: the request was to disable the connector feature for Claude Code)

### Requirements

- R1. A Claude Code session on any host built from this flake does not auto-load claude.ai connectors.
- R2. The setting holds regardless of launch path: terminal, GUI launcher, or an embedding app such as T3 Code.
- R3. A rebuild that produces a new generation restores the setting if it was removed from `~/.claude/settings.json`.
- R4. Connectors stay available on claude.ai web and in cloud routines.

### Scope Boundaries

- Per-connector allow or deny lists are out of scope (see Key Decisions).
- Revoking connectors on the claude.ai account is out of scope (R4).

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Use the settings key, not the environment variable.** Declare `disableClaudeAiConnectors = true` in `settingsTier` of `home/h82/agents/claude.nix`. Claude Code treats the key as true when any settings source sets it, so a project-level settings file cannot turn it back off. It also does not depend on how the session's environment was built, which can differ on non-NixOS hosts whose graphical session this flake does not configure. The existing `claudeSettings` activation merge reasserts it on each new generation. Governs R1, R2, R3. (session-settled: user-approved — chosen over `ENABLE_CLAUDEAI_MCP_SERVERS=false` in `environmentTier`: session variables may not reach GUI-launched sessions such as T3 Code)

### Research

- The installed claude-code 2.1.289 binary declares `disableClaudeAiConnectors` in its settings schema: "When true in any settings source, claude.ai MCP cloud connectors are not auto-fetched". Its reader checks every settings source (`ge(e)?.disableClaudeAiConnectors`), so the key is read from `settings.json`, not only from `~/.claude.json`. That satisfies the prevention rule in `.compound-engineering/artifacts/solutions/integration-issues/claude-code-global-config-keys-ignored-in-settings-json.md`.
- `tests/claude.nix` keeps its own copy of `settingsTier` and compares it with the JSON the module renders for the merger. A key added to only one side fails the check.

### Assumptions

- No host runs a Claude Code version older than the one that introduced the key; an older version would ignore the unknown key harmlessly.

---

## Implementation Units

### U1. Declare the connector opt-out

- **Goal:** The rendered Claude Code settings declaration carries `disableClaudeAiConnectors = true`.
- **Requirements:** R1, R2, R3, R4; KTD1.
- **Dependencies:** none.
- **Files:**
  - `home/h82/agents/claude.nix`
  - `tests/claude.nix`
- **Approach:**
  1. Add the key to `settingsTier` in `home/h82/agents/claude.nix`, with a short comment giving KTD1's reason for a settings key rather than an environment variable, in the style of the existing comments in that block.
  2. Add the same key and value to the `settingsTier` copy in `tests/claude.nix`.
- **Patterns to follow:** existing `settingsTier` entries and their comments in `home/h82/agents/claude.nix`.
- **Test scenarios:**
  - With both files updated, the `claude` check passes for every user environment in `tests/lib/configurations.nix`.
  - Mutation: removing the key from `home/h82/agents/claude.nix` alone makes the `claude` check fail with "the declared keys claudeSettings renders drifted from the asserted values".
- **Verification:** The `claude` check passes, and the mutation above turns it red.

---

## Verification Contract

| Gate | Command |
|---|---|
| Formatting | `nix fmt -- --ci` |
| Flake checks | `nix flake check` |
| Focused check | `nix build --no-link .#checks.x86_64-linux.claude` |
| NixOS VM tests | `nix build --no-link .#vmChecks.all` |
| Host outputs | Build every `nixosConfigurations`, `homeConfigurations`, and `systemConfigs` output per `AGENTS.md` |

Do not run `nixos-rebuild switch` or `nr switch` as validation.

## Definition of Done

- U1 is landed with the key in both files, and the mutation test was run and reverted.
- Every gate in the Verification Contract passes.
- No experimental or abandoned edits remain in the diff.
