---
title: Remove Claude Code from GitHub Actions - Plan
type: chore
date: 2026-10-05
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Remove Claude Code from GitHub Actions - Plan

## Goal Capsule

- **Objective:** No GitHub Actions run in this repository invokes Claude Code or reads `CLAUDE_CODE_OAUTH_TOKEN`, while the dependency updater, `check.yml`, and the repository's own checks keep working and the docs no longer describe Claude CI behavior as current.
- **Means:** Delete the two Claude workflows and the reconcile step, together with the checks and docs that assume them (KTD1, KTD2).
- **Authority:** R-IDs win on behavior, KTDs on mechanism. The user scoped the work to GitHub Actions; the machine configuration stays untouched (Key Decisions).
- **Stop conditions:** Stop if removing a workflow file breaks a check other than `github-workflow-conventions` in a way this plan does not name, or if any workflow other than the three named here references `claude-code-action`.
- **Execution profile:** Config and docs change with one shell test edit. Verify with `nix flake check` and mutation of the edited test.
- **Finishes and ships:** `ce-work` implements; the LFG pipeline reviews, commits, and opens the PR.

---

## Product Contract

### Summary

Delete `.github/workflows/claude.yml` and `.github/workflows/claude-code-review.yml`. Remove the "Reconcile breakages with Claude Code" step from `.github/workflows/update-dependencies.yml`, so a failed update still opens or refreshes the reconciliation PR for a person to fix. Remove the `github-workflow-conventions` check, which only inspects the two deleted files. Update `tests/update-dependencies-reconcile.sh`, `AGENTS.md`, `CONCEPTS.md`, `docs/verification.md`, and `docs/provisioning.md` to match.

### Problem Frame

The user no longer wants Claude Code running in this repository's CI. Three places run it today: the `@claude` mention agent, the automatic PR review, and the updater's reconcile step. Repository checks and the PR-readiness rules in `AGENTS.md` and `CONCEPTS.md` are written around those workflows, so deleting the files alone would break `nix flake check` at evaluation and leave instructions that describe a reviewer that no longer exists.

### Key Decisions

- **Scope is GitHub Actions only.** (session-settled: user-directed — chosen over removing Claude Code from the Home Manager/NixOS configuration and the `claude-code`/`claude-desktop` package updaters: the user clarified the request means GitHub Actions.) Governs R1, R7.

### Requirements

**Workflows**

- R1. No file under `.github/workflows/` references `anthropics/claude-code-action`, `CLAUDE_CODE_OAUTH_TOKEN`, `@claude`, or `claude[bot]`.
- R2. When an update fails verification and no reconciliation PR is open, the updater still pushes `update-dependencies-fix` and opens the PR; when one is open, it still leaves the branch alone and refreshes the PR body.
- R3. The reconciliation PR body tells the reader to push a fix and merge by hand, and no longer promises a Claude dispatch.
- R4. `update-dependencies.yml` requests only the token permissions its remaining steps use.

**Checks**

- R5. `nix flake check` evaluates and passes with the workflows gone, and every remaining assertion in `tests/update-dependencies-reconcile.sh` still guards the behavior it names.

**Docs**

- R7. `AGENTS.md`, `CONCEPTS.md`, `docs/verification.md`, and `docs/provisioning.md` no longer describe Claude CI workflows, the CI agent, or a review check as current, and the PR-readiness rule stays satisfiable for docs-only PRs whose `check.yml` jobs skip by design.

### Scope Boundaries

- Claude Code on the machines (`home/h82/agents/claude.nix`, `packages/claude-code*`, `packages/claude-desktop*`) and the updater steps that bump those packages stay as they are (Key Decisions).
- Historical plans and solutions under `.compound-engineering/artifacts/` keep citing the deleted workflows; they record what was true when written.
- Considered and not built: a new failure signal for the reconciliation PR, such as assigning the owner or failing the run after opening the PR. `check.yml` runs on the PR because it is opened with `GH_TOKEN_FOR_UPDATES`, and its red run is the signal; add one if failed updates are found sitting unnoticed.
- Considered and not built: a guard against reintroducing Claude Code, either a replacement for `github-workflow-conventions` or a `claude-code-action` assertion in the updater test. Reintroducing it would be a deliberate, reviewed edit, and adding such a guard later is a cheap test change.
- Outside the repository: delete the `CLAUDE_CODE_OAUTH_TOKEN` secret and, if unused elsewhere, uninstall the Claude GitHub App. The PR body lists these for the owner.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Delete `github-workflow-conventions` rather than retarget it.** Every assertion in `tests/github-workflow-conventions.sh` concerns the two Claude workflows (SHA-pin version comments, concurrency keyed on issue or PR number, the `claude[bot]` exclusion, the owner gate, commit signing, the tool allowlist). `check.yml` and `update-dependencies.yml` would fail it, since their `cachix/install-nix-action` pin has no version comment and their concurrency is not keyed on an issue or PR. The flake attribute interpolates both workflow paths, so the files, the attribute, the script, and its `docs/verification.md` sentence go in one commit (`flake.nix` `github-workflow-conventions`).
- KTD2. **Drop the PR step's `reconcile` output and `id: pr`.** The reconcile step is its only reader. Drop the top-level `id-token: write` and `actions: read` too; only the Claude step and the deleted workflows used them, and `gh pr list|edit|create` needs only `pull-requests: write`.
- KTD3. **Keep `--settle-seconds 0` with a new reason.** No automated reviewer remains, so CI (`check.yml`) is the only pull-request signal and it reports as checks. The current-head, per-workflow evidence rule stays. The "review check merely skipped" clauses and the hand-back sentence go, because they would only ever match a skipped `check.yml` job, which is a designed skip, not missing evidence.
- KTD4. **Delete the `AGENTS.md` paragraph "After an agent pushes to a pull request branch from CI".** Its subject was the CI agent in `claude.yml`, which no longer exists.
- KTD5. **New PR-body line:** "Push a fix to this branch; CI runs on each push. This PR waits for you to review and merge it." It avoids "hourly" and "merged automatically", which the test rejects.

### Assumptions

- `GH_TOKEN_FOR_UPDATES` stays configured, so the reconciliation PR triggers `check.yml`. The rewritten test header states that `GITHUB_TOKEN` fallback triggers no CI.
- No other workflow or check reads the deleted files; repo research found only `flake.nix` `github-workflow-conventions`.

### Sources

- `.compound-engineering/artifacts/solutions/best-practices/merge-ready-wake-fires-on-zero-check-evidence.md` is where the "every reviewer reports as a check" premise came from.
- `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md` and `.compound-engineering/artifacts/solutions/logic-errors/printf-pipe-grep-q-under-pipefail-reports-a-miss.md` govern the edited test: feed `grep` from a here-string, and mutation-test each kept assertion.

---

## Implementation Units

### U1. Remove the Claude workflows and their conventions check

- **Goal:** The two Claude workflows and the check that only inspects them are gone, and `nix flake check` still evaluates.
- **Requirements:** R1, R5, R7
- **Dependencies:** none
- **Files:**
  - Delete `.github/workflows/claude.yml`
  - Delete `.github/workflows/claude-code-review.yml`
  - Delete `tests/github-workflow-conventions.sh`
  - Modify `flake.nix` (remove the `github-workflow-conventions` attribute)
  - Modify `docs/verification.md` (remove the `github-workflow-conventions` sentence)
- **Approach:** Per KTD1, land all five changes together. `tests/check-shards.nix` derives its sets automatically; confirm `check-shards-guard` still passes rather than editing shards.
- **Test expectation:** none -- removal only; `nix flake check` evaluating and `check-shards-guard` passing prove it.
- **Verification:** `nix flake check` passes; `grep -rn github-workflow-conventions` outside `.compound-engineering/` finds nothing.

### U2. Remove the reconcile step from the updater

- **Goal:** A failed update opens or refreshes the reconciliation PR and dispatches nothing.
- **Requirements:** R1, R2, R3, R4
- **Dependencies:** none
- **Files:**
  - Modify `.github/workflows/update-dependencies.yml`
  - Modify `tests/update-dependencies-reconcile.sh`
- **Approach:**
  1. In the workflow, delete the "Reconcile breakages with Claude Code" step, the PR step's `reconcile=` output lines and `id: pr` (KTD2), and the `id-token`/`actions` permissions.
  2. Replace the PR-body line with the KTD5 text, and reword the comment that says the branch "may carry fix commits from Claude or a person" to name a person only.
  3. In the test, drop every `reconcile` read and assertion, the Claude-step block, and the Claude step from the `if:` loop. Rewrite the header to describe what remains, including that the PR triggers CI only because it is opened with `GH_TOKEN_FOR_UPDATES`.
  4. Extend the existing PR-body assertion so the created body must not mention Claude (R3).
- **Execution note:** Mutation-test inside the builder, per the mutation-testing learning: each mutation must fail with the check's own message, not at evaluation.
- **Patterns to follow:** existing `fail`/`pass` helpers and the here-string `grep` form already used in the test.
- **Test scenarios:**
  - With no open PR, the PR step pushes `update-dependencies-fix`, runs `gh pr create`, and exits 0.
  - The created PR body contains neither "hourly", "merged automatically", nor "Claude".
  - With a PR already open, the step keeps the fix commit at the branch head, runs `gh pr edit`, and the body carries the new logs.
  - With the open-PR query failing, the step exits non-zero and runs neither `gh pr create` nor `gh pr edit`.
  - The PR step's `if:` requires both a changed update and a failed verification.
  - Adding `gh pr merge` to any step makes the test fail.
- **Verification:** `nix build --no-link` of the `update-dependencies-reconcile` check passes, and each mutation above fails it in the builder.

### U3. Update agent instructions, glossary, and docs

- **Goal:** No instruction or doc presents Claude CI behavior as current, and the readiness rule works for docs-only PRs.
- **Requirements:** R7
- **Dependencies:** U1, U2
- **Files:**
  - Modify `AGENTS.md`
  - Modify `CONCEPTS.md`
  - Modify `docs/provisioning.md`
- **Approach:**
  1. `AGENTS.md`: rewrite the PR-watching paragraph per KTD3 and delete the CI-agent paragraph per KTD4.
  2. `CONCEPTS.md` "Check evidence": keep the first paragraph. Rewrite the second so it no longer speaks of a reviewer, and states that jobs a finished run skips by design are part of that run's result.
  3. `docs/provisioning.md`: delete the last sentence of the Claude settings paragraph, which points at the allowlist in `.github/workflows/claude.yml`.
- **Test expectation:** none -- documentation only.
- **Verification:** `grep -rn 'claude.yml\|claude-code-review\|claude-code-action\|@claude'` outside `.compound-engineering/` finds nothing; `nix fmt -- --ci` and the markdown lint pass.

---

## Verification Contract

| Gate | Command | Proves |
| --- | --- | --- |
| Format | `nix fmt -- --ci` | Nix layout unchanged by edits |
| Checks | `nix flake check` | Evaluation survives the deletions; `update-dependencies-reconcile` and `check-shards-guard` pass |
| Reconcile mutations | build the `update-dependencies-reconcile` check with each U2 mutation applied in a scratch copy | Kept and new assertions fail in the builder |
| Reference sweep | `grep -rnI 'claude-code-action\|CLAUDE_CODE_OAUTH_TOKEN\|@claude\|claude\[bot\]' .github` | R1 |

VM tests and host builds are unaffected: no NixOS, Home Manager, or system-manager module changes.

## Definition of Done

- U1-U3 verification outcomes hold and every gate above passes.
- No mutation scratch copy or leftover edit remains in the diff.
- The PR body lists the manual secret and GitHub App cleanup.
