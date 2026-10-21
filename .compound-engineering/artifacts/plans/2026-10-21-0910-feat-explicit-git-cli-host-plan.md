---
title: Explicit host for Git-dependent CLIs outside a checkout - Plan
type: feat
date: 2026-10-21
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Explicit host for Git-dependent CLIs outside a checkout - Plan

## Goal Capsule

- **Objective:** An agent that runs `gh`, `glab`, or a similar CLI from a temporary directory, a local scratch clone, or any directory whose remotes do not name the target repository reaches the intended host and repository instead of failing or hitting `github.com` or `gitlab.com` by default.
- **Means:** Add pinned sentences to the `# Pull and merge requests` section of the shared agent instructions template, pin them in the `agent-instructions` check, assert that the installed CLIs still accept every flag and variable the sentences name, and describe the rule in the provisioning docs (KTD1-KTD5).
- **Authority:** This plan, then `AGENTS.md`, then the existing `tests/agent-instructions.nix` contract.
- **Stop conditions:** Stop if the check's sentence splitter cannot hold the new sentences without a full stop followed by a space inside one sentence.
- **Execution profile:** One small change across a template, its check, and one doc paragraph.

## Product Contract

### Summary

The shared agent instructions gain a rule that tells an agent to pass the host and repository explicitly when it runs a CLI that infers them from the current Git checkout, in a directory whose remotes do not name the target repository.
The `agent-instructions` check pins the rule's sentences and fails when the installed `gh` or `glab` stops accepting a flag or variable the rule names.
`docs/provisioning.md` names the rule in its summary of the section.

### Problem Frame

`gh` and `glab` read the host and the repository from the current directory's Git remote.
Agents often work in scratch directories, such as review scratch roots, local clones whose `origin` is a filesystem path, or `mktemp -d` output, where no remote names the target.
There, `gh` falls back to `github.com` or fails with "not a git repository", and `glab` falls back to `gitlab.com`, so calls against a self-managed GitLab or GitHub Enterprise host go to the wrong server or fail.
`gh api` and `glab api` also fill repository placeholders such as `{owner}` and `:fullpath` from the current checkout, so naming only the host still leaves the repository unresolved.
The current instructions say nothing about this.

### Requirements

- R1. The rendered instructions tell an agent to pass the host and repository explicitly when it runs `gh`, `glab`, or another CLI that reads them from the current Git checkout, in a directory whose remotes do not name the target repository, such as a temporary directory or a clone whose `origin` is a local path.
- R2. The rendered instructions tell the agent where the values come from: the target project's own checkout, its `upstream` remote when it has one and otherwise `origin`, never a default host.
- R3. The rendered instructions name forms that carry both host and repository on every command shape: `--repo` on a subcommand that takes it (`HOST/OWNER/REPO` for `gh`, the full URL for `glab`), the same value as the positional argument of a command such as `gh repo view`, and for any other command, `gh api` and `glab api` included, `GH_REPO` or `GITLAB_REPO` prefixed to that one command, never exported, plus `--hostname HOST` for `gh api`.
- R4. The `agent-instructions` check fails when any of the new sentences is dropped, doubled, negated, moved, or reordered, the same as for every other pinned sentence.
- R5. A check fails when the `gh` or `glab` package the profile installs no longer accepts a flag or environment variable the new sentences name.

### Scope Boundaries

- Rewriting existing `gh` or `glab` usage in repository scripts is out of scope; the request covers agent instructions only.
- A wrapper that injects `GH_REPO` or `GITLAB_REPO` automatically was considered and not built: the right repository depends on the project the agent is working on, which only the agent knows.
- T3 Code's Antigravity instance reads no instructions file (see `docs/provisioning.md`), so the rule does not reach its sessions; this repository cannot change that runtime.

## Planning Contract

### Key Technical Decisions

- KTD1. **Place the rule in `# Pull and merge requests`, right after the GitLab sentence.** That section already owns `gh` and `glab` usage, and the check pins every section's sentences in order, so a new section would need a new heading in `topLevelHeadings` for no gain.
- KTD2. **Write each sentence so it holds no full stop followed by a space.** The check's `sectionSentences` splits after each full stop followed by a space, so a sentence such as one containing "e.g. " would split and fail the order check.
- KTD3. **Use the repository variables, not the host variables, for commands without `--repo`.** `gh help environment` documents `GH_REPO` in `[HOST/]OWNER/REPO` form, and `gh api` fills `{owner}` and `{repo}` from it. The profile's `glab` 1.114.0 reads `GITLAB_REPO` with a full URL and routes both host and `:fullpath` from it. `GH_HOST` and `GITLAB_HOST` set only the host, so they leave the repository to the current checkout.
- KTD4. **Add `--hostname` for `gh api`.** With `GH_REPO=HOST/OWNER/REPO` alone, `gh api` 2.102.0 still sends the request to `github.com`. Only `--hostname` or `GH_HOST` moves it, and `--hostname` is per command by construction.
- KTD5. **Prefix the variables to one command instead of exporting them.** Harnesses that keep one shell across commands would otherwise send a later call for another project to the wrong repository.
- KTD6. **Guard the named flags and variables against the installed packages.** `gh pr view --help` lists `--repo`, `gh api --help` lists `--hostname`, `gh help environment` lists `GH_REPO`, `glab mr view --help` lists `--repo`, and `glab api --help` lists `--hostname`. `glab` 1.114.0 documents `GITLAB_REPO` in no help topic, so the guard reads that name from the binary itself.

## Implementation Units

### U1. Add the rule, pin it, and document it

- **Goal:** Deliver R1-R4 in one atomic change.
- **Requirements:** R1, R2, R3, R4.
- **Dependencies:** none.
- **Files:**
  - `home/h82/agents/instructions/instructions.md.tmpl`
  - `tests/agent-instructions.nix`
  - `docs/provisioning.md`
- **Approach:**
  1. In the template, add one bullet after the "Treat GitLab like GitHub" bullet carrying the rule's sentences per KTD1-KTD5.
  2. In `tests/agent-instructions.nix`, insert the same sentences into `pullRequestsSentences` at the matching position.
  3. In `docs/provisioning.md`, extend the "pull and merge requests" parenthetical in the Shared agent instructions paragraph to mention the explicit host and repository outside a checkout.
- **Patterns to follow:** existing multi-sentence bullets such as the GPG recipient bullet and the matching split entries in `gpgSentences`.
- **Test scenarios:**
  - The `agent-instructions` check passes with the new sentences in both template and check.
  - Removing one new sentence from the template makes the check fail with "does not hold this sentence exactly once".
  - Swapping two of the new sentences in the template makes the check fail the order comparison.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.agent-instructions` passes, and the two mutations above fail it.

### U2. Guard the named CLI flags and variables

- **Goal:** Deliver R5.
- **Requirements:** R5.
- **Dependencies:** U1.
- **Files:**
  - `tests/agent-instructions.nix`, or a new check beside it registered in `flake.nix` and `tests/check-shards.nix`
- **Approach:** For the `gh` and `glab` packages the Home Manager profile installs, assert each item KTD6 lists against the named help output, and `GITLAB_REPO` against the `glab` binary.
- **Test scenarios:**
  - The check passes against the current `gh` and `glab` packages.
  - Replacing one asserted name with a name the CLI lacks, such as `--repository`, makes the check fail and names the missing flag.
- **Verification:** the check builds, and the mutation above fails it.

## Verification Contract

| Gate | Command |
| --- | --- |
| Format | `nix fmt -- --ci` |
| Targeted checks | `nix build --no-link .#checks.x86_64-linux.agent-instructions`, plus the U2 check if it is separate |
| Evaluation of all checks | `nix flake check --no-build` |
| Markdown lint | `nix build --no-link .#checks.x86_64-linux.markdown-lint`, which lints the working tree whether or not the edit is staged |

## Definition of Done

- The template, check, and doc carry the rule, and the targeted checks pass.
- The removal, reorder, and missing-flag mutations were each observed to fail their check, then reverted.
- No leftover experimental edits remain in the diff.
