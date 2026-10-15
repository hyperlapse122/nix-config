---
title: Mise Trust for Temporary Hook Copies - Plan
type: fix
date: 2026-10-15
topic: mise-trust-temp-hook-copy
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Mise Trust for Temporary Hook Copies - Plan

## Goal Capsule

- **Objective:** A commit that stages Markdown in this repository runs the lint and reports its result with no manual step, and an agent in any project whose commit hook trips over an untrusted temporary `mise.toml` retries the commit correctly instead of skipping the hook or trusting a throwaway directory.
- **Means:** Trust the hook's scratch copy for its one `markdownlint-cli2` call (KTD1), and add a `# Commit hooks` section to the shared agent instructions, pinned by the `agent-instructions` check (KTD2, KTD4).
- **Product authority:** GitHub issues #218 and #219.
- **Open blockers:** None.
- **Stop conditions:** Stop and report when the fix would need a `mise trust` entry, a change to `mise.toml`, or a weaker lint.
- **Execution profile:** One script fix, one learning update, and one instruction-and-check change, implemented by `ce-work` and shipped through `lfg` in one pull request.

## Product Contract

### Summary

`scripts/lint-staged-markdown` sets `MISE_TRUSTED_CONFIG_PATHS` to the resolved path of its own scratch copy for the one command that lints it. The learning that records the trap describes the fixed hook. The shared agent instructions gain a rule for the same failure in other projects' hooks, and the `agent-instructions` check pins every sentence of it.

### Problem Frame

The hook checks the index out into `mktemp -d` and runs `markdownlint-cli2` there. That binary is a mise shim, and mise refuses the copy's `mise.toml` because no one trusted the new path. Every Markdown commit fails before linting, and the learning's workaround has to be typed by hand on each commit. Agents in other repositories hit the same error with no instruction for it, and fall back to `--no-verify` or `mise trust` on the throwaway directory.

### Requirements

- **R1.** The hook runs `markdownlint-cli2` in its scratch copy with `MISE_TRUSTED_CONFIG_PATHS` set to that copy's resolved (`pwd -P`) path, scoped to that one command (#218).
- **R2.** The hook never runs `mise trust` and writes no trust entry.
- **R3.** A staged Markdown file with a lint error still fails the commit, and every existing `lint-staged-markdown` scenario still holds.
- **R4.** The learning `copied-git-worktree-writes-the-real-index.md` describes the fixed hook and keeps the manual variable only for other scripts that copy a checkout.
- **R5.** The shared instructions carry a rule for a commit whose hook failed on an untrusted temporary `mise.toml` (#219):
  - retry that one commit with `MISE_TRUSTED_CONFIG_PATHS` set to the resolved temporary root, resolved with `pwd -P` (KTD3);
  - report, rather than retry again, when the retry fails the same way;
  - never `mise trust` a temporary directory, and never `--no-verify`;
  - report instead when the untrusted file is the checkout's own `mise.toml`.
- **R6.** The rendered Claude Code, Codex, and Antigravity instruction files carry the rule, and the `agent-instructions` check fails when any of its sentences is deleted, reworded, negated, contradicted by an added sentence, reordered, or moved out of its section.

### Scope Boundaries

- No change to `mise.toml`, `.githooks/pre-commit`, or the lint configuration.
- Not built: exporting the variable for the rest of the script. Only the shim call needs it, and a wider scope would trust the copy for anything else the script later runs.

## Planning Contract

### Key Technical Decisions

- **KTD1. Set the variable inside the subshell, after `cd`.** The command becomes, in shape, `(cd "$tmpdir" && MISE_TRUSTED_CONFIG_PATHS="$(pwd -P)" markdownlint-cli2)`. `pwd -P` after `cd` resolves the macOS `/var` to `/private/var` link, which mise compares against. An environment assignment prefixed to `cd` would never reach the next command (see `.compound-engineering/artifacts/solutions/logic-errors/env-assignment-prefix-on-cd-never-reaches-the-next-command.md`).
- **KTD2. A new top-level `# Commit hooks` section after `# Branch names`.** The template has no Git section; `# Branch names` is the nearest Git guidance. A section of its own lets the check pin it whole, the way `# GPG and encryption` and `# Pull and merge requests` are pinned: `requireSentences`, `onlyPinnedSentences` with pattern `.`, `sentencesInSection`, and `sentencesInOrder`.
- **KTD3. The agent rule trusts the temporary root, not one directory.** A retried commit runs the hook again, and the hook makes a new directory, so the directory named in the first error is already gone. The rule therefore trusts the directory that holds it, which is usually the resolved `$TMPDIR`, for that one commit only (R5). The cost is that any `mise.toml` under that root is trusted for the commit's mise calls; it lasts one command and writes no trust entry, which #219 accepts. A retry that fails the same way is reported, not retried again.
- **KTD4. The section text.** Directional, final wording settles in `ce-work`, but no code span in a sentence may hold a full stop followed by a space, because the check's splitter breaks sentences there:

  ```text
  # Commit hooks

  A commit hook can copy the checkout into a temporary directory and run a mise shim there, which fails because mise has never trusted the copy's `mise.toml`.

  - When a commit hook fails because mise does not trust a `mise.toml` in a temporary directory the hook created, run that one commit again with `MISE_TRUSTED_CONFIG_PATHS` set to the resolved directory that holds the one the error names, usually `"$(cd "${TMPDIR:-/tmp}" && pwd -P)"`.
  - Resolve that path with `pwd -P`, because mise checks the resolved path and `$TMPDIR` on macOS sits under `/var`, a link to `/private/var`.
  - When the retry fails with the same error, report the failure instead of retrying again.
  - Do not run `mise trust` on a temporary directory, which writes a trust entry for every throwaway copy, and do not skip the hook with `--no-verify`, which skips its checks.
  - When the untrusted file is the checkout's own `mise.toml`, trusting it is the user's decision; report the failure instead.
  ```

  In `commitHookSentences`, the first bullet's `${` must be written `\${` and its inner double quotes `\"`, so the Nix string equals the rendered sentence byte for byte.

- **KTD5. Prove R1 and R2 with stubs, not a real mise.** The check's sandbox has no mise install. A stub `markdownlint-cli2` that exits non-zero unless `MISE_TRUSTED_CONFIG_PATHS` equals its own `pwd -P` reproduces mise's refusal, and running it under a `TMPDIR` that is a symlink proves the path is resolved. A stub `mise` on `PATH` that records any call guards against a future `mise trust`; the unfixed script never calls `mise`, so that scenario is proved by a mutation instead (U1).

## Implementation Units

### U1. Trust the hook's scratch copy for its lint call

**Goal:** The hook lints in its scratch copy without a mise trust error.

**Requirements:** R1, R2, R3.

**Dependencies:** None.

**Files:**

- `scripts/lint-staged-markdown`
- `tests/lint-staged-markdown.sh`

**Approach:**

1. Apply KTD1 to the one `markdownlint-cli2` line, and update the header comment to say why the variable is set.
2. Add the scenarios below to `tests/lint-staged-markdown.sh`, with stubs placed on `PATH` the way the existing `failing_lint_bin` scenario does.

**Patterns to follow:** the `repo3` stub scenario in `tests/lint-staged-markdown.sh`; `.compound-engineering/artifacts/solutions/logic-errors/env-assignment-prefix-on-cd-never-reaches-the-next-command.md`.

**Test scenarios:**

- A stub `markdownlint-cli2` that fails unless `MISE_TRUSTED_CONFIG_PATHS` equals its `pwd -P`, with clean Markdown staged: the script exits 0.
- The same stub run with `TMPDIR` set to a symlink to a real directory: the script exits 0, and the recorded variable is the resolved path, not the symlink.
- A stub `mise` on `PATH` that records its arguments: after a run with staged Markdown, it recorded no call.
- The existing bad-Markdown and clean-Markdown scenarios pass unchanged with the real `markdownlint-cli2`.

**Verification:** `nix build --no-link .#checks.x86_64-linux.lint-staged-markdown` passes, and fails on each of these script mutations, made in a scratch copy:

1. The unfixed line: the first stub scenario must fail.
2. `MISE_TRUSTED_CONFIG_PATHS="$tmpdir"` without `pwd -P`: the symlinked-`TMPDIR` scenario must fail.
3. The assignment prefixed to `cd` instead of the lint command: the first stub scenario must fail.
4. An added `mise trust "$tmpdir"` before the lint line: the stub-`mise` scenario must fail.

A real commit in this worktree that stages Markdown runs markdownlint without a manual variable.

### U2. Update the learning

**Goal:** The learning describes the fixed hook.

**Requirements:** R4.

**Dependencies:** U1.

**Files:**

- `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`

**Approach:** Rewrite the hook paragraphs to say the hook now trusts its own copy for one command, keep the manual `MISE_TRUSTED_CONFIG_PATHS` command for other scripts that copy a checkout, update the `applies_when` entry about the hook, and bump `last_updated`.

**Test expectation:** none -- documentation; the Markdown lint covers it.

**Verification:** No sentence in the learning still tells a reader to type the variable for this repository's hook.

### U3. Add the commit-hook rule to the shared instructions

**Goal:** Every harness's rendered instructions carry the rule, pinned whole.

**Requirements:** R5, R6.

**Dependencies:** None.

**Files:**

- `home/h82/agents/instructions/instructions.md.tmpl`
- `tests/agent-instructions.nix`

**Approach:**

1. Add the KTD4 section after `# Branch names`, outside any harness branch.
2. Add `commitHookSentences` to `tests/agent-instructions.nix` holding every sentence of the section, and wire it through `requireSentences`, `onlyPinnedSentences` with pattern `.`, `sentencesInSection`, and `sentencesInOrder` under `# Commit hooks`.
3. Describe the new assertion in the check's header comment beside the other rules.

**Patterns to follow:** `gpgSentences` and `pullRequestSentences` and their wiring in `tests/agent-instructions.nix`; `.compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md`; `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`.

**Test scenarios** (mutation tests in a scratch copy built per `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`; each must turn the check red):

- Delete one pinned sentence.
- Reword one pinned sentence.
- Negate one pinned sentence with a `Do not` prefix.
- Add a contradicting sentence to the section, such as one that allows `--no-verify`.
- Swap two sentences.
- Move one sentence into `# Branch names`.
- Move the section into one harness's `{{ if }}` branch.

**Verification:** `nix build --no-link .#checks.x86_64-linux.agent-instructions` passes on the change and fails on each mutation.

## Verification Contract

- `nix fmt -- --ci`
- `nix flake check`
- `nix build --no-link .#checks.x86_64-linux.lint-staged-markdown` and `.#checks.x86_64-linux.agent-instructions`
- `nix build --no-link .#vmChecks.all`, since the VM tests build NixOS generations that carry the changed instruction files
- Build every `nixosConfigurations`, `homeConfigurations`, and `systemConfigs` output as `AGENTS.md` lists; macOS outputs build only on a macOS builder, so CI's `build-darwin` job builds them, including the Home Manager instruction files U3 changes.
- `~/.local/state/mise/trusted-configs` gains no entry for a scratch directory after a real Markdown commit.

## Definition of Done

- R1 through R6 hold, each unit's verification passed, every U1 script mutation was seen to fail the `lint-staged-markdown` check, and every U3 mutation was seen to fail the `agent-instructions` check.
- No experimental or abandoned code remains in the diff.
