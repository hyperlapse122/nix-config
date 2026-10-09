---
title: macOS Tailscale App Cask - Plan
type: feat
date: 2026-10-10
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# macOS Tailscale App Cask - Plan

## Goal Capsule

- **Objective:** After an apply, a macOS host has the Tailscale app, so the user can log in to it and reach the tailnet from the Mac.
- **Means:** Add the core `tailscale-app` cask to `darwinOnly` in `modules/shared/darwin-apps.nix`, pin it in the `darwin-config` check, and document the manual first-launch steps (KTD1, KTD2).
- **Authority:** The Key Decisions below win over this plan's own choices; Key Technical Decisions win on mechanism.
- **Execution profile:** Small Nix and Markdown edits. On the Mac, verify by evaluating the `darwin-config` build script (an `x86_64-linux` check) and building `darwin-outputs`; CI's check shards and `build-darwin` job build the rest.
- **Stop conditions:** Stop if `tailscale-app` is no longer a Homebrew core cask, or if the work needs a change to `.sops.yaml`, `secrets/`, `tests/linux-host-secrets.sh`, or any NixOS module.
- **Finish:** The implementer ships the PR. The user runs `nr switch` on the Mac, approves the Tailscale system extension, and logs in to the app by hand.

## Product Contract

### Summary

Declare the Homebrew `tailscale-app` cask for every macOS host, make the `darwin-config` check fail if it drops out, and tell the reader of `docs/macos.md` that approving the extension and logging in happen by hand.

### Problem Frame

The MacBook is not on the tailnet, so it cannot reach the NixOS desktop or the other tailnet devices. Installing Tailscale by hand breaks the repository's rule that a Mac's apps come from its apply. The NixOS hosts run Tailscale as a system service with auth-key registration, but the macOS host plan left Tailscale out of scope.

### Requirements

**Cask**

- R1. Every macOS host's Homebrew cask list includes `tailscale-app`.
- R2. No NixOS or non-NixOS Linux host changes, and no Mac becomes a recipient of the Tailscale secrets.

**Checks**

- R3. `darwin-config` passes, and fails if `tailscale-app` is not among the macOS casks.

**Documentation**

- R4. `docs/macos.md` says the apply installs the Tailscale app, that the apply may ask for the administrator password, and that the user approves the system extension and logs in to the app by hand.
- R5. The macOS hosts plan no longer lists Tailscale as out of scope without pointing at this plan.

### Key Decisions

- **Install only. The user registers the Mac in the app.** (session-settled: user-directed — chosen over auth-key auto-registration from `secrets/tailscale.yaml` on apply: the GUI app's system extension needs manual approval on first launch, so unattended registration cannot finish on a fresh Mac.) Governs R1, R2, R4.
- **The GUI app as a client only, with no Tailscale SSH server on the Mac.** (session-settled: user-directed — chosen over the open-source `tailscaled` through nix-darwin `services.tailscale` with `--ssh --accept-routes`: the user needs outbound access from the Mac and the menu bar app, not inbound Tailscale SSH.) Governs R1.

### Scope Boundaries

- No auth key, API token, or other Tailscale secret on a Mac; `.sops.yaml`, `secrets/tailscale.yaml`, and `tests/linux-host-secrets.sh` stay as they are.
- No Tailscale preferences in the repo: launch at login, MagicDNS, accepted subnet routes, and exit nodes are set in the app.
- No same-name device cleanup on the Mac. NixOS does that with `tailscale-dedup-device`, which needs the API token.
- Not changing `modules/darwin/homebrew.nix`, its cleanup mode, or its upgrade settings.
- Considered and not built: a check that the Mac runs macOS 13 or later, the cask's floor. The only macOS host runs macOS 27 and Parallels already needs macOS 14, so a host below the floor would already fail.

### Sources

- `brew info --cask tailscale-app` (2026-10-10): Tailscale 1.104.1, core tap, `auto_updates`, requires macOS 13 or later, installs `Tailscale-1.104.1-macos.pkg`, and warns that it needs a system extension enabled in System Settings → Privacy & Security. `brew info --cask tailscale` resolves to the same cask.
- `.compound-engineering/artifacts/plans/2026-10-09-1450-feat-darwin-parallels-cask-plan.md`: the same change for Parallels Desktop, which this plan mirrors.
- `docs/macos.md` ("Secrets and authentication"): a Mac decrypts only `secrets/tokens.yaml` and its own `ssh.yaml`, and is never a recipient of the Wi-Fi or Tailscale secrets.

## Planning Contract

### Key Technical Decisions

- KTD1. **Add `tailscale-app` to `darwinOnly`, not to `apps`.** `apps` holds the macOS decision for each package a NixOS user environment has and a Linux one lacks. NixOS runs Tailscale as a system service from `modules/nixos/services/tailscale.nix`, not as a Home Manager package, so there is no `apps` key to decide. `darwinOnly` holds casks with no NixOS counterpart, which already holds `parallels`. It is a core cask, so `tapOf` returns null and no tap or trust entry is needed. Covers R1, R2.
- KTD2. **Pin `tailscale-app` by name in `assertMapping`.** The Homebrew and Brewfile assertions in `tests/darwin-config.nix` compare against `mapping.casks`, so they follow the mapping and still pass when the entry is removed. Adding it to the pinned list beside `ghostty`, `1password`, and `parallels` makes removal fail R3. Covers R3.
- KTD3. **Use the cask name `tailscale-app`, not `tailscale`.** `tailscale` is an alias Homebrew resolves to `tailscale-app`, and `tailscale` is also the name of the CLI formula. The canonical name keeps the Brewfile and the pin unambiguous. Covers R1.

### Assumptions

- Updates come from Tailscale's own updater. The cask is `auto_updates`, and the apply does not upgrade such casks without `greedy`.
- The `.pkg` installer runs through `sudo`, so it may ask for the password on the terminal running `nr switch`, the same way Parallels' privileged step does.
- An apply that runs before the extension is approved still succeeds: Homebrew installs the package, and the extension prompt appears when the app first launches. If the install itself fails without approval, the Homebrew caveat says to approve and retry, and the next apply installs it.

## Implementation Units

### U1. Declare the tailscale-app cask

- **Goal:** macOS hosts install the Tailscale app.
- **Requirements:** R1, R2.
- **Dependencies:** none.
- **Files:** `modules/shared/darwin-apps.nix`.
- **Approach:** Add `"tailscale-app"` to the `darwinOnly` list after `"parallels"` (KTD1, KTD3). Nothing else in the mapping changes.
- **Patterns to follow:** the `parallels` entry in the same list.
- **Test scenarios:** covered by U2.
- **Verification:** `mapping.casks` contains `tailscale-app`, and the macOS fixture's Brewfile lists it.

### U2. Pin tailscale-app in darwin-config

- **Goal:** Removing `tailscale-app` from the mapping fails the check.
- **Requirements:** R3.
- **Dependencies:** U1.
- **Files:** `tests/darwin-config.nix`.
- **Approach:** Add `"tailscale-app"` to the pinned cask list in `assertMapping` (KTD2).
- **Patterns to follow:** the `parallels` pin in the same list.
- **Test scenarios:**
  - With U1 applied, the `darwin-config` build script carries no failure message.
  - Mutation: with `tailscale-app` removed from `darwinOnly`, the build script carries "tailscale-app is not among the macOS casks". Run this in a scratch copy per `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`, or revert the edit afterwards.
- **Verification:** the check passes on the branch and fails under the mutation.

### U3. Document the manual first-launch steps

- **Goal:** A reader knows the apply installs Tailscale and what they must do by hand afterwards.
- **Requirements:** R4, R5.
- **Dependencies:** U1.
- **Files:** `docs/macos.md`, `.compound-engineering/artifacts/plans/2026-10-07-1651-feat-macos-darwin-hosts-plan.md`.
- **Approach:**
  1. In the Homebrew bullet of `docs/macos.md`, name the Tailscale app beside Parallels Desktop as a cask with no entry in the NixOS app mapping, because NixOS runs Tailscale as a system service rather than a user app. Say the apply that installs it may ask for the administrator password, and that on first launch the user approves its system extension in System Settings → Privacy & Security and logs in in the app. Launch at login, exit nodes, and accepted routes are app settings.
  2. In "Secrets and authentication", keep the sentence that a Mac is never a recipient of the Tailscale secrets and add that the Mac joins the tailnet through the app's own login instead.
  3. In the macOS hosts plan's scope list, drop Tailscale from the out-of-scope line and add that `2026-10-10-0328-feat-darwin-tailscale-cask-plan.md` later installs the Tailscale app as a cask.
- **Test expectation:** none -- documentation only; the pre-commit `markdownlint-cli2` hook covers formatting.
- **Verification:** the paragraphs read correctly and markdownlint passes.

## Verification Contract

| Gate | Command | Proves |
| --- | --- | --- |
| Formatting | `nix fmt -- --ci` | Nix layout unchanged by the formatter |
| Flake checks evaluate | `nix flake check --no-build` | every check, including `darwin-config`, evaluates |
| darwin-config assertions | `nix eval --raw .#checks.x86_64-linux.darwin-config.buildCommand`: a passing assertion folds to an empty string, so the script holds no failure message | R1, R3 |
| macOS fixture | `nix build --no-link .#checks.aarch64-darwin.darwin-outputs` | the macOS system builds with the new cask |
| Markdown | `mise run lint-staged-markdown` (pre-commit hook) | R4, R5 formatting |

On the Mac, `x86_64-linux` checks and NixOS outputs build only through CI's shards; leave them to CI.

## Definition of Done

- U1 through U3 are applied and every gate above that runs on the Mac passes.
- The U2 mutation fails `darwin-config`, and the mutation is reverted.
- `git diff` touches nothing under `secrets/`, `.sops.yaml`, `tests/linux-host-secrets.sh`, or `modules/nixos/`.
- No experimental edits remain in the diff.
