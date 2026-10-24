---
title: Restore ChatGPT on NixOS and macOS
type: feat
date: 2026-10-24
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# Restore ChatGPT on NixOS and macOS

## Goal Capsule

- **Objective:** ChatGPT is available on the user's NixOS and macOS hosts without an unwanted window appearing at login.
- **Means:** Restore the existing package and cask integrations, validating startup support against the shipped app (KTD1, KTD2).
- **Authority:** The user's scope and silent-start decisions, repository instructions, then this plan.
- **Stop conditions:** An unavailable upstream package or a conflict with a settled decision that cannot be resolved within this scope.
- **Execution profile:** Packaging and configuration; prioritize package smoke checks and evaluated host outputs.
- **Finishes and ships:** The implementation workflow verifies locally; the LFG pipeline reviews, pushes, opens a PR, and waits for CI. The user merges.

## Product Contract

### Summary

Restore ChatGPT on NixOS and macOS. Enable login startup separately on each platform only when the app supports starting silently without opening its main window.

### Problem Frame

The October 17 removal deleted installation, release tracking, and checks. The user wants the app back, with the unobtrusive login behavior used by 1Password where supported.

### Key Decisions

- **NixOS and macOS coverage.** (session-settled: user-directed — chosen over including non-NixOS Linux: the user selected the previous platform coverage.) Governs R1, R2.
- **Silent startup only.** (session-settled: user-directed — chosen over unconditional window-opening login startup: the user requested automatic launch only when silent launch is supported.) Governs R3.

### Requirements

**Installation and updates**

- R1. NixOS hosts install the official ChatGPT Linux app through the existing pinned-package pattern; macOS hosts install the ChatGPT Homebrew cask.
- R2. Non-NixOS Linux remains unchanged. Preserve existing GUI installation in production and bootstrap outputs; exclude ChatGPT login startup from bootstrap environments.
- R3. On each supported platform, configure login startup only if the shipped app has a verified silent-start mechanism. Unsupported platforms use manual launch; do not simulate silence by opening and then hiding a window.
- R4. Restore automatic Linux release updates with the repository's existing release-helper and scheduled-update pattern.

**Evidence and documentation**

- R5. Verify package executables, desktop entry, host coverage, release resolution, and startup behavior at their owning boundaries. Keep sign-in manual and distinguish hardware/runtime verification from build evidence.
- R6. Update current installation and verification documentation to match the restored behavior; preserve historical plans.

### Acceptance Examples

- AE1. Given a platform with verified silent-start support, login starts ChatGPT without displaying its main window, and the user can open it normally afterward. Covers R3.
- AE2. Given a platform without verified silent-start support, installation provides normal manual launch and adds no ChatGPT login entry. Covers R3.

### Scope Boundaries

No non-NixOS desktop configuration, Codex CLI changes, credential provisioning, display-backend customization, or system activation on the developer's machine.

## Planning Contract

### Key Technical Decisions

- KTD1. Restore the implementation removed by commit `9aecc82` selectively, adapting it to the current flake and tests. Keep the existing static-pie preservation around autoPatchelf; smoke-test the bundled executables rather than relying on file presence. The prior implementation and the static-pie learning provide the direct pattern.
- KTD2. Inspect current Linux and macOS app startup code or authoritative app documentation before choosing startup wiring. The former NixOS entry expressly had no hidden-start argument. Do not restore that entry without new supporting evidence. Record the actual inspected version and result in verification documentation. Runtime confirmation is required before claiming a newly discovered mechanism is silent.
- KTD3. Resolve a fresh upstream Linux pin instead of reintroducing the removed version. Re-add the ChatGPT cask mapping and reuse the generic cask checks. Extend existing package and host checks without duplicating coverage.

### Research and Risks

The current APT index advertises amd64 ChatGPT `26.1021.22027`. The local macOS app bundles Electron resources. A bounded inspection found no `setLoginItemSettings`, `wasOpenedAtLogin`, `openAsHidden`, `wasOpenedAsHidden`, or `--startup` handling in its JavaScript; this is preliminary evidence, not a runtime claim.

Relevant sources: `packages/claude-desktop.nix`, `scripts/claude-desktop-release`, `modules/shared/darwin-apps.nix`, `tests/desktop-autostart.nix`, and `.compound-engineering/artifacts/solutions/integration-issues/autopatchelf-corrupts-static-pie-binaries-in-deb-packages.md`. See [official app settings documentation](https://learn.chatgpt.com/docs/app/settings).

## Implementation Units

### U1. Restore packaging and release tracking

- **Goal:** Supply a maintained ChatGPT package on NixOS and the cask on macOS.
- **Requirements:** R1, R2, R4, R5.
- **Dependencies:** None.
- **Files:** `packages/chatgpt.nix`, `packages/chatgpt-version.json`, `scripts/chatgpt-release`, `packages/agent-tools.nix`, `flake.nix`, `home/h82/default.nix`, `modules/shared/darwin-apps.nix`, `.github/workflows/update-dependencies.yml`, `tests/test_chatgpt_release.py`, `tests/non-nixos-outputs.nix`, `tests/check-shards.nix`.
- **Approach:** Reuse the removed package and resolver, update the pin, reconnect exports and the update workflow, and extend the existing host/package checks. Inspect restored tests against the test-audit rules before retaining them.
- **Test scenarios:** Offline resolver chooses the newest valid amd64 candidate and does not downgrade; package smoke checks run bundled CLI binaries and verify the desktop launcher; evaluated production and bootstrap NixOS/macOS outputs include ChatGPT, while non-NixOS Linux outputs exclude it.
- **Verification:** Formatting, resolver tests, flake checks, and supported-platform builds succeed; cross-platform build limits are explicit.

### U2. Verify startup support and document the result

- **Goal:** Honor the user's conditional silent-start request.
- **Requirements:** R3, R5, R6.
- **Dependencies:** U1.
- **Files:** `home/h82/desktop/kde/autostart.nix` and macOS startup configuration only if supported; `tests/desktop-autostart.nix` and relevant Darwin checks if startup configuration changes; `README.md`, `docs/provisioning.md`, `docs/verification.md`, `docs/macos.md`.
- **Approach:** Inspect the pinned Linux app and current macOS app. Add only supported and runtime-verified silent startup; otherwise document manual launch and the inspected evidence. Update installation and update documentation.
- **Test scenarios:** Covers AE1 if a supported mechanism is found; otherwise covers AE2 through evaluated absence of ChatGPT startup entries. Normal launch remains available from the desktop launcher.
- **Verification:** Record versions and evidence. Do not claim live Linux desktop or login behavior from static inspection or macOS builds.

## Verification Contract

Run `nix fmt -- --ci`, offline resolver tests, `nix flake check`, and the targeted package and host checks. Enumerate every production/bootstrap output and attempt the repository-required builds, including `vmChecks.all`; platform-incompatible builds require CI evidence on the appropriate runner. On macOS, use the repository's documented Linux builder path if available. Never run `nr switch` or `nixos-rebuild switch` for validation. Check the current PR head's CI before declaring readiness.

## Definition of Done

U1 and U2 meet R1 through R6, startup claims match observed evidence, all applicable checks pass, and any platform limitations are reported. Remove abandoned experiments. The final PR describes changes, applied review findings, and verification; no merge is performed.
