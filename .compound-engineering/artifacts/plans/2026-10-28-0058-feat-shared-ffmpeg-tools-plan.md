---
title: Shared FFmpeg Tools - Plan
type: feat
date: 2026-10-28
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Shared FFmpeg Tools - Plan

## Summary

Install FFmpeg through the shared Home Manager utilities module so every host's managed user gets `ffmpeg` and `ffprobe`.

## Problem Frame

The shared command-line tools do not currently declare FFmpeg. Media conversion and inspection should be available consistently across hosts.

## Goal Capsule

**Objective:** Make both commands available on every supported host kind, including bootstrap generations.
**Means:** Extend the existing shared utilities package list.
**Authority:** The user's request and repository instructions govern this plan.
**Stop conditions:** Report unsupported package platforms or failed verification; do not activate a host as validation.

## Product Contract

### Requirements

- R1. The managed user environment provides working `ffmpeg` and `ffprobe` commands on NixOS, non-NixOS Linux, and macOS.
- R2. Production and bootstrap configurations receive the same tools.

## Planning Contract

### Key Technical Decisions

- KTD1. Add the pinned nixpkgs `ffmpeg` package to `home/h82/shell/utilities.nix` without a host-kind or bootstrap condition. All three host assemblies import this Home Manager profile.
- KTD2. Verify the package's binaries and evaluated host coverage directly. This is a declarative package addition with no custom runtime logic; a new package inventory test would duplicate the declaration.

## Implementation Units

### U1. Install the shared media tools

- **Goal:** Satisfy R1 and R2 through KTD1.
- **Dependencies:** None.
- **Files:** `home/h82/shell/utilities.nix`.
- **Approach:** Follow the existing unconditional package entries and retain their alphabetical order.
- **Execution note:** Prefer package/runtime smoke verification for this configuration change.
- **Test expectation:** No new test; verify the packaged commands and host configuration coverage directly under KTD2.
- **Verification:** Generate a short media sample with `ffmpeg`, inspect it with `ffprobe`, and confirm the expected stream metadata. Confirm the package is present in production/bootstrap environments and supported fixture host kinds.

## Verification Contract

- Run `git diff --check` and lint the new Markdown plan.
- Evaluate the flake and package membership for production/bootstrap hosts and Linux/macOS fixtures.
- Build the selected package on the local platform and run the U1 smoke scenario.
- Obtain successful current-head CI, all declared checks, VM tests, and every production/bootstrap host output before declaring the pull request ready. Use supported CI builders for Linux and ARM outputs; distinguish pending evidence from passes.
- Run `nix fmt -- --ci` on a platform with a flake formatter; the current Darwin platform leaves this to Linux CI.
- Do not run `nr switch` or another host activation as validation.

## Definition of Done

U1 is implemented, both commands pass the smoke check, host coverage is verified, and required platform evidence passes. The change is reviewed and published in an open pull request; merging remains with the user.
