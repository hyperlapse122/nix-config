---
title: KakaoTalk from the Mac App Store on macOS Hosts - Plan
type: feat
date: 2026-10-17
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# KakaoTalk from the Mac App Store on macOS Hosts - Plan

## Goal Capsule

- **Objective:** After an apply with the App Store signed in, every macOS host has KakaoTalk installed from the Mac App Store and kept current, and a signed-out App Store never stops the apply.
- **Means:** a new guarded root step in nix-darwin's `postActivation`, after the Xcode step and before Home Manager, that runs `mas` in the primary user's session for KakaoTalk (KTD1, KTD2).
- **Authority:** this plan's R-IDs win on behavior; KTDs win on mechanism; `AGENTS.md` and the learnings it links win on repository conventions.
- **Stop conditions:** stop and report if `homebrew.masApps` or `programs.mas` turns out to be the only way to install the app, or if the step cannot run without being able to abort the `set -e` activate script.
- **Execution profile:** mostly configuration plus evaluation and build checks; no hardware apply.
- **Finishing:** `ce-work` implements and verifies locally; shipping and the PR belong to the caller.

## Product Contract

### Summary

Add KakaoTalk (Mac App Store id `869223134`, bundle `com.kakao.KakaoTalkMac`) to every macOS host. The nix-darwin apply installs it with `mas` when `/Applications/KakaoTalk.app` is missing and upgrades it otherwise, the same way it already handles Xcode. Checks and docs are updated so the new step is guarded the same way the Xcode step is.

### Problem Frame

KakaoTalk is the user's messenger on the Mac, and today it is installed by hand, so a new or rebuilt Mac lacks it until someone remembers. Xcode is currently the only Mac App Store app the configuration manages.

### Key Decisions

- **Install from the Mac App Store, not a Homebrew cask.** The user asked for the App Store source. Governs R1.

### Requirements

**Install and upgrade**

- R1. Every macOS host's apply, production and bootstrap, installs KakaoTalk from the Mac App Store (id `869223134`) when `/Applications/KakaoTalk.app` is missing, trying `mas install` then `mas get`.
- R2. When `/Applications/KakaoTalk.app` exists, the apply runs `mas upgrade 869223134`, so the App Store decides the version.

**Never break the apply**

- R3. A signed-out App Store, a failed download, or unresolved user ids prints one line naming the problem and the fix, and the apply continues.

**Guards and docs**

- R4. Repository checks fail when the KakaoTalk install or upgrade call is missing, unguarded, not run in the primary user's session, or ordered outside "after `brew bundle`, before Home Manager".
- R5. `docs/macos.md`, `docs/verification.md`, and `AGENTS.md` describe KakaoTalk as a managed App Store app next to Xcode.

### Scope Boundaries

- KakaoTalk login, settings, and launch-at-login are out of scope; they live in the app.
- NixOS and non-NixOS Linux hosts get nothing; KakaoTalk has no NixOS package here, so `modules/shared/darwin-apps.nix` needs no entry.
- Considered and not built: a list of App Store apps with a per-app generator. With KakaoTalk the only app outside Xcode, a literal block is smaller; a second App Store app would justify the list.
- Considered and not built: removing KakaoTalk when it leaves the configuration. Cleanup stays manual, matching Homebrew's `cleanup = "none"`; a request to uninstall dropped apps would change this.

### Deferred to Follow-Up Work

- Folding Xcode's install and upgrade into the App Store step. It would remove the duplicated wrapper but rewrites every Xcode assertion in `tests/darwin-config.nix` and `tests/darwin-outputs.nix`; not requested.

## Planning Contract

### Key Technical Decisions

- KTD1. **A separate root step in `postActivation`, not `homebrew.masApps` or `programs.mas`.** `modules/darwin/xcode.nix` already records why: `brew bundle` runs `mas` as the user while mas 7 needs root to install, a failed bundle aborts the activate script, and `programs.mas` exits the whole script when the App Store is signed out. The existing `darwin-config` assertion that `homebrew.masApps == { }` and `programs.mas` is off stays as it is.
- KTD2. **New module `modules/darwin/app-store.nix`, imported by `modules/darwin/profile.nix`, holding one literal KakaoTalk block for id `869223134` and bundle `/Applications/KakaoTalk.app`.** One concern per module: Xcode's step also handles `xcode-select`, the license, and first launch, which do not apply to other apps. With one app, no list or per-app generator is built.
- KTD3. **Order the step with `lib.mkOrder 750`.** That sits strictly after Xcode's `lib.mkBefore` (order 500) and before Home Manager's `postActivation` call, which Home Manager's nix-darwin module defines at the default order 1000. Relying on import order between two definitions of one order is not a contract. Running before Home Manager keeps the step at the last point that still runs as root, as KTD1 requires.
- KTD4. **Reuse the Xcode step's shell pattern verbatim in shape:** resolve the primary user's uid and gid at activation time, call `mas` through `/bin/launchctl asuser <uid> /usr/bin/env SUDO_UID=… SUDO_GID=… <mas> "$@"`, and put every `mas` call in an `if !` or `elif !` condition whose branch only echoes. The step uses its own variable and function names (for example `appStoreUid`, `appStoreMas`) so it does not depend on shell state the Xcode step defines.
- KTD5. **Generalize both Xcode-bound `darwin-config` assertions instead of exempting the new step.**
  1. The launchctl assertion collects every line before Home Manager that names the `mas` executable (`masLines`) and requires the Xcode wrapper string. It must accept each step's own wrapper string, Xcode's and the App Store step's, while still failing for a bare `mas` call.
  2. The guard assertion keeps only calls through `xcodeMas` (`masCalls`). Its filter must also collect calls through the App Store step's wrapper, excluding each wrapper's definition line, and still require `if !` or `elif !` on every call.

### Sources

- `modules/darwin/xcode.nix`: the pattern to mirror, and the rationale for KTD1.
- `tests/darwin-config.nix` (the Xcode block near the `masLines`, `masCalls`, and `guarded` bindings): the assertions to extend.
- `tests/darwin-outputs.nix` (the `lineof` ordering block for the Xcode step): the materialized-order check to extend.
- `mas info 869223134` returns KakaoTalk by Kakao Corp., and the installed `/Applications/KakaoTalk.app` on the user's Mac reports `kMDItemAppStoreAdamID = 869223134`.
- Learnings to read before writing the checks: `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`, `.compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md`, and `.compound-engineering/artifacts/solutions/best-practices/verify-linux-only-nix-check-inputs-on-macos-through-derivation-show.md`.

### Assumptions

- Both bootstrap and production outputs install KakaoTalk, as they do Xcode; the app holds no repository secrets.
- `mas get` exists in the pinned `mas`, as the Xcode step already calls it.

## Implementation Units

### U1. App Store step module

- **Goal:** install or upgrade KakaoTalk during activation without ever aborting it.
- **Requirements:** R1, R2, R3; KTD1, KTD2, KTD3, KTD4.
- **Dependencies:** none.
- **Files:** create `modules/darwin/app-store.nix`; modify `modules/darwin/profile.nix`.
- **Approach:**
  1. Resolve the uid and gid and define the wrapper, then install with `mas install` falling back to `mas get` when the bundle is missing, otherwise run `mas upgrade`.
  2. Each failure branch echoes one line prefixed with `kakaotalk:` that names its own fix. A failed install or upgrade names the App Store sign-in. Unresolved ids name the account: `system.primaryUser` must be an existing user.
  3. Import the module from `modules/darwin/profile.nix`.
- **Patterns to follow:** `modules/darwin/xcode.nix`, including its header comment style.
- **Test scenarios:** covered by U2 and U3.
- **Verification:** `darwinConfigurations.<host>.system` builds and its `activate` script contains the KakaoTalk block after the Xcode block and before the Home Manager call.

### U2. Evaluation check on Linux

- **Goal:** `darwin-config` fails when the KakaoTalk step is missing, unguarded, or not run as the user.
- **Requirements:** R4; KTD5.
- **Dependencies:** U1.
- **Files:** modify `tests/darwin-config.nix` (assertions and its header comment).
- **Approach:** add assertions on the `postActivation` lines before Home Manager, and generalize the existing every-mas-call-through-launchctl assertion per KTD5.
- **Test scenarios:**
  - The fixture's lines contain `if ! <wrapper> install 869223134 && ! <wrapper> get 869223134; then` and `elif ! <wrapper> upgrade 869223134; then`.
  - The step resolves the uid and gid of `system.primaryUser` with the same `|| var=` fallback form the Xcode step uses.
  - Mutation: dropping the `if !` from the KakaoTalk install line fails the guard assertion.
  - Mutation: replacing the KakaoTalk wrapper with a bare `mas` call fails the launchctl assertion.
  - Mutation: removing the module import fails the install-line assertion.
  - The existing Xcode assertions still pass unchanged.
- **Verification:** `checks.x86_64-linux.darwin-config` passes, and each mutation above fails it.

### U3. Materialized-order check on macOS

- **Goal:** `darwin-outputs` proves from the built `activate` script that the KakaoTalk step runs after `brew bundle` and before Home Manager.
- **Requirements:** R4; KTD3.
- **Dependencies:** U1.
- **Files:** modify `tests/darwin-outputs.nix` (ordering block and header comment).
- **Approach:** extend the `lineof` ordering block with the KakaoTalk install line, requiring `brew bundle` < Xcode install < KakaoTalk install < Home Manager call.
- **Test scenarios:**
  - Both fixture outputs pass with the step present.
  - Mutation: ordering the step after the Home Manager call fails the check with a message naming KakaoTalk.
- **Verification:** `checks.aarch64-darwin.darwin-outputs` builds on this Mac.

### U4. Documentation

- **Goal:** the docs say KakaoTalk is a managed App Store app and how sign-in affects it.
- **Requirements:** R5.
- **Dependencies:** U1.
- **Files:** modify `docs/macos.md`, `docs/verification.md`, `AGENTS.md`.
- **Approach:**
  1. `docs/macos.md`: replace "Xcode is the one Mac App Store app" with a description covering KakaoTalk; mention KakaoTalk in the prerequisites, step 6, step 7, and the signed-out troubleshooting row.
  2. `docs/verification.md`: extend the `darwin-config` and `darwin-outputs` descriptions, and add a macOS hardware checklist item that `mas list` lists `869223134`.
  3. `AGENTS.md`: add `app-store.nix` to the `modules/darwin/` description, saying it installs or upgrades KakaoTalk from the Mac App Store after the Xcode step.
- **Test scenarios:** Test expectation: none -- documentation only; the Markdown lint hook covers formatting.
- **Verification:** `mise run lint-staged-markdown` passes on the changed files, matching the Verification Contract's Markdown row.

## Verification Contract

| Gate | Command | Applies to |
| --- | --- | --- |
| Format | `nix fmt -- --ci` | U1-U3 |
| Flake evaluation | `nix flake check --no-build` | all |
| Linux evaluation check | `checks.x86_64-linux.darwin-config`; on this Mac, verify its inputs through `nix derivation show` per the linked learning when no Linux builder is available | U2 |
| macOS build check | `nix build --no-link .#checks.aarch64-darwin.darwin-outputs` | U3 |
| macOS systems | `nix build --no-link .#darwinConfigurations.<host>.system` for every host, production and bootstrap | U1 |
| Markdown | `mise run lint-staged-markdown` through the pre-commit hook | U4 |

No `darwin-rebuild switch` or `nr switch` runs as validation.

## Definition of Done

- R1 through R5 hold, and every gate in the Verification Contract passes, or a gate that cannot run on this machine is named with the reason.
- Each mutation listed in U2 and U3 was tried and failed its check, then reverted.
- No abandoned-attempt code or mutation remains in the diff.
