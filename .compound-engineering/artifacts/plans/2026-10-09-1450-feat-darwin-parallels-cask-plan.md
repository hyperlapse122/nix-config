---
title: macOS Parallels Desktop Cask - Plan
type: feat
date: 2026-10-09
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# macOS Parallels Desktop Cask - Plan

## Goal Capsule

- **Objective:** A macOS host gets Parallels Desktop from its apply, ready for the user to activate with their education (Student/Educator) license.
- **Means:** Add the core `parallels` cask to `darwinOnly` in `modules/shared/darwin-apps.nix`, pin it in the `darwin-config` check, and note the manual license step in `docs/macos.md` (KTD1, KTD2).
- **Authority:** The Key Decisions below win over this plan's own choices; Key Technical Decisions win on mechanism.
- **Execution profile:** Small Nix and Markdown edits. On the Mac, verify by evaluating the `darwin-config` build script (an `x86_64-linux` check) and building `darwin-outputs`; CI's check shards and `build-darwin` job build the rest.
- **Stop conditions:** Stop if the `parallels` cask is no longer in Homebrew core, or if a change outside `modules/shared/darwin-apps.nix`, `tests/darwin-config.nix`, and `docs/macos.md` turns out to be needed.
- **Finish:** The implementer ships the PR. The user runs `nr switch` on the Mac and enters the education key in Parallels Desktop by hand.

## Product Contract

### Summary

Declare the Homebrew `parallels` cask for every macOS host, make the `darwin-config` check fail if it drops out, and tell the reader of `docs/macos.md` that the license is activated by hand.

### Problem Frame

Parallels Desktop is not on the Mac and nix-config does not declare it, so a Mac set up from this flake has to download it by hand. The user holds a Parallels Desktop for Mac education license. The education edition is a license for the standard app, not a separate installer, so the standard cask is what a Mac needs.

### Requirements

**Cask**

- R1. Every macOS host's Homebrew cask list includes `parallels`.
- R2. No NixOS or non-NixOS Linux host changes.

**Checks**

- R3. `darwin-config` passes, and fails if `parallels` is not among the macOS casks.

**Documentation**

- R4. `docs/macos.md` says Parallels Desktop is installed by the apply and that its license is entered in the app by hand.

### Key Decisions

- **Install the latest `parallels` cask.** (session-settled: user-approved — chosen over pinning a versioned cask such as `parallels@20` or installing outside the repo: the education license is a subscription that covers the current version.) Governs R1.
- **No license key or activation in the repo.** (session-settled: user-approved — chosen over automating activation: the education edition is a license on the standard build, and a key is a secret the repo should not hold.) Governs R4.

### Scope Boundaries

- Not changing `modules/darwin/homebrew.nix`, its cleanup mode, or its upgrade settings.
- No license key, activation script, or Parallels configuration in the repo.
- No VM definitions or guest operating systems.
- Considered and not built: a check or host gate for the cask's platform requirements, arm64 and macOS 14 or later. `host.nix` accepts only `aarch64-darwin` macOS hosts, and the one macOS host runs macOS 27. The repository documents no macOS version floor, so a host below macOS 14 would fail this cask at apply; adding such a host, or Intel support, would change this call.

### Sources

- `brew info --cask parallels` (2026-10-09): Parallels Desktop 27.0.3-58680, core tap, `auto_updates`, requires arm64 and macOS 14 or later, installs `Parallels Desktop.app`.
- The cask's postflight runs `Parallels Desktop.app/Contents/MacOS/inittool init` with `sudo: true` ([Casks/p/parallels.rb](https://github.com/Homebrew/homebrew-cask/blob/HEAD/Casks/p/parallels.rb)). nix-darwin runs `brew bundle` as the user, so that `sudo` asks on the terminal running `nr switch` when its timestamp from `nr-darwin`'s `sudo -v` has expired.
- [Parallels Desktop for Mac Student and Educator Edition](https://parallels.com/products/desktop/welcome/edu), [Pitt installation guide](https://services.pitt.edu/TDClient/33/Portal/KB/Article/3867/Parallels-Desktop-Installation-Guide-for-Mac?SIDs=32), and [UW-Madison guide](https://kb.wisc.edu/page.php?id=92136): students download the standard installer and activate it with their key.

## Planning Contract

### Key Technical Decisions

- KTD1. **Add `parallels` to `darwinOnly`, not to `apps`.** `apps` holds the macOS decision for each NixOS-only package, which the `darwin-config` check requires to exist. Parallels has no NixOS counterpart, and the header comment of `modules/shared/darwin-apps.nix` reserves `darwinOnly` for casks like it. It is a core cask, so `tapOf` returns null and no tap or trust entry is needed. Covers R1, R2.
- KTD2. **Pin `parallels` by name in `assertMapping`.** The Homebrew and Brewfile assertions in `tests/darwin-config.nix` compare against `mapping.casks`, so they follow the mapping and pass if the entry is removed. Adding `"parallels"` to the existing pinned list next to `ghostty` and `1password` makes R3 fail on removal. Covers R3.

### Assumptions

- Updates are left to Parallels' own updater. The cask is `auto_updates`, and `homebrew.onActivation.upgrade` does not upgrade such casks without `greedy`, so the apply installs Parallels once and leaves later versions to the app.
- That an education key activates the standard installer comes from university IT guides and Parallels' education landing page, not a Parallels statement that the two editions share one installer. If the key is rejected, the cask choice needs revisiting.
- The pinned-list comment in `assertMapping` ("other assertions and the docs rely on these casks") stays true once `docs/macos.md` names Parallels, so the comment needs no rewrite.

## Implementation Units

### U1. Declare the parallels cask

- **Goal:** macOS hosts install Parallels Desktop.
- **Requirements:** R1, R2.
- **Dependencies:** none.
- **Files:** `modules/shared/darwin-apps.nix`.
- **Approach:** Put `"parallels"` in the `darwinOnly` list (KTD1). Nothing else in the mapping changes.
- **Patterns to follow:** the cask string form the `apps` entries use.
- **Test scenarios:** covered by U2.
- **Verification:** `mapping.casks` contains `parallels`, and the macOS fixture's Brewfile lists it.

### U2. Pin parallels in darwin-config

- **Goal:** Removing `parallels` from the mapping fails the check.
- **Requirements:** R3.
- **Dependencies:** U1.
- **Files:** `tests/darwin-config.nix`.
- **Approach:** Add `"parallels"` to the pinned cask list in `assertMapping` (KTD2).
- **Patterns to follow:** the `ghostty` and `1password` pin in the same list.
- **Test scenarios:**
  - With U1 applied, the `darwin-config` build script carries no failure message.
  - Mutation: with `parallels` removed from `darwinOnly`, the build script carries "parallels is not among the macOS casks". Run this in a scratch copy per `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`, or revert the edit afterwards.
- **Verification:** the check passes on the branch and fails under the mutation.

### U3. Document the manual license step

- **Goal:** A reader of `docs/macos.md` knows Parallels Desktop comes from the apply and needs the license entered by hand.
- **Requirements:** R4.
- **Dependencies:** U1.
- **Files:** `docs/macos.md`.
- **Approach:** Name Parallels Desktop in the Homebrew paragraph, which already lists the casks. Add that installing it runs a privileged init step, so the apply that installs it may ask for the administrator password, and that its license, education or otherwise, is entered in the app afterwards.
- **Test expectation:** none -- documentation only; the pre-commit `markdownlint-cli2` hook covers formatting.
- **Verification:** the paragraph reads correctly and markdownlint passes.

## Verification Contract

| Gate | Command | Proves |
| --- | --- | --- |
| Formatting | `nix fmt -- --ci` | Nix layout unchanged by the formatter |
| Flake checks evaluate | `nix flake check --no-build` | every check, including `darwin-config`, evaluates |
| darwin-config assertions | `nix eval --raw .#checks.x86_64-linux.darwin-config.buildCommand`: a passing assertion folds to an empty string, so the script holds no failure message | R1, R3 |
| macOS fixture | `nix build --no-link .#checks.aarch64-darwin.darwin-outputs` | the macOS system builds with the new cask |
| Markdown | `mise run lint-staged-markdown` (pre-commit hook) | R4 formatting |

On the Mac, `x86_64-linux` checks and NixOS outputs build only through CI's shards; leave them to CI.

## Definition of Done

- U1 through U3 are applied and every gate above that runs on the Mac passes.
- The U2 mutation fails `darwin-config`, and the mutation is reverted.
- No experimental edits remain in the diff.
