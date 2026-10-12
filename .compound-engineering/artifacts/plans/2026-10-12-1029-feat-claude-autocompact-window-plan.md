---
title: Claude Code Auto-Compact Window - Plan
type: feat
date: 2026-10-12
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Claude Code Auto-Compact Window - Plan

## Goal Capsule

- **Objective:** After a rebuild, Claude Code sessions for user `h82` on the 1M-window models, including the sessions T3 Code starts, compact their conversation at about 367K tokens instead of about 967K, unless a per-model `/autocompact` value or a higher-precedence settings file sets another window.
- **Means:** Declare `autoCompactWindow = 400000` in the settings tier that activation merges into `~/.claude/settings.json`, (KTD1), and pin it in the `claude` check (KTD2).
- **Authority:** The Key Decisions below win over this plan's own choices; Key Technical Decisions win on mechanism.
- **Execution profile:** Two small Nix edits. Verify with the `claude` check, a mutation round on it, `nix fmt -- --ci`, and `nix flake check`; CI builds the host outputs.
- **Stop conditions:** Stop if the packaged Claude Code no longer recognizes `autoCompactWindow`, or if the change needs the environment tier or the managed settings tier.
- **Finish:** The implementer ships the PR. The user rebuilds and restarts running Claude Code sessions.

## Product Contract

### Summary

Set Claude Code's user-level default auto-compact window to 400K tokens for every host through the declared settings, and make the `claude` check fail when the key drifts or disappears. A per-model `/autocompact` value, a project or managed settings file, and a model whose context window is below 400K still take precedence, since Claude Code caps the window at the model's context.

### Problem Frame

The declared model is `opus[1m]`, and T3 Code starts sessions on `claude-opus-5-5`, both with a native 1M window. Without a window setting, Claude Code compacts at about 967K tokens, so a session carries close to a million tokens of context before it compacts. The user wants compaction to happen much earlier.

### Requirements

**Setting**

- R1. Every Home Manager user environment writes `autoCompactWindow: 400000` into `~/.claude/settings.json` on activation, and leaves every other key as the merge already does.
- R2. A user can still change the window for one model with `/autocompact`, and that value outranks the declared key and survives a rebuild.

**Checks**

- R3. The `claude` check passes with the key declared, and fails when the key is removed or its value changes.

### Key Decisions

- **A window of 400K tokens.** Claude Code subtracts its 33K autocompact buffer, so compaction starts at about 367K. (session-settled: user-directed — chosen over 200K, 600K, and 433000, the value that would start compaction at 400K: the user wanted the window itself to read 400K.) Governs R1.

### Scope Boundaries

- No change to the model, the effort level, or any other declared key.
- No status line change. The status line's `used_percentage` still measures against the full 1M window, so it does not show when compaction will run.
- Considered and not built: `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`. It sets a percentage of the window, not a token count, and adds a second knob for the same threshold.

### Sources

- Claude Code docs, model configuration, "Set the auto-compact window" and "Default auto-compact thresholds": <https://code.claude.com/docs/en/model-config>
- Claude Code docs, settings reference, `modelSettings`: `/autocompact` saves a per-model `autoCompactWindow` there, and for that model it takes precedence over the top-level key in the same file (v2.1.288 or later): <https://code.claude.com/docs/en/settings-reference>
- Claude Code docs, environment variables, `CLAUDE_CODE_AUTO_COMPACT_WINDOW`: <https://code.claude.com/docs/en/env-vars>
- Verified locally: Claude Code 2.1.296 reads `autoCompactWindow`. With it set to `400000` in a copied config directory's `settings.json`, `claude -p /context --model claude-opus-5-5 --settings '{"fastMode":false,"showThinkingSummaries":true}'` reports `16.2k / 400k` and a 33k autocompact buffer; without it, `16.2k / 1m`. T3 Code starts `claude` with those flags and no `--setting-sources`, so it loads the user settings file. Adding `modelSettings: {"claude-opus-5-5": {"autoCompactWindow": 300000}}` beside the top-level key makes the same command report `16.2k / 300k`. The merge leaves `modelSettings` alone because it assigns only declared keys, so a rebuild does not undo an `/autocompact` choice.

## Planning Contract

### Key Technical Decisions

- KTD1. Declare the window as a `settingsTier` key in `home/h82/agents/claude.nix`. (session-settled: user-approved — chosen over the `CLAUDE_CODE_AUTO_COMPACT_WINDOW` environment variable: the variable overrides `/autocompact`, while a settings key leaves it working and follows the existing `settingsTier` pattern.) Implements R1, R2.
- KTD2. Pin the key by adding it to the `settingsTier` copy in `tests/claude.nix`. The check already compares the JSON the module renders for the merge against its own copy with `diff`, so no new assertion is needed. Implements R3.

## Implementation Units

### U1. Declare the auto-compact window

- **Goal:** Activation writes the 400K window into `~/.claude/settings.json` (R1, R2, KTD1).
- **Files:** `home/h82/agents/claude.nix`
- **Approach:** Add `autoCompactWindow = 400000;` to `settingsTier`. Above it, a short comment says three things: the value is the window, so compaction starts after the 33K buffer is subtracted; the status line percentage stays measured against 1M; the environment variable was not used because it blocks `/autocompact`. Also correct the existing `effortLevel` comment, which says the published settings schema has no `modelSettings` property: the property exists, and a per-model entry there covers only one model ID, so the top-level key is still the one that applies to every model.
- **Test scenarios:** Covered by U2.
- **Verification:** The rendered `claude-declared-settings.json` contains `"autoCompactWindow":400000` under `set`.

### U2. Pin the key in the `claude` check

- **Goal:** The `claude` check fails if the declared window drifts (R3, KTD2).
- **Files:** `tests/claude.nix`
- **Approach:** Add the same key and value to the check's `settingsTier`.
- **Test scenarios:**
  - With U1 and U2 applied, `nix build --no-link .#checks.x86_64-linux.claude` passes.
  - Mutation: with the key removed from `home/h82/agents/claude.nix` only, the check fails with "the declared keys claudeSettings renders drifted from the asserted values".
  - Mutation: with the value changed to `500000` in `home/h82/agents/claude.nix` only, the check fails the same way.
- **Verification:** Both mutation rounds go red and the restored tree goes green.

## Verification Contract

| Gate | Command | Proves |
| --- | --- | --- |
| Format | `nix fmt -- --ci` | Nix layout is unchanged by the formatter |
| Claude check | `nix build --no-link .#checks.x86_64-linux.claude` | R1, R3 |
| Mutation rounds | U2's two mutations, run in a scratch copy per the copied-worktree solution | The check guards the key |
| Flake checks | `nix flake check` | No other check regressed |
| Host outputs | The AGENTS.md build loop over `nixosConfigurations` and the other output sets, or CI's shards and `build-darwin` | Every host still builds |

## Definition of Done

- U1 and U2 are in the diff, and nothing else changes outside this plan.
- Every gate in the Verification Contract passes, or CI reports the gates that cannot run locally.
- The mutation rounds left no change in the working tree or the real index.
