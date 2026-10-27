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
- **Means:** Change the macOS host's `my.user.home` value (KTD1).
- **Authority:** R1 and R2 govern product behavior; KTD1 governs the mechanism.
- **Stop conditions:** Stop if evaluation shows that `users.users.<name>.home` or Home Manager's `home.homeDirectory` disagrees with `my.user.home`.
- **Execution profile:** One-line configuration change plus evaluation checks; no new tests.

## Product Contract

### Summary

Set `my.user.home` to `/Users/hyperlapse` in `hosts/MacBook-Pro-Mac17-9/default.nix`. The account name stays `h82`. NixOS and non-NixOS Linux hosts keep their current home directories.

### Problem Frame

Intune policy on the MacBook Pro requires the home folder to be named `hyperlapse`. The host still declares `/Users/h82`, so Home Manager would place every managed file in a directory that is not the account's home.

### Requirements

- R1. The macOS host's home directory is `/Users/hyperlapse`.
- R2. Hosts of other kinds keep their current home directories.

### Key Decisions

- **The home directory is `/Users/hyperlapse`.** Governs R1. (session-settled: user-directed — chosen over keeping `/Users/h82`: Intune policy requires the home folder name `hyperlapse`.)
- **Only macOS hosts change.** Governs R2. (session-settled: user-directed — chosen over changing the home on every host kind: the user asked for macOS only.)

### Scope Boundaries

- Changing the account name (`my.user.name`) is out of scope; see Assumptions.
- Renaming or moving the existing home directory on the Mac is the user's job, since Intune owns it.

## Planning Contract

### Key Technical Decisions

- KTD1. **Set the value in the host file only.** `modules/darwin/profile.nix` already feeds `my.user.home` into `users.users.<name>.home`, and `home/h82/default.nix` feeds it into `home.homeDirectory`. Every other consumer reads `config.my.user.home`, so one value moves the whole macOS user layer. The shared default in `modules/shared/host.nix` stays `/home/h82`, so other hosts are untouched (R2).

### Assumptions

- The macOS account short name stays `h82`; only its home folder is `/Users/hyperlapse`. The request named only the home folder. If Intune also renamed the account, `system.primaryUser` would name a missing account. The KakaoTalk step prints an account-resolution diagnostic and skips installation without aborting activation, so its exit status does not validate the account name. A renamed account would require a follow-up change to `my.user.name`.

## Implementation Units

### U1. Point the macOS host at /Users/hyperlapse

- **Goal:** The macOS host declares `/Users/hyperlapse` as its home (R1).
- **Requirements:** R1, R2
- **Dependencies:** none
- **Files:** `hosts/MacBook-Pro-Mac17-9/default.nix`
- **Approach:** Replace the `my.user.home` value per KTD1. Leave `my.user.name` as it is.
- **Patterns to follow:** `docs/adding-a-host.md`, the macOS host section.
- **Test expectation:** none -- a host value change; a check that the host's home equals a literal would only restate the file. The `darwin-outputs` fixture already covers how `my.user.home` reaches nix-darwin and Home Manager.
- **Verification:** Evaluation of the macOS host reports `/Users/hyperlapse` for both `users.users.h82.home` and the Home Manager `home.homeDirectory`.

## Verification Contract

| Gate | Command | Where |
| --- | --- | --- |
| Format | `nix fmt -- --ci` | Linux |
| Home value | `nix eval .#darwinConfigurations.MacBook-Pro-Mac17-9.config.users.users.h82.home` and `...config.home-manager.users.h82.home.homeDirectory` | Linux evaluation |
| Flake checks | `nix flake check` | Linux; CI `check-shards` |
| macOS build | `darwinConfigurations.<host>.system` builds | CI `build-darwin` |

## Definition of Done

- U1 is in place and both evaluated home values read `/Users/hyperlapse`.
- `nix fmt -- --ci` and `nix flake check` pass, and CI's `build-darwin` job passes on the PR head.
- No other host's home value changes.
- No abandoned-attempt code remains in the diff.
