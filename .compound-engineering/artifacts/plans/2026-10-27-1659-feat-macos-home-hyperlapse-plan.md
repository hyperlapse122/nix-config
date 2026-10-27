---
title: macOS Home Directory /Users/hyperlapse - Plan
type: feat
date: 2026-10-27
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# macOS Home Directory /Users/hyperlapse - Plan

## Goal Capsule

- **Objective:** On the MacBook Pro, the nix-darwin apply manages the user environment in `/Users/hyperlapse`, the home folder the company's Intune policy requires.
- **Means:** Change the macOS host's `my.user.name` and `my.user.home` values (KTD1).
- **Authority:** R1 and R2 govern product behavior; KTD1 governs the mechanism.
- **Stop conditions:** Stop if evaluation shows that `users.users.<name>.home` or Home Manager's `home.homeDirectory` disagrees with `my.user.home`.
- **Execution profile:** Two host values plus evaluation checks; no new tests.

## Product Contract

### Summary

Set `my.user.name` to `hyperlapse` and `my.user.home` to `/Users/hyperlapse` in `hosts/MacBook-Pro-Mac17-9/default.nix`. NixOS and non-NixOS Linux hosts keep their current accounts and home directories.

### Problem Frame

Intune policy on the MacBook Pro requires the home folder to be named `hyperlapse`. The host still declares `/Users/h82`, so Home Manager would place every managed file in a directory that is not the account's home.

### Requirements

- R1. The macOS host's home directory is `/Users/hyperlapse`.
- R2. Hosts of other kinds keep their current accounts and home directories.
- R3. The macOS account name is `hyperlapse`.

### Key Decisions

- **The home directory is `/Users/hyperlapse`.** Governs R1. (session-settled: user-directed — chosen over keeping `/Users/h82`: Intune policy requires the home folder name `hyperlapse`.)
- **Only macOS hosts change.** Governs R2. (session-settled: user-directed — chosen over changing the home on every host kind: the user asked for macOS only.)

### Scope Boundaries

- The user's follow-up explicitly includes changing `my.user.name` to `hyperlapse` (R3), replacing the initial assumption that the account name would remain `h82`.
- Renaming a live macOS account or moving its existing files is outside this repository change.

## Planning Contract

### Key Technical Decisions

- KTD1. **Set the values in the host file only.** `modules/darwin/profile.nix` feeds `my.user.name` into `system.primaryUser` and `my.user.home` into `users.users.<name>.home`. `lib/darwin-host.nix` selects the Home Manager account using `my.user.name`, and `home/h82/default.nix` sets its username and home from the shared host values. Shared defaults remain `h82` and `/home/h82`, so other hosts are untouched (R2).

### Assumptions

- The Mac already has the `hyperlapse` account and `/Users/hyperlapse` home when this configuration is applied. The KakaoTalk step prints an account-resolution diagnostic and skips installation without aborting activation if the account is absent, so its exit status does not validate the account name.

## Implementation Units

### U1. Point the macOS host at /Users/hyperlapse

- **Goal:** The macOS host declares `hyperlapse` as its account and `/Users/hyperlapse` as its home (R1, R3).
- **Requirements:** R1, R2, R3
- **Dependencies:** none
- **Files:** `hosts/MacBook-Pro-Mac17-9/default.nix`
- **Approach:** Replace `my.user.name` and `my.user.home` per KTD1.
- **Patterns to follow:** `docs/adding-a-host.md`, the macOS host section.
- **Test expectation:** none -- a host value change; a check that the host's home equals a literal would only restate the file. The `darwin-outputs` fixture already covers how `my.user.home` reaches nix-darwin and Home Manager.
- **Verification:** Both macOS outputs select `hyperlapse` for `system.primaryUser`, Homebrew, and Home Manager. Both `users.users.hyperlapse.home` and the Home Manager `home.homeDirectory` report `/Users/hyperlapse`; no `h82` Home Manager entry remains.

## Verification Contract

| Gate | Command | Where |
| --- | --- | --- |
| Format | `nix fmt -- --ci` | Linux |
| Account and home | Evaluate `system.primaryUser`, `nix-homebrew.user`, `users.users.hyperlapse.home`, and `home-manager.users.hyperlapse.home` for production and bootstrap | Linux evaluation |
| Flake checks | `nix flake check` | Linux; CI `check-shards` |
| macOS build | `darwinConfigurations.<host>.system` builds | CI `build-darwin` |

## Definition of Done

- U1 is in place, both outputs use the `hyperlapse` account, and both evaluated home values read `/Users/hyperlapse`.
- `nix fmt -- --ci` and `nix flake check` pass, and CI's `build-darwin` job passes on the PR head.
- No other host's account or home value changes.
- No abandoned-attempt code remains in the diff.
