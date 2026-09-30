---
title: Claude Code Left-Arrow Agents Off and Advisor On - Plan
type: feat
date: 2026-09-30
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Claude Code Left-Arrow Agents Off and Advisor On - Plan

## Goal Capsule

- **Objective:** In every Claude Code session user `h82` starts, pressing the left arrow on an empty prompt no longer opens the agents view, and Claude consults an advisor model at key moments.
- **Means:** declare `advisorModel = "opus"` in the settings tier merged into `~/.claude/settings.json` (KTD2), and declare `leftArrowOpensAgents = false` in a new global-config tier merged into `~/.claude.json` by the same packaged merger (KTD1).
- **Authority:** this plan, then `AGENTS.md`, then the existing pattern in `home/h82/agents/claude.nix` and `tests/claude.nix`.
- **Stop conditions:** stop if claude-code 2.1.285 no longer reads `advisorModel` from the user settings file or `leftArrowOpensAgents` from `~/.claude.json`, or if a change breaks any `nixosConfigurations` build.
- **Execution profile:** one settings key, one new activation entry with its declared file, their assertions in the existing `claude` check, and documentation; `ce-work` finishes it and the LFG pipeline ships it.

## Product Contract

### Summary

Add `advisorModel` to `settingsTier` and a new `globalConfigTier` holding `leftArrowOpensAgents` in `home/h82/agents/claude.nix`, merged into `~/.claude.json` by a second activation entry. Extend `tests/claude.nix` to guard both, and document both in `docs/provisioning.md`.

### Problem Frame

Claude Code 2.1.285 opens the agents view when the left arrow is pressed on an empty prompt, which the user does not want, and leaves its advisor tool off until an advisor model is chosen. Both are chosen through `/config` or `/advisor` today, which writes only the machine's own files and does not reach other hosts.

### Requirements

- R1. On every configuration, activation assigns `leftArrowOpensAgents` to `false` in `~/.claude.json`, the file Claude Code reads it from. (session-settled: user-directed)
- R2. On every configuration, activation assigns `advisorModel` in `~/.claude/settings.json`, enabling the advisor. (session-settled: user-directed)
- R3. Removing either key, or pointing the new activation at another file, fails `nix flake check`.

### Scope Boundaries

- Agent view itself (`claude agents`, `--bg`, the daemon) stays available; only the left-arrow shortcut is turned off. `disableAgentView` is not set.
- No keybinding changes in `~/.claude/keybindings.json`.
- No `CLAUDE_CODE_ENABLE_EXPERIMENTAL_ADVISOR_TOOL` environment variable.
- No other `~/.claude.json` keys are declared.

## Planning Contract

### Key Technical Decisions

- KTD1. **Turn off the shortcut with `leftArrowOpensAgents = false` in `~/.claude.json`.** (session-settled: user-directed — disable the left-arrow agents view; rejected: keep it.) In the 2.1.285 binary the gesture, footer hint, and tip all read `ce().leftArrowOpensAgents !== false`, and `ce()` is the global-config reader for `~/.claude.json`; the `/config` toggle "← opens agents" writes it through the global-config setter. The key is absent from the settings schema and from the `iCe` list of keys that are read from the user settings file first, which is why `preferredNotifChannel` and the notification keys work from `settings.json` and this key would not. `disableAgentView` was rejected because it disables the whole agent view, not just the gesture.
- KTD2. **Turn on the advisor with `advisorModel = "opus"` in `settings.json`.** (session-settled: user-directed — enable the advisor; rejected: leave it off.) The settings schema describes `advisorModel` as "Advisor model for the server-side advisor tool", and it is read from the settings file. The advisor must be at least as capable as the main model (`opus[1m]`), and the allowed aliases are `fable`, `opus`, and `sonnet`; `sonnet` is less capable, and `fable` as advisor bills to usage credits and needs a separate consent step, so `opus` is the one alias that works without either.
- KTD3. **Rely on the rolled-out feature gate rather than the experimental environment variable.** The advisor command is gated by `tengu_sage_compass2` unless `CLAUDE_CODE_ENABLE_EXPERIMENTAL_ADVISOR_TOOL` is set; the cached gate on this machine is `enabled: true`. The variable also bypasses the model-rank check, which is a larger behavior change than asked.
- KTD4. **Merge `~/.claude.json` with the existing `agent-settings` merger in a separate activation entry.** The merger already assigns only declared top-level keys, compare-and-swaps against a concurrent writer, and refuses symlinks, which is what a file Claude Code rewrites at runtime needs. A separate entry (`home.activation.claudeGlobalConfig`, after `installPackages`) keeps the existing entry's single `--settings` target, which `tests/claude.nix` parses, unchanged. The merger tightens the file's parent directory to `0700`; for `~/.claude.json` that parent is `$HOME`, which NixOS already creates `0700`, so this is a no-op.

### Assumptions

- `opus` is the advisor the user wants; a different model is a one-line change to KTD2.
- A declared key returns to its value on the next rebuild even if the user flips it in `/config`, as for every other declared key.
- A Claude Code session running during activation may rewrite `~/.claude.json` from its cache. The merger's compare-and-swap avoids clobbering the session's write, and Claude Code re-reads the file on external change, so a lost value is at worst restored on the next rebuild.

## Implementation Units

### U1. Declare the two settings and guard them

- **Goal:** R1, R2, R3 via KTD1, KTD2, KTD4.
- **Requirements:** R1, R2, R3.
- **Dependencies:** none.
- **Files:** `home/h82/agents/claude.nix`, `tests/claude.nix`, `docs/provisioning.md`.
- **Approach:**
  1. Add `advisorModel = "opus";` to `settingsTier`, with a short comment that the advisor must be at least as capable as the main model.
  2. Add `globalConfigTier = { leftArrowOpensAgents = false; };` with a comment that these keys live in `~/.claude.json` because Claude Code reads them only from its global config, render it to a second declared file (`set` plus an empty `remove`), and add `home.activation.claudeGlobalConfig` after `installPackages` invoking the merger with `--label 'Claude Code'`, `--settings ${config.home.homeDirectory}/.claude.json`, and that declared file.
  3. In `tests/claude.nix`, add `advisorModel` to the `settingsTier` mirror, add a `globalConfigTier` mirror and its expected declared file, and assert for `claudeGlobalConfig` what the check already asserts for `claudeSettings`: present, after `installPackages`, invokes the packaged merger, does not swallow its exit status, `--settings` equals `<home>/.claude.json`, and `--declared` diffs clean against the expected file. Update the check's header comment.
  4. In `docs/provisioning.md`, add `advisorModel` to the settings-file list and describe `~/.claude.json` with `leftArrowOpensAgents`.
- **Patterns to follow:** the existing `claudeSettings` activation and its assertions.
- **Test scenarios:**
  - Both declared files render the expected keys on every configuration.
  - Mutation: with `advisorModel` removed, the check fails with its declared-settings drift message.
  - Mutation: with `leftArrowOpensAgents` removed, the check fails with the global-config drift message.
  - Mutation: with the new activation pointed at `~/.claude/settings.json`, the check fails on the `--settings` target.
- **Verification:** `nix build .#checks.x86_64-linux.claude` passes and fails under each mutation (run in a scratch copy per `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`).

## Verification Contract

| Gate | Command |
| --- | --- |
| Formatting | `nix fmt -- --ci` |
| Changed check | `nix build .#checks.x86_64-linux.claude` |
| All checks | `nix flake check` |
| Every output | build each `nixosConfigurations.<name>.config.system.build.toplevel` per `AGENTS.md` |

## Definition of Done

- U1 is on one branch and every gate above passes.
- The check was seen to fail under each mutation.
- No abandoned experiment code remains in the diff.
