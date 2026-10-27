---
title: Flighty App Store Install - Plan
type: feat
date: 2026-10-27
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Flighty App Store Install - Plan

## Goal Capsule

- **Objective:** Every macOS host has Flighty – Live Flight Tracker from the Mac App Store after an apply, kept up to date by later applies, the same way it has KakaoTalk.
- **Means:** One App Store step in `modules/darwin/app-store.nix` that renders the existing KakaoTalk install-or-upgrade block once per entry of an app list (KTD1).
- **Authority:** This plan, then `AGENTS.md`, then the existing Xcode and KakaoTalk steps as the pattern.
- **Stop conditions:** Stop if a declared check cannot be made to pass without weakening an existing assertion on the KakaoTalk or Xcode step.
- **Execution profile:** Lightweight; Nix configuration plus the checks and docs that describe it.
- **Finish and ship:** The implementer lands the change, checks, and docs in one PR.

## Product Contract

### Summary

Add Flighty (Mac App Store id `1358823008`, bundle `/Applications/Flighty.app`) to the macOS App Store installs. The apply installs it when absent and upgrades it when present, and a signed-out App Store or a failed download never stops the apply.

### Problem Frame

Flighty is installed by hand on the user's Mac today. The repository declares the macOS app set, so a reinstall or a new Mac would come up without it.

### Requirements

**Install behavior**

- R1. The apply installs Flighty with `mas install`, falling back to `mas get`, when `/Applications/Flighty.app` is missing, and upgrades it with `mas upgrade` otherwise.
- R2. Every Flighty `mas` call runs in the primary user's session the way KakaoTalk's does, and every call that can fail is guarded so the `set -e` activate script continues.
- R3. A failed Flighty install, a failed upgrade, and unresolved user ids each print one line prefixed `flighty:` naming the cause, matching KakaoTalk's three messages.
- R4. KakaoTalk's behavior, messages, and order (after the Xcode step, before Home Manager) are unchanged, and the Flighty step also runs after Xcode and before Home Manager.
- R5. The retired-cask step still runs after every App Store app step and before Home Manager.

**Checks and docs**

- R6. `tests/darwin-config.nix` and `tests/darwin-outputs.nix` assert R1 through R5 for Flighty as they do for KakaoTalk.
- R7. `docs/macos.md` and the `app-store.nix` description in `AGENTS.md` name Flighty wherever they list the App Store apps, including the troubleshooting rows.

### Scope Boundaries

- Not building: a declarative option for hosts to choose App Store apps. Every macOS host gets the same list, as with KakaoTalk; a per-host trait would be needed only when a host must differ.
- Not building: removal of App Store apps dropped from the list. No retired App Store app exists today.
- Not changing: the Xcode step in `modules/darwin/xcode.nix`, which carries its own `xcode-select`, license, and first-launch logic.

## Planning Contract

### Key Technical Decisions

- KTD1. **Render one block per app from a Nix list in `app-store.nix`.** The list holds each app's display name, App Store id, and log prefix. The uid/gid resolution and the `appStoreMas` wrapper are emitted once, and each app gets the same `if`/`elif` chain KakaoTalk has now. Unrolling in Nix keeps every rendered line literal, so the existing line-equality checks keep working, and a third app becomes a one-line addition.
- KTD2. **Checks declare the expected apps themselves.** `tests/darwin-config.nix` and `tests/darwin-outputs.nix` keep their own list of expected ids and bundle names rather than reading the module's list, so dropping an app from the module fails the check. KakaoTalk keeps its existing assertions; Flighty gets the same ones, ordered after KakaoTalk.

### Assumptions

- Flighty's Mac App Store bundle installs as `/Applications/Flighty.app`; the hand-installed copy on this Mac has that path.
- The hand-installed copy came from the App Store, so `mas upgrade` can manage it. If not, the existing upgrade-failure message tells the user to delete it so the next apply reinstalls it.

## Implementation Units

### U1. Generalize the App Store step and add Flighty

- **Goal:** `modules/darwin/app-store.nix` installs or upgrades KakaoTalk and Flighty in that order.
- **Requirements:** R1, R2, R3, R4
- **Dependencies:** none
- **Files:** `modules/darwin/app-store.nix`
- **Approach:**
  1. Replace `kakaoTalkId` with a list of `{ name; id; tag; }` entries: KakaoTalk `869223134` `kakaotalk`, then Flighty `1358823008` `flighty` (KTD1).
  2. Emit the uid/gid lines and `appStoreMas` once, then one block per entry whose lines match today's KakaoTalk block with the name, id, bundle path, and prefix substituted.
  3. Update the module comment to describe the list; keep the `lib.mkOrder 750` placement and its rationale.
- **Patterns to follow:** the current KakaoTalk block in `modules/darwin/app-store.nix`; `modules/darwin/xcode.nix` for the guard style.
- **Test scenarios:** covered by U2, since the checks read the materialized activation script.
- **Verification:** KakaoTalk's rendered lines are byte-identical to before; Flighty's lines differ only in name, id, bundle path, and prefix.

### U2. Extend the macOS checks to Flighty

- **Goal:** Both macOS checks fail when Flighty's step is missing, misordered, or unguarded.
- **Requirements:** R5, R6
- **Dependencies:** U1
- **Files:** `tests/darwin-config.nix`, `tests/darwin-outputs.nix`
- **Approach:**
  1. In `tests/darwin-config.nix`, add the Flighty install, missing-bundle, upgrade, and message assertions beside KakaoTalk's, with Flighty after KakaoTalk and before Home Manager (KTD2).
  2. Change the retired-cask order assertion to require the retired-cask step after the last App Store app's install line.
  3. In `tests/darwin-outputs.nix`, add a `lineof` for Flighty's install line, require it after KakaoTalk's and before the Home Manager call, and require the retired-cask step after it.
  4. Update both files' header comments to list Flighty.
- **Patterns to follow:** the existing KakaoTalk assertions in both files.
- **Test scenarios:**
  - Happy path: both fixture variants render `if ! appStoreMas install 1358823008 && ! appStoreMas get 1358823008; then` between KakaoTalk's install line and the Home Manager call, and both checks pass.
  - Missing bundle: the `elif [[ ! -d /Applications/Flighty.app ]]; then` line precedes the Flighty install line, which precedes `elif ! appStoreMas upgrade 1358823008; then`.
  - Messages: a `flighty:` line names the App Store sign-in, and a `flighty: cannot resolve` line names `system.primaryUser`.
  - Ordering: the retired-cask list line comes after Flighty's install line.
  - Mutation: removing Flighty from the module's list fails both checks; moving Flighty before KakaoTalk fails the ordering assertion.
- **Verification:** both checks pass on the change and fail on each mutation above.

### U3. Update the docs

- **Goal:** The macOS guide and `AGENTS.md` describe Flighty alongside KakaoTalk.
- **Requirements:** R7
- **Dependencies:** U1
- **Files:** `docs/macos.md`, `AGENTS.md`
- **Approach:**
  1. In `docs/macos.md`, name Flighty in the App Store prerequisite, the first-apply download list, the sign-in step, the "other Mac App Store app" entry, and the retired-cask entry's ordering.
  2. Add `flighty:` troubleshooting rows beside the three `kakaotalk:` rows, or generalize them to cover both prefixes.
  3. In `AGENTS.md`, update the `app-store.nix` description to name both apps, and the retired-casks description's "after the KakaoTalk step".
- **Test scenarios:** Test expectation: none -- documentation only; `agent-instructions` reads `AGENTS.md` and must still pass.
- **Verification:** no remaining sentence calls KakaoTalk the only App Store app besides Xcode; changed Markdown passes `markdownlint-cli2`.

## Verification Contract

| Gate | Command or evidence | Where |
| --- | --- | --- |
| macOS outputs | `nix build --no-link .#checks.aarch64-darwin.darwin-outputs` | this Mac |
| macOS systems | `nix build --no-link .#darwinConfigurations.<host>.system` for every host | this Mac |
| `darwin-config` | `nix derivation show` evidence per `.compound-engineering/artifacts/solutions/best-practices/verify-linux-only-nix-check-inputs-on-macos-through-derivation-show.md`, then CI's check shards | this Mac, then CI |
| `agent-instructions` | CI check shard | CI |
| Hygiene | `git diff --check`, `markdownlint-cli2` on changed Markdown | this Mac |
| Formatting | `nix fmt -- --ci` | CI `fmt` job (no `formatter.aarch64-darwin`) |

Record local results and CI-deferred checks separately; a check not run is pending, not passed.

## Definition of Done

- U1 through U3 land in one PR, and every gate above has passed locally or on the PR's current-head CI.
- The mutations in U2 were run and each failed the intended check.
- No experimental or abandoned code remains in the diff.
