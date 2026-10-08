---
title: macOS Telegram Desktop Cask - Plan
type: feat
date: 2026-10-09
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# macOS Telegram Desktop Cask - Plan

## Goal Capsule

- **Objective:** The macOS host runs Telegram Desktop, the same Telegram client the NixOS hosts run.
- **Means:** Map the `telegram-desktop` package to the `telegram-desktop` cask in `modules/shared/darwin-apps.nix`, and pin that choice in the `darwin-config` check (U1, U2).
- **Authority:** Issue #187 and the Key Decisions below win over this plan's own choices; Key Technical Decisions win on mechanism.
- **Execution profile:** Two small Nix edits. On the Mac, verify by evaluating the `darwin-config` build script and building `darwin-outputs`; CI's check shards and `build-darwin` job build the rest.
- **Stop conditions:** Stop if the `telegram-desktop` cask no longer exists in Homebrew core, or if a change outside `modules/shared/darwin-apps.nix` and `tests/darwin-config.nix` turns out to be needed.
- **Finish:** The implementer ships the PR. The user does the hardware check (`nr switch`, sign-in) and removes the old app by hand.

## Product Contract

### Summary

Switch the macOS cask for Telegram from `telegram` (Telegram for macOS) to `telegram-desktop` (Telegram Desktop), and make the `darwin-config` check fail if the mapping drifts back.

### Problem Frame

`modules/shared/darwin-apps.nix` maps the `telegram-desktop` package to the `telegram` cask. That cask is Telegram for macOS, the native Swift client, a different app from Telegram Desktop, the Qt client the NixOS hosts install. Non-NixOS Linux hosts install no Telegram client: `tests/non-nixos-outputs.nix` keeps GUI packages off them. The user wants macOS and NixOS to run the same client.

### Requirements

**Cask mapping**

- R1. The `telegram-desktop` package's macOS decision is the cask `telegram-desktop`.
- R2. No macOS host declares the `telegram` cask.

**Checks**

- R3. `darwin-config` passes, and fails if `telegram-desktop` maps to any cask other than `telegram-desktop` or if `telegram` appears among the macOS casks.
- R4. `darwinConfigurations.<host>.system` builds, and its Brewfile lists `telegram-desktop`, not `telegram`.

### Key Decisions

- **Use the `telegram-desktop` cask.** (session-settled: user-directed — chosen over keeping the `telegram` cask: the macOS host should run the same client as the Linux hosts.) Governs R1, R2.
- **Leave the old `telegram` cask unmanaged.** Homebrew cleanup stays `"none"` in `modules/darwin/homebrew.nix`, so switching does not uninstall `Telegram.app`. (session-settled: user-directed — chosen over changing cleanup or uninstalling `telegram` declaratively: the user removes the old app by hand after confirming the new client works.) Governs R2.
- **No repository documentation for the migration.** The PR description tells the user to run `brew uninstall --cask telegram` after confirming the new client works. (session-settled: user-directed — chosen over a docs note: it is a one-time manual step.)

### Scope Boundaries

- Not changing `modules/darwin/homebrew.nix` or its cleanup mode.
- Not touching Linux Telegram configuration (`home/h82/default.nix`, `home/h82/desktop/kde/autostart.nix`).
- No macOS autostart for Telegram Desktop; the current `telegram` cask has none either.
- Not rewriting historical plans under `.compound-engineering/artifacts/plans/` that mention the `telegram` cask.

### Sources

- Issue #187.
- `brew info --cask telegram-desktop` (2026-10-09): Telegram Desktop 7.2.9, core tap, installs `Telegram.app` renamed to `Telegram Desktop.app`, so it does not collide with the `Telegram.app` the `telegram` cask installed.

## Planning Contract

### Key Technical Decisions

- KTD1. **Pin the cask by name in `darwin-config`.** The check's Homebrew and Brewfile assertions compare against `mapping.casks`, so they follow the mapping and pass if it reverts to `telegram`. A pinned assertion, like the existing `ghostty`/`1password` pin and the `orbstack` absence check in `assertMapping`, is what makes R3 fail on drift. Covers R3.

### Assumptions

- The pin belongs in `assertMapping` in `tests/darwin-config.nix`, next to the `orbstack` absence check, rather than in a new check file.
- `telegram-desktop` is a core cask, so `tapOf` returns null and no tap or trust entry is needed.

## Implementation Units

### U1. Map telegram-desktop to the telegram-desktop cask

- **Goal:** The macOS cask list carries `telegram-desktop` instead of `telegram`.
- **Requirements:** R1, R2, R4.
- **Dependencies:** none.
- **Files:** `modules/shared/darwin-apps.nix`.
- **Approach:** Change the `telegram-desktop` entry's `cask` value from `"telegram"` to `"telegram-desktop"`. Nothing else in the mapping changes.
- **Test scenarios:** covered by U2.
- **Verification:** `mapping.casks` contains `telegram-desktop` and not `telegram`.

### U2. Pin the Telegram cask in darwin-config

- **Goal:** `darwin-config` fails if the Telegram mapping drifts back.
- **Requirements:** R3 (KTD1).
- **Dependencies:** U1.
- **Files:** `tests/darwin-config.nix`.
- **Approach:**
  1. In `assertMapping`, assert that `mapping.apps.telegram-desktop` is exactly `{ cask = "telegram-desktop"; }`, with a failure message naming the package.
  2. Assert that `telegram` is not among `mapping.casks`, mirroring the `orbstack` check.
  3. Update the header comment's GUI-apps bullet to mention the Telegram pin.
- **Patterns to follow:** the `orbstack` absence check and the pinned `ghostty`/`1password` list in `assertMapping`.
- **Test scenarios:**
  - With U1 applied, `darwin-config` builds.
  - Mutation: revert the mapping to `telegram`; both new assertions fail and name the reason.
  - Mutation: map `telegram-desktop` to `leftOut`; the cask-value assertion fails.
- **Verification:** the check passes on the branch and fails under each mutation, reverted afterwards.

## Verification Contract

| Gate | Command | Where |
| --- | --- | --- |
| Format | `nix fmt -- --ci` | local |
| `darwin-config` and the U2 mutations, without a Linux builder | `nix eval --raw .#checks.x86_64-linux.darwin-config.buildCommand \| grep -F "echo '"`: no match on the branch, a match naming telegram under each mutation | Mac |
| Brewfile lists `telegram-desktop` (R4) | `nix build --no-link .#checks.aarch64-darwin.darwin-outputs` | Mac, and CI `build-darwin` |
| Fast checks, including `darwin-config` | `nix flake check` | Linux builder or CI |
| `darwin-config` built | `nix build --no-link .#checks.x86_64-linux.darwin-config` | Linux builder or CI check shards |
| Hardware | `nr switch` on the Mac, open `/Applications/Telegram Desktop.app`, sign in | user, manual |

Before mutation testing in a scratch copy, read `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`.

## Definition of Done

- U1 and U2 are committed on one branch with `nix fmt -- --ci` clean.
- `darwin-config` passes and fails under the U2 mutations; mutations are reverted.
- CI's `build-darwin` job passes.
- The PR description tells the user to run `brew uninstall --cask telegram` after confirming Telegram Desktop works, warns that any secret chats in Telegram for macOS are device-only and lost with it, and states that the hardware check is pending.
- No experimental or abandoned code remains in the diff.
