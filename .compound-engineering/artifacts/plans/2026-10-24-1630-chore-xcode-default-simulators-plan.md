---
title: Xcode Default Simulators - Plan
type: chore
date: 2026-10-24
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Xcode Default Simulators - Plan

## Goal Capsule

- **Objective:** The user's iOS simulator list follows their Xcode choices without an extra iPhone being provisioned by default.
- **Means:** Narrow the default mobile-device declaration (KTD1).
- **Authority:** The Product Contract owns behavior; the Planning Contract owns implementation choices within it.
- **Execution profile:** One bounded configuration change with existing-check verification.
- **Stop conditions:** Stop if the work would require deleting existing devices or changing the Android default.
- **Completion and shipping:** The autonomous pipeline implements, reviews, and opens a PR; the user merges and applies it.

## Product Contract

### Summary

Leave iOS simulator provisioning to Xcode by default while retaining the repository's optional iOS declarations.

### Problem Frame

The default declaration creates a versioned iPhone 18 Pro simulator, adding a repository-selected device to the user's Xcode device list.

### Key Decisions

- **Preserve existing devices.** Governs R2. (session-settled: user-directed — chosen over deleting old or undeclared simulators: the user explicitly wants existing devices left in place.)
- **Use Xcode's iOS defaults.** Governs R1, R3. (session-settled: user-approved — chosen over maintaining a repository-selected iPhone and runtime: the user wants Xcode to manage iOS while Android provisioning stays available.)

### Requirements

- R1. A default macOS apply must not request iOS simulator creation or iOS runtime downloads through the mobile-devices helper.
- R2. Existing simulators and their data must remain untouched by this change.
- R3. The default Android device remains pixel_10_pro on the newest pinned API.
- R4. Explicit iOS entries in my.mobileDevices remain supported with their current behavior.
- R5. macOS provisioning and verification guidance must distinguish the default Android-only declaration from optional iOS provisioning.

## Planning Contract

### Key Technical Decisions

- KTD1. **Remove only the default iOS entry** in `home/h82/dev/mobile-devices.nix`. The helper already invokes its iOS branch only when iOS device arguments are present, satisfying R1 without changing its implementation.
- KTD2. **Update the existing default-contract assertion** in `tests/darwin-config.nix` to require zero iOS and one Android default. Retain explicit iOS helper coverage and the existing materialized-output checks; no new check is needed.
- KTD3. **Keep historical plans and solutions intact.** Update current operator guidance in `docs/macos.md` and `docs/verification.md`; no runtime cleanup or host activation is part of this change.

## Implementation Units

### U1. Make iOS provisioning opt-in

- **Goal:** Deliver R1-R5 through KTD1-KTD3.
- **Requirements:** R1, R2, R3, R4, R5.
- **Dependencies:** None.
- **Files:** `home/h82/dev/mobile-devices.nix`, `tests/darwin-config.nix`, `docs/macos.md`, `docs/verification.md`.
- **Approach:** Remove the iPhone entry from the default list, update the existing default assertion and its description, and revise default-oriented documentation and manual verification steps. Preserve the helper and its iOS tests.
- **Patterns to follow:** Existing platform-count assertion, device argument rendering, and macOS mobile-device documentation.
- **Execution note:** Prefer evaluating the actual default configuration and building the existing macOS fixture over adding unit-test machinery.
- **Test scenarios:** A production or fixture macOS configuration using defaults declares only the Android device. Existing explicit iOS helper scenarios continue to pass. The generated activation invocation contains no iOS device declaration under defaults.
- **Verification:** Existing default-contract checks and materialized macOS outputs pass, the mobile-devices helper suite remains green, and current docs no longer promise default iPhone creation or runtime downloads.

## Verification Contract

- Run `nix fmt -- --ci` and the staged Markdown lint check for changed documents.
- Run `nix flake check` and build `checks.aarch64-darwin.darwin-outputs` on the macOS builder. Exercise the Linux-only mobile-devices and darwin-config checks through the repository's documented Linux builder path or CI; do not claim evaluation alone built them.
- Enumerate and build production and bootstrap outputs under `nixosConfigurations`, `homeConfigurations`, `systemConfigs`, and `darwinConfigurations`, and build `vmChecks.all` where the required architecture and Linux KVM are available. Report platform limitations and rely on the corresponding CI jobs for unavailable builders.
- Inspect the generated default activation invocation for Android arguments and absence of iOS device declarations. Do not run `nr switch`, delete a simulator, or alter the developer host as validation.

## Definition of Done

R1-R5 are met, U1's verification is evidenced, relevant checks and platform limits are reported, and review findings are resolved. No abandoned experimental code, device cleanup, helper redesign, or unrelated changes remain in the diff.
