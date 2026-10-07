---
title: Darwin Homebrew autoMigrate Check - Plan
type: test
date: 2026-10-08
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Darwin Homebrew autoMigrate Check - Plan

## Goal Capsule

- **Objective:** CI fails any change to the shared macOS modules that builds nix-homebrew's setup script with `autoMigrate` off, which would make a Mac's first apply stop on an existing `/opt/homebrew` installation, before that change reaches a Mac.
- **Means:** one assertion in `tests/darwin-outputs.nix` that reads the materialized nix-homebrew setup script of each macOS fixture (KTD1, KTD2).
- **Authority:** this plan's Requirements, then its KTDs, then the units.
- **Stop conditions:** stop and report if the fixture systems do not reference a `setup-homebrew` script from their activation, or if the rendered guard in the pinned nix-homebrew no longer has the `if [[ -z "…" ]]` shape that KTD2 relies on.
- **Execution profile:** one small change to an existing check, verified on this aarch64-darwin Mac and by CI's `build-darwin` job.
- **Finishes and ships:** the change lands on `feat/macbook-pro-host` and merges with PR #176.

## Product Contract

### Summary

Add one per-fixture assertion to the `darwin-outputs` check. It confirms that the generated nix-homebrew setup script is built with `autoMigrate` on. The check's header comment lists the new assertion.

### Problem Frame

PR #176 sets `nix-homebrew.autoMigrate = true` in `modules/darwin/homebrew.nix` so a Mac that already has Homebrew at `/opt/homebrew` is taken over in place. Without that setting, nix-homebrew's activation prints migration instructions and exits 1, and the first `nr switch` on such a Mac stops. CI builds every macOS system on `macos-15`, but a build never runs activation. Removing the line or overriding it in a shared module would therefore pass every existing check and surface only on a real Mac.

### Requirements

- R1. `checks.aarch64-darwin.darwin-outputs` fails for a macOS fixture whose system's nix-homebrew setup script was generated with `autoMigrate` off.
- R2. The check also fails when the fixture's activation references no `setup-homebrew` script, or that script has no rendered migration guard, so a reshaped upstream module cannot make it pass vacuously.
- R3. The failure message names the fixture and variant, matching the check's existing `bad` reporting.

### Key Decisions

- **Static assertion only** (session-settled: user-approved — chosen over activating the configuration on a macOS runner and over relying on existing CI alone: activation is heavy and needs a secret-free configuration, and existing CI builds the host but never exercises autoMigrate). Governs R1.
- **Fixture hosts, not the real host** (session-settled: user-approved — chosen over checking `MacBook-Pro-Mac17-9` directly: `host-name-guard` forbids host names in `tests/`, and `autoMigrate` lives in the shared `modules/darwin/homebrew.nix` every macOS host imports). Governs R1.

### Scope Boundaries

- Activating any configuration on a CI runner is not built.
- The `build-darwin` job in `.github/workflows/check.yml` is unchanged; it already builds `checks.aarch64-darwin.darwin-outputs`.
- No option-value assertion is added to `tests/darwin-config.nix` (KTD1).
- Not covered: a per-host `nix-homebrew.autoMigrate` override in `hosts/<mac>/default.nix`, which never reaches a fixture, and nix-homebrew's other existing-installation failures, such as an unrecognized prefix layout or an occupied `bin/brew`.

#### Deferred to Follow-Up Work

- The `tests/lib/darwin-fixtures.nix` header still says the fixtures "stand in for the Mac that has not been bought". That comment is stale now that a real Mac host exists, but it is outside this change.

## Planning Contract

### Key Technical Decisions

- KTD1. **Assert on the materialized setup script in `darwin-outputs`, not on the option value** (session-settled: user-approved — chosen over an option-value assertion in `tests/darwin-config.nix`: an assertion on an unconditionally set option folds to a constant, and an option-value check misses the materialized output). Sources: `.compound-engineering/artifacts/solutions/best-practices/nix-check-assertion-on-unconditional-option-folds-to-a-constant.md`, `.compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md`.
- KTD2. **Match the rendered guard text exactly.** nix-homebrew renders `if [[ -z "${toString cfg.autoMigrate}" ]]; then` in its `setupPrefix` (pinned source `modules/default.nix:220`), so the script holds `if [[ -z "1" ]]` when on and `if [[ -z "" ]]` when off. The assertion requires the `"1"` form. The two states produce different text, so the fixture can tell the bug from the fix (`.compound-engineering/artifacts/solutions/best-practices/converged-fixture-state-defeats-nix-check-mutation-testing.md`).
- KTD3. **Resolve the script at build time, inside the builder.** Find the `/nix/store/…-setup-homebrew` path in `$sys/activate` with `grep`, the same way the existing Brewfile assertion finds its Brewfile. No nullable value is interpolated at evaluation time, so a mutation fails inside the builder with the check's own message instead of at evaluation (`.compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md`).

### Assumptions

- The setup-homebrew script is referenced from `$sys/activate` directly: nix-darwin splices `system.activationScripts.setup-homebrew.text`, which execs the script by store path (nix-homebrew `modules/default.nix:597-605`). If the reference sits one level deeper, U1 follows it rather than changing the requirement.

## Implementation Units

### U1. Assert autoMigrate in the darwin-outputs fixture check

- **Goal:** each macOS fixture variant fails the check unless its nix-homebrew setup script was generated with `autoMigrate` on.
- **Requirements:** R1, R2, R3. KTD1, KTD2, KTD3.
- **Dependencies:** none.
- **Files:** `tests/darwin-outputs.nix` (the check and its header comment).
- **Approach:**
  1. Next to the Brewfile assertion in `assertEntry`, extract the first `/nix/store/<hash>-setup-homebrew` path from `$sys/activate`.
  2. When none is found, call `bad` with a message saying the activation runs no nix-homebrew setup.
  3. Otherwise, call `bad` unless that script contains the literal guard `if [[ -z "1" ]]` (KTD2), with a message saying the setup script would stop on an existing Homebrew installation.
  4. Add one bullet to the header comment's list of what the check reads.
- **Patterns to follow:** the `brewfile=$(grep -o -m1 …)` block and the `bad` helper in `tests/darwin-outputs.nix`. Use a fixed-string match (`grep -F`) so the brackets and quotes are not regex syntax.
- **Execution note:** prove the assertion with mutations, reading where each run went red, per `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`.
- **Test scenarios:**
  - The unmodified tree builds `checks.aarch64-darwin.darwin-outputs` successfully for both fixture variants.
  - With `autoMigrate = true;` removed from `modules/darwin/homebrew.nix`, the build fails inside the builder, and the log carries the new message for both the production and bootstrap variants of the fixture.
  - With the assertion's expected guard changed to a string the script does not contain, the build fails with the same message, which shows the match is not vacuous.
  - With the `setup-homebrew` pattern changed to one that matches nothing, the build fails with the "runs no nix-homebrew setup" message (R2).
- **Verification:** the scenarios above hold, every mutation is reverted, and the failing runs show the check's own messages rather than evaluation errors.

## Verification Contract

| Gate | Command or evidence | Applies to |
| --- | --- | --- |
| Check builds on this Mac | `nix build --no-link .#checks.aarch64-darwin.darwin-outputs` | U1 |
| Mutation rounds | scratch copy made with `rsync -a --exclude .git` plus `git init`, never `cp -r` and never `cd` into it, per `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`; build with `nix build --no-link "path:$M#checks.aarch64-darwin.darwin-outputs"` | U1 |
| Formatting | `nix fmt -- --ci` | U1 |
| Flake evaluation and Linux-side guards | `nix flake check` (includes `host-name-guard` and `check-shards-guard`) | U1 |
| CI | `build-darwin (checks.aarch64-darwin.darwin-outputs)` passes on PR #176 | U1 |

## Definition of Done

- R1 through R3 hold, shown by the U1 test scenarios.
- Every mutation is reverted, the scratch copies are removed, and the real index carries only the intended change.
- The `darwin-outputs` header comment lists the new assertion.
- No abandoned-attempt code remains in the diff.
