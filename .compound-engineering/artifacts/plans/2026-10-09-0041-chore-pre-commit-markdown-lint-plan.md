---
title: Pre-commit Markdown Lint Managed by mise - Plan
type: chore
date: 2026-10-09
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Pre-commit Markdown Lint Managed by mise - Plan

## Goal Capsule

- **Objective:** A Markdown lint error that CI's `markdown-lint` check would reject is caught when the author commits, on any checkout including macOS, instead of after a push and a shard run.
- **Means:** a tracked pre-commit hook, enabled by the T3 Code `Setup` script, runs a mise task that lints the staged Markdown with the mise-pinned `markdownlint-cli2` (KTD1, KTD2, KTD3).
- **Authority:** GitHub issue #184 owns the product scope; this plan's Requirements and KTDs own the mechanism.
- **Stop conditions:** stop and report if `npm:markdownlint-cli2` 0.23.3 cannot be pinned in `mise.lock`, or if the hook cannot run from a linked worktree.
- **Execution profile:** small change to config, one shell script, one hook, one flake check, and docs; verify by the flake check plus a manual commit in a linked worktree.
- **Finishing:** `ce-work` implements and verifies; the calling pipeline reviews, commits, and opens the PR.

---

## Product Contract

### Summary

Add `markdownlint-cli2` 0.23.3 to `mise.toml`, add a mise task that lints only the staged Markdown files with the repository's `.markdownlint-cli2.jsonc`, and run that task from a tracked `.githooks/pre-commit` hook that the T3 Code `Setup` script enables. `AGENTS.md` documents the hook and how to skip it.

### Problem Frame

The `markdown-lint` flake check is the only Markdown lint, and it builds only on Linux. On a macOS checkout it never runs locally, so an error surfaces only after a push and a roughly ten-minute `check-shards (light-*)` run. On #183 a new plan file failed CI with 25 MD060 and MD032 errors that `markdownlint-cli2 --fix` would have fixed before the commit.

### Requirements

**Lint behavior**

- R1. A commit whose staged Markdown under the configured globs (`docs/**/*.md`, root `*.md`, `.compound-engineering/artifacts/**/*.md`) has a lint error fails, and the output names the file, line, and rule.
- R2. A commit with clean staged Markdown, or with no staged Markdown, succeeds without noticeable delay.
- R3. For the same file content, the hook reports the same issues as the CI `markdown-lint` check: same tool version, same `.markdownlint-cli2.jsonc`, same glob scope.
- R4. The hook only reports; it does not modify or re-stage files.

**Installation**

- R5. A new T3 Code worktree has the hook enabled after its `Setup` script runs, and re-running `Setup` leaves exactly one working hook.
- R6. The hook works in a linked worktree, where `.git` is a file and repository config is shared through the common git directory.

**Documentation**

- R7. `AGENTS.md` (Build and development commands) describes the hook, how to enable it outside T3 Code, and how to skip it for one commit.

### Key Decisions

- **markdownlint-cli2 comes from mise, pinned to the nixpkgs version.** (session-settled: user-directed — chosen over a floating `latest` version or a Nix-only tool: local and CI results must agree.) Governs R3.
- **T3 Code's `Setup` script installs the hook.** (session-settled: user-directed — chosen over a manual per-developer install: every new T3 worktree gets the hook.) Governs R5.
- **`.markdownlint-cli2.jsonc` stays unchanged.** (session-settled: user-directed — chosen over a separate local config: the hook uses the same rules as CI.) Governs R3.

### Scope Boundaries

- Considered and not built: auto-fixing with `--fix` and re-staging. It rewrites files the author may have staged only in part, and a silent re-stage can commit hunks the author left out. Revisit if report-only proves too slow in practice. Governs R4.
- Considered and not built: a fallback when `mise` is missing from the hook's `PATH`. The hook fails with git's own "command not found" message, which names the cause, and `--no-verify` skips it.
- Not in scope: linting Markdown outside the three globs, or changing CI.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Enable a tracked `.githooks/` directory with `core.hooksPath`, not `mise generate git-pre-commit --write`.** `Setup` runs `git config core.hooksPath .githooks`. Git resolves a relative `core.hooksPath` from the root of the working tree that runs the hook, so each worktree runs the hook its own branch carries, and a branch without `.githooks/` simply has no hook. `mise generate git-pre-commit --write` writes one script into the common git directory, so every worktree of the repository runs it. Each commit then calls `mise run pre-commit`, and that fails on any branch whose `mise.toml` predates the task, such as an existing worktree on an older feature branch. Its generated `STAGED` variable also space-joins paths and reads `HEAD`, which breaks on paths with spaces and on an unborn branch. Re-running `git config` with the same value is idempotent (R5). Implements the T3 `Setup` Key Decision, Governs R5, R6.
- KTD2. **Lint the index content in a scratch tree with the config's own globs.** The task lists staged paths ending in `.md` (`git diff --cached --name-only -z --diff-filter=ACMR`) and exits 0 at once when there are none. Otherwise it copies those blobs plus the staged `.markdownlint-cli2.jsonc` from the index into a temporary directory with `git checkout-index --prefix`, then runs bare `markdownlint-cli2` there. Bare invocation applies the config's `globs` exactly as CI does, so staged Markdown outside the globs is ignored without a second copy of the glob list. Reported paths are repo-relative because the scratch tree mirrors the repository layout. Linting the index, not the working tree, keeps a partially staged file's result tied to what is committed. Passing file paths on the command line was rejected: `markdownlint-cli2 <file>` adds the config globs and lints the whole tree, and `--no-globs <file>` lints files CI never checks, such as `secrets/README.md`. Governs R1, R2, R3.
- KTD3. **Keep the logic in `scripts/lint-staged-markdown`, called by a mise task and a thin hook.** `mise.toml` declares task `lint-staged-markdown` with `run = "scripts/lint-staged-markdown"`, so `markdownlint-cli2` comes from the mise-managed tool on `PATH`. `.githooks/pre-commit` only `exec`s `mise run lint-staged-markdown`. A standalone script follows the `scripts/` convention, and a flake check can test it with nixpkgs' `markdownlint-cli2` and no mise. Implements the mise Key Decision, Governs R3.
- KTD4. **Pin `npm:markdownlint-cli2` at `0.23.3`, record it in `mise.lock`, and fail a flake check when the pin and nixpkgs differ.** It mirrors the existing `npm:@sentry/dotagents` entry. The npm backend already depends on the system Node that dotagents uses, so no new runtime enters `mise.toml`. `flake.lock` is bumped routinely, so a one-time match would drift silently. The `lint-staged-markdown` check compares the `mise.toml` pin and the `mise.lock` version against `pkgs.markdownlint-cli2.version`, which turns the flake update PR that moves the tool red until the pin follows. Governs R3.
- KTD5. **Also enable the hook in `orca.yaml`'s setup.** `orca.yaml` runs the same `mise trust` and `mise install` as `t3.json`. `core.hooksPath` lives in the shared repository config, so either setup enables it for every worktree, and keeping both setups equal avoids depending on which tool ran first.

### Assumptions

- Hosts that commit to this repository have `mise` and Node on `PATH`, as Home Manager provides today.
- No other tool in this repository relies on hooks under the common `.git/hooks/`, which `core.hooksPath` disables; that directory holds only Git's samples today.

---

## Implementation Units

### U1. Staged Markdown lint script and mise task

- **Goal:** lint the staged in-scope Markdown with the pinned tool and the CI config.
- **Requirements:** R1, R2, R3, R4 (KTD2, KTD3, KTD4)
- **Dependencies:** none
- **Files:**
  - `scripts/lint-staged-markdown` (create)
  - `mise.toml` (modify: tool and task)
  - `mise.lock` (modify: generated by mise)
  - `tests/lint-staged-markdown.sh` (create)
  - `flake.nix` (modify: register check `lint-staged-markdown`)
- **Approach:**
  1. Write the script as `#!/usr/bin/env bash` with `set -euo pipefail` and a header comment stating behavior and exit codes, like `scripts/ci-docs-only-paths`.
  2. Run from the repository top level (`git rev-parse --show-toplevel`), collect staged `.md` paths NUL-separated, and exit 0 when the list is empty.
  3. Check the paths and the config out of the index into a `mktemp -d` directory removed by an `EXIT` trap, run `markdownlint-cli2` with no arguments inside it, and exit with its status.
  4. On failure, print one line saying how to fix only the reported file (`mise exec -- markdownlint-cli2 --no-globs --fix <file>`; without `--no-globs` the config globs are added and every in-scope file is rewritten) and how to skip (`git commit --no-verify`).
  5. Add the tool and task to `mise.toml`, then let mise write the lock entry.
  6. Register the check in `flake.nix` beside `ci-docs-only-paths`, using `pkgs.markdownlint-cli2`, `pkgs.git`, and `pkgs.bash`. Shards pick it up automatically.
  7. In the same check, fail with a message naming both versions when the `npm:markdownlint-cli2` version in `mise.toml` or `mise.lock` differs from `pkgs.markdownlint-cli2.version` (KTD4).
- **Patterns to follow:** `scripts/ci-docs-only-paths` with `tests/ci-docs-only-paths.sh` and its `flake.nix` check; the `markdown-lint` check for how `markdownlint-cli2` runs.
- **Test scenarios** (each in a fresh temporary git repository holding a copy of `.markdownlint-cli2.jsonc`):
  - Staged `docs/bad.md` with a list missing its surrounding blank line exits non-zero, and the output contains `docs/bad.md`, a line number, and `MD032`.
  - Staged clean `docs/ok.md` exits 0.
  - A commit staging only `flake.nix` exits 0 without running `markdownlint-cli2`; a stub `markdownlint-cli2` that fails when called proves it.
  - Staged `secrets/bad.md` with a lint error exits 0, since it is outside the globs.
  - Staged root `README.md` with an error and staged `.compound-engineering/artifacts/plans/bad.md` with an error each exit non-zero.
  - The index holds a bad `docs/x.md` and the working tree a fixed copy: exits non-zero.
  - The index holds a clean `docs/x.md` and the working tree a broken copy: exits 0.
  - A staged deletion of a Markdown file exits 0.
  - A staged Markdown path containing a space is linted.
  - In a repository with no commits yet, a staged bad `docs/bad.md` still fails.
  - After a failing run on a staged `docs/bad.md` with a fixable MD032 error, the index blob and the working-tree file are byte-identical to before the run (R4).
  - The version-parity assertion fails when given a `mise.lock` version other than `pkgs.markdownlint-cli2.version`, and passes when they match.
- **Verification:** `nix build .#checks.<system>.lint-staged-markdown` passes; on the developer's Mac, `mise run lint-staged-markdown` with a staged broken file under `docs/` fails and names it.

### U2. Tracked hook, setup wiring, and docs

- **Goal:** every T3 Code or Orca worktree runs the U1 task on commit.
- **Requirements:** R5, R6, R7 (KTD1, KTD5)
- **Dependencies:** U1
- **Files:**
  - `.githooks/pre-commit` (create, executable)
  - `t3.json` (modify: `Setup` command)
  - `orca.yaml` (modify: `setup` script)
  - `AGENTS.md` (modify: Build and development commands)
  - `tests/lint-staged-markdown.sh` (extend)
- **Approach:**
  1. Write the hook as a POSIX `sh` script that `exec`s `mise run lint-staged-markdown`.
  2. Append `git config core.hooksPath .githooks` to the `Setup` command in `t3.json` and to `orca.yaml`'s setup.
  3. In `AGENTS.md`, add a bullet that names the hook, says `Setup` enables it, gives the manual `git config core.hooksPath .githooks` for other checkouts, and gives `git commit --no-verify` to skip it once.
- **Test scenarios** (extend the U1 test file; a stub `mise` on `PATH` runs the script for `mise run lint-staged-markdown`):
  - With `core.hooksPath=.githooks` set in the main repository, `git commit` from a linked worktree with a staged bad `docs/bad.md` fails and prints the rule; with a clean file it succeeds.
  - A linked worktree on a branch without `.githooks/` commits successfully, showing that a branch without the hook is unaffected.
  - Running the `git config` step twice leaves a single `core.hooksPath` value.
- **Verification:** the flake check passes; in a new linked worktree of this repository, after running the `Setup` command, a commit with a broken `docs/` file fails and `git commit --no-verify` succeeds; `markdownlint-cli2` passes on the edited `AGENTS.md`.

---

## Verification Contract

| Gate | Command | Applies to |
| --- | --- | --- |
| Formatting | `nix fmt -- --ci` | U1 (`flake.nix`) |
| Flake checks evaluate | `nix flake check --no-build` | U1, U2 |
| New check builds | `nix build --no-link .#checks.x86_64-linux.lint-staged-markdown` (on Linux or a Linux builder) | U1, U2 |
| Markdown lint | `mise exec -- markdownlint-cli2` from the repository root | U2 (`AGENTS.md`, this plan) |
| Lock pin | `mise.lock` holds `npm:markdownlint-cli2` at `0.23.3` | U1 |
| Manual linked-worktree commit | a broken `docs/` file blocks a commit; `--no-verify` bypasses it | U2 |

Off a Linux builder, the flake check build runs in CI's `check-shards` jobs; report it as CI evidence rather than local evidence.

---

## Definition of Done

- R1 through R7 hold, each proven by a U1 or U2 test scenario or the manual verification.
- `markdownlint-cli2` 0.23.3 is pinned in `mise.lock`, and the `lint-staged-markdown` check fails whenever that pin differs from the nixpkgs version the `markdown-lint` check uses.
- The new check is registered in `flake.nix`, and `check-shards-guard` passes.
- No abandoned-attempt code, stray hook files under the common `.git/hooks/`, or temporary repositories remain.
