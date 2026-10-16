---
title: Remove the ChatGPT Desktop App - Plan
type: refactor
date: 2026-10-17
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Remove the ChatGPT Desktop App - Plan

## Goal Capsule

- **Objective:** No host this flake configures installs, autostarts, or keeps bumping the ChatGPT desktop app, and nothing outside the historical plans and the static-pie learning still describes it as installed.
- **Means:** delete the package, its release helper, its checks, and its update step, and strip every remaining mention from modules, tests, and docs (KTD1).
- **Authority:** this plan, then `AGENTS.md`, then existing repository patterns.
- **Stop conditions:** stop if removing the package breaks evaluation of a host or check in a way that needs a design change beyond deleting references.
- **Execution profile:** mostly deletion and documentation; prove it by evaluation and the repository checks, not new tests.
- **Finishes and ships:** `ce-work` implements; the calling pipeline reviews, commits, and opens the pull request.

---

## Product Contract

### Summary

Remove the ChatGPT desktop app from every host kind: the NixOS package and its KDE autostart entry, the macOS Homebrew cask, the scheduled release bump, and the checks and docs that cover them. The Codex CLI and its ChatGPT sign-in are untouched.

### Problem Frame

The ChatGPT desktop app ships on every NixOS host's user environment from a repackaged `.deb` (`packages/chatgpt.nix`), starts its window at every Plasma login, and is installed as a cask on macOS hosts. A scheduled workflow re-pins it every 30 minutes. The user no longer wants the app, so each of those pieces is cost without value: a login window to close, a pin to keep green, and a package-specific check with static-pie workarounds to maintain.

### Requirements

**Installation**

- R1. No NixOS host's Home Manager generation contains a `chatgpt` package or an `autostart/chatgpt.desktop` entry.
- R2. No macOS host's Brewfile lists the `chatgpt` cask, and `modules/shared/darwin-apps.nix` has no `chatgpt` decision.

**Release tracking**

- R3. The flake exposes no `chatgpt` or `chatgpt-release` package, and the update-dependencies workflow no longer resolves or commits a ChatGPT pin.

**Checks and documentation**

- R4. No check refers to the ChatGPT package, its autostart entry, or its release helper, and `nix flake check` still evaluates.
- R5. `README.md` and `docs/` no longer list the ChatGPT app among installed or autostarted apps, and no verification step asks to launch it.

### Scope Boundaries

- The Codex CLI, its ChatGPT account sign-in, and its verification steps stay as they are.
- Historical plans under `.compound-engineering/artifacts/plans/` stay unedited; they record past decisions.
- Uninstalling the already-installed cask on an existing Mac is out of scope: Homebrew cleanup is `"none"`, so a removed cask stays installed until the user removes it.
- A check that asserts the ChatGPT entries are absent was considered and not built: nothing re-adds them implicitly, and `darwin-config` would already force a decision if the package came back on NixOS.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Delete rather than gate behind a trait.** The request is removal, and no host wants the app, so a disabled-by-default trait would keep the package, pin, and check alive for nothing.
- KTD2. **Rewrite the cross-references that cite `packages/chatgpt.nix` as the model.** `packages/t3code-cli.nix` says its static-pie handling mirrors `packages/chatgpt.nix`, and the `codex` check in `flake.nix` says it runs a binary "as the chatgpt check does". After deletion those pointers dangle, so each comment must stand on its own.
- KTD3. **Leave the static-pie learning to the push-time refresh.** `.compound-engineering/artifacts/solutions/integration-issues/autopatchelf-corrupts-static-pie-binaries-in-deb-packages.md` cites `packages/chatgpt.nix` as its main example; the learning-refresh rule updates it on the branch before push, so this plan does not edit it.

### Assumptions

- The user wants the app gone on macOS hosts too, not only on NixOS, since "remove chatgpt desktop app" names the app rather than a platform.
- Removing `packages/chatgpt-version.json` is safe because only `packages/chatgpt.nix` and the update workflow read it.

---

## Implementation Units

### U1. Remove the package and its NixOS wiring

- **Goal:** the NixOS user environment no longer installs or autostarts ChatGPT.
- **Requirements:** R1
- **Dependencies:** none
- **Files:**
  - delete `packages/chatgpt.nix` and `packages/chatgpt-version.json`
  - modify `home/h82/default.nix` (drop the `gui` entry)
  - modify `home/h82/desktop/kde/autostart.nix` (drop the `chatgpt` binding and the `autostart/chatgpt.desktop` entry)
  - modify `tests/desktop-autostart.nix` (drop the ChatGPT name, package, entry, Exec, and assertions, and the header line describing it)
  - modify `tests/non-nixos-outputs.nix` (drop `"chatgpt"` from the GUI package list)
- **Approach:** remove each binding and its uses together so no dangling `chatgpt` identifier remains in a `let`.
- **Patterns to follow:** the Claude Desktop entries beside each removed ChatGPT entry stay as the shape reference.
- **Test scenarios:** Test expectation: none -- removal only; `desktop-autostart` and `non-nixos-outputs` keep running for the remaining apps.
- **Verification:** the NixOS host output and the `desktop-autostart` and `non-nixos-outputs` checks evaluate with no reference to `chatgpt`.

### U2. Remove the macOS cask

- **Goal:** macOS hosts stop installing the ChatGPT cask.
- **Requirements:** R2
- **Dependencies:** U1, so `darwin-config` does not see a NixOS package without a decision or a decision without a package.
- **Files:** modify `modules/shared/darwin-apps.nix`
- **Approach:** drop the `chatgpt.cask` entry; `tests/darwin-outputs.nix` derives its expected casks from this mapping, so it needs no edit.
- **Test scenarios:** Test expectation: none -- the existing `darwin-config` check covers the mapping.
- **Verification:** `darwin-config` evaluates, and the macOS fixture's expected cask list no longer contains `chatgpt`.

### U3. Remove release tracking and package checks

- **Goal:** nothing resolves, pins, or checks a ChatGPT release.
- **Requirements:** R3, R4
- **Dependencies:** U1
- **Files:**
  - delete `scripts/chatgpt-release` and `tests/test_chatgpt_release.py`
  - modify `packages/agent-tools.nix` (drop `chatgptRelease` and its export)
  - modify `flake.nix` (drop the `chatgpt` and `chatgpt-release` packages, the `chatgpt-release` and `chatgpt` checks, and reword the `codex` check comment per KTD2)
  - modify `.github/workflows/update-dependencies.yml` (drop the ChatGPT resolve step and its commit block, renumbering the step comments if they are numbered)
  - modify `packages/t3code-cli.nix` (reword the comment per KTD2)
- **Approach:** check shards derive membership from the check names, so removing the checks needs no shard edit; confirm `check-shards-guard` still passes.
- **Test scenarios:** Test expectation: none -- removal only; `check-shards-guard` and `nix flake check` evaluation prove nothing still references the removed checks.
- **Verification:** `nix flake check --no-build` evaluates, and `grep -ri chatgpt` over `flake.nix`, `packages/`, `scripts/`, `tests/`, `modules/`, `home/`, and `.github/` finds nothing.

### U4. Update documentation

- **Goal:** the docs describe the hosts as they are after the removal.
- **Requirements:** R5
- **Dependencies:** U1, U2, U3
- **Files:** modify `README.md`, `docs/provisioning.md`, `docs/verification.md`, `docs/macos.md`
- **Approach:**
  1. `README.md`: drop ChatGPT from the installed-app list, the pinned-and-bumped sentence, the non-NixOS exclusion list, and the macOS cask list.
  2. `docs/provisioning.md`: drop ChatGPT from the autostart paragraph, keeping Claude Desktop's `--startup` sentence, and delete the `### ChatGPT desktop app` subsection, which describes the repackaged `.deb`, its pin file, and the `chatgpt-release` bump.
  3. `docs/verification.md`: drop ChatGPT and its trailing "no argument" from the `desktop-autostart` description in the checks paragraph, so the app list and argument list still pair up. Drop ChatGPT from the login-autostart checklist item and delete the item that launches ChatGPT and checks `xprop`. Keep the `codex login` item.
  4. `docs/macos.md`: drop ChatGPT from the cask list.
- **Test scenarios:** Test expectation: none -- documentation only; the Markdown lint hook covers formatting.
- **Verification:** `grep -i chatgpt` over `README.md` and `docs/` matches only the Codex sign-in mention.

---

## Verification Contract

| Gate | Command | Applies to |
| --- | --- | --- |
| Formatting | `nix fmt -- --ci` | U1, U2, U3 |
| Flake evaluation | `nix flake check --no-build` | all units |
| Light checks touched | `nix build --no-link .#checks.x86_64-linux.desktop-autostart .#checks.x86_64-linux.darwin-config .#checks.x86_64-linux.check-shards-guard` where the builder supports them | U1, U2, U3 |
| Host outputs | evaluate every `nixosConfigurations`, `homeConfigurations`, `systemConfigs`, and `darwinConfigurations` output named in `AGENTS.md`; outputs this builder cannot build are left to CI | U1, U2 |
| Markdown lint | `mise run lint-staged-markdown` through the pre-commit hook | U4 |

A macOS session cannot build `checks.x86_64-linux` or NixOS outputs; there, evaluate them and leave the builds to CI's `check-shards`, `vm-checks`, and host jobs.

## Definition of Done

- Every requirement R1 through R5 holds, and the only `chatgpt` mentions left outside historical plans and the static-pie learning are the Codex sign-in references.
- The Verification Contract gates pass or are explicitly left to CI with the reason.
- No dead `let` bindings, unused imports, or half-removed blocks remain in the diff.
