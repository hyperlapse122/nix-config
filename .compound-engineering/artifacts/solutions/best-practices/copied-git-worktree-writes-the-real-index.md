---
title: "A copied git worktree still writes the real index"
date: "2026-09-28"
category: best-practices
module: NixOS flake checks (mutation testing in scratch copies)
problem_type: best_practice
component: testing_framework
severity: medium
applies_when:
  - "Mutation-testing a flake check in a scratch copy of a checkout that is a git worktree"
  - "Copying a checkout with cp -r and then running git add, git commit, or git reset inside the copy"
  - "Evaluating or building a flake whose new files are not yet tracked by Git"
root_cause: missing_workflow_step
resolution_type: workflow_improvement
related_components:
  - tooling
tags:
  - mutation-testing
  - flake-checks
  - nix
  - git-worktree
  - scratch-copy
---

# A copied git worktree still writes the real index

## Context

This repository is usually checked out as a git worktree. A worktree's `.git` is not a directory. It is a one-line file that points into the main repository:

```text
gitdir: /home/h82/nix-config/.git/worktrees/<worktree-id>
```

During the host-generic composition work (`.compound-engineering/artifacts/plans/2026-09-28-0203-refactor-host-generic-composition-plan.md`), a worker ran mutation tests in a scratch copy made with `cp -r <worktree> $TMPDIR/copy`. It ran `git add` in the copy so that the flake would evaluate the mutated files. `cp -r` copies the `.git` link file unchanged, so every git command in the copy acted on the original worktree's index. The mutations were staged in the real checkout, and the worker had to run `git reset` there to recover. The working tree was spared only because the edits happened in the copy.

A second trap sits next to this one. A flake evaluated from a git checkout sees only files Git tracks, so a module created but not yet staged is missing from `nix eval` and `nix build`. The evaluation does not fail. It either reports a missing import or quietly evaluates the tree without the new file.

## Guidance

Build scratch copies for mutation testing without the `.git` link, and give each copy its own repository:

```bash
M=$(mktemp -d)
rsync -a --exclude .git ./ "$M"/
(cd "$M" && git init -q && git add -A)
# mutate inside "$M", then: (cd "$M" && git add -A && nix build --no-link .#checks.x86_64-linux.<check>)
rm -rf "$M"
```

`git init` plus `git add -A` makes every file, tracked or not, visible to the flake in the copy. Nothing the copy does can reach the real index.

In the real checkout, stage new files (`git add <path>`) before trusting `nix eval`, `nix build`, or `nix flake check` output that should include them. Staging is enough, and no commit is needed.

## Why This Matters

The index corruption is silent. Nothing fails, so a coordinator that commits by path after the mutation run can sweep mutated test files into a commit. It can also find its planned commit already partly staged with content it never reviewed. Several workers share one worktree during an orchestrated run, so one worker's scratch experiment can reach another worker's commit.

The untracked-file trap makes a check look green against a tree that is not the one under review. A check whose new helper file is untracked can pass because it evaluated the old tree.

## When to Apply

- Any mutation-testing step in this repository (see `mutation-testing-reveals-decorative-nix-check-assertions.md`), especially when a worker or subagent runs it from a worktree.
- Any task spec handed to a worker that says to test in a copy. Name the rsync-and-`git init` recipe explicitly and forbid `cp -r` of the worktree.
- Any evaluation right after creating a new `.nix` file.

## Examples

Unsafe, because git commands in the copy write the worktree's real index:

```bash
cp -r . "$TMPDIR/copy" && cd "$TMPDIR/copy" && git add -A
```

Safe, because the copy has its own repository:

```bash
rsync -a --exclude .git ./ "$TMPDIR/copy"/ && cd "$TMPDIR/copy" && git init -q && git add -A
```
