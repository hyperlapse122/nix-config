---
title: Explicit claudeAgent enabled - Plan
type: chore
date: 2026-10-19
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Explicit claudeAgent enabled - Plan

## Goal Capsule

- **Objective:** A reader of `home/h82/t3code.nix` sees from the file alone that every T3 Code provider instance it declares is on or off. The Claude instance no longer depends on T3 Code's unstated default.
- **Means:** declare the `enabled` leaf on `claudeAgent` and pin it in the existing settings check (KTD1).
- **Authority:** this plan, then `AGENTS.md`.
- **Stop conditions:** stop if the `t3code-traits` check cannot pin the new leaf without also changing another instance's declared leaves.
- **Execution profile:** one small unit. Verify with the `t3code-traits` check and the shipping builds in `AGENTS.md`.

## Product Contract

### Summary

Add `enabled = true` to the `claudeAgent` entry of `providerInstances` in `home/h82/t3code.nix`. Pin that leaf in `tests/t3code-traits.nix` and list it in `docs/provisioning.md`.

### Problem Frame

Four of the five declared instances (`antigravity`, `codex`, `grok`, `opencode`) state `enabled`. `claudeAgent` states only `driver` and `config.launchArgs`, because T3 Code turns the Claude instance on by default. On this host `~/.t3/userdata/settings.json` holds no `enabled` for `claudeAgent`. Whether the instance is on is therefore visible only to someone who knows T3 Code's default.

### Requirements

- R1. The `claudeAgent` entry in `home/h82/t3code.nix` declares `enabled = true`, so all five declared instances state `enabled`.
- R2. The `t3code-traits` check fails when the `claudeAgent` `enabled` leaf is missing or holds a different value.
- R3. `docs/provisioning.md` lists `claudeAgent.{driver,enabled}` among the `providerInstances` leaves the merge declares.
- R4. No other declared setting changes.

### Key Decisions

- **Scope is only the `claudeAgent.enabled` leaf, with its test and doc update.** Governs R1, R4. (session-settled: user-directed — chosen over continuing the broader #250 Grok scope: #250's Grok provider work is already done, live-checked, and closed.)

## Planning Contract

- KTD1. **Pin the leaf in the declared merge spec, not in the materialized setting.** `enabled = true` equals T3 Code's default, so a check of the resulting `settings.json` value would pass even without the declaration. That trap is recorded in `.compound-engineering/artifacts/solutions/best-practices/declared-line-identical-to-distribution-default-makes-verbatim-check-vacuous.md`. `t3code-traits` already compares the whole `setPaths` list that `home/h82/t3code.nix` generates with `leaves`. Dropping the leaf therefore changes that list, and the check fails.
- KTD2. **Order follows `leaves`.** `leaves` builds the paths in attribute-name order, so the new entry sits after `providerInstances.claudeAgent.driver` and before `providerInstances.codex.config.launchArgs`.
- KTD3. **Name the default-equal leaf as an exception to the merge rule.** The `settings` comment in `home/h82/t3code.nix` and the T3 Code paragraph in `docs/provisioning.md` both say the merge declares only settings that differ from the pinned schema defaults, and that a value left at its default follows T3 Code when the default changes. `claudeAgent.enabled = true` equals that default, so both statements must say that every declared provider instance states `enabled`, even where the value equals the default. Without that note, a cleanup that follows the stated rule would delete the leaf as redundant. The doc must also say what the leaf changes: the Claude instance no longer follows a change to T3 Code's default, and a Claude instance turned off in the app is turned back on at the next activation that produces a new generation.

## Implementation Units

### U1. Declare and pin claudeAgent enabled

- **Goal:** the Claude instance states `enabled` like the other four.
- **Requirements:** R1, R2, R3, R4.
- **Dependencies:** none.
- **Files:**
  - `home/h82/t3code.nix`
  - `tests/t3code-traits.nix`
  - `docs/provisioning.md`
- **Approach:**
  1. In `home/h82/t3code.nix`, add `enabled = true;` to the `claudeAgent` block. Keep `config.launchArgs = ""`. Update the `settings` comment per KTD3.
  2. In `tests/t3code-traits.nix`, add the `providerInstances` / `claudeAgent` / `enabled` path with value `true` to `settingsExpectedBase.setPaths`, placed per KTD2. Update the file's header description of the settings.json declaration so it names the enabled Antigravity, Claude, Grok, and OpenCode instances and says "those five instances". It currently omits Grok and the Claude instance's `enabled` leaf and says "those four instances".
  3. In `docs/provisioning.md`, in the T3 Code paragraph that lists the `providerInstances` leaves the merge declares, add `claudeAgent.{driver,enabled}`, which turns on the Claude instance explicitly. Add the KTD3 exception and its effect to that paragraph. Keep the sentence that says the Claude instance's `launchArgs` leaf is owned whole.
- **Patterns to follow:** the `grok` and `opencode` entries in `home/h82/t3code.nix` and their `setPaths` entries in `tests/t3code-traits.nix`.
- **Test scenarios:**
  - With all three edits in place, `t3code-traits` passes on every host with a T3 Code trait.
  - With `enabled = true;` removed from `home/h82/t3code.nix` and the test left as edited, `t3code-traits` fails on the `setPaths` mismatch.
  - With `enabled = false;` in `home/h82/t3code.nix`, `t3code-traits` fails.
- **Verification:** the check passes, and both mutations fail it.

## Verification Contract

| Gate | Command | Proves |
| --- | --- | --- |
| Settings check | `nix build --no-link .#checks.x86_64-linux.t3code-traits` | R1, R2, R4 |
| Leaf mutation | the same build with the leaf removed, then set to `false`, each in a scratch copy | R2 fails closed |
| Flake checks | `nix flake check` | nothing else regressed |
| Formatting | `nix fmt -- --ci` | layout |
| Host outputs | the `nixosConfigurations`, `homeConfigurations`, `systemConfigs`, and `darwinConfigurations` build loop in `AGENTS.md` | every output still builds |

Run the leaf mutation in a scratch copy as `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md` describes, so it leaves the real index alone. Builds of macOS and aarch64 outputs are left to CI when no such builder is available.

## Definition of Done

- R1 to R4 hold, and every gate in the Verification Contract passes or is reported as left to CI.
- The diff touches only the three files in U1, with no leftover mutation edits.
