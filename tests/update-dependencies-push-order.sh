#!/usr/bin/env bash
#
# Check interface:
#
#   bash tests/update-dependencies-push-order.sh <update-dependencies-workflow>
#
# Extracts the literal script of the "Push verified updates directly to main"
# step from the given workflow file and runs it against a real sandboxed git
# remote, so a regression in the *behaviour* of that step is caught even
# though the step's shell is never parsed structurally.
#
# `git rebase <upstream>` refuses to run against a dirty working tree even
# when <upstream> is identical to HEAD -- there is nothing to replay, but git
# still requires a clean tree before it will look. The step commits the
# updates `nix flake update` (run earlier in the job) left uncommitted, so
# rebasing before those commits land fails unconditionally, every time the
# job actually has something to push. Ordering the commits before the fetch
# and rebase is what makes the step able to succeed at all.
#
# Two scenarios exercise that ordering:
# - origin/main unchanged since checkout: the step must still succeed (this
#   is the exact case that failed every run in production). This scenario
#   also leaves fmt.log/check.log untracked in the clone, the way the real
#   "Verify updates" step does, to prove the catch-all `git add -A` commit
#   never sweeps them into main now that this ordering fix makes that commit
#   reachable for the first time.
# - origin/main advanced with an unrelated commit: the step must rebase onto
#   it and push both commits.

set -euo pipefail

workflow=${1:-}
if [[ $# -ne 1 || -z $workflow || ! -f $workflow ]]; then
  printf 'usage: %s WORKFLOW_FILE\n' "${0##*/}" >&2
  exit 2
fi

fail() { printf 'update-dependencies-push-order: FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'update-dependencies-push-order: ok - %s\n' "$*"; }

step_script=$(awk -v step="- name: Push verified updates directly to main" '
  found == 0 && index($0, step) > 0 { found = 1; next }
  found == 1 && capturing == 0 && $0 ~ /^[[:space:]]*run: \|[[:space:]]*$/ { capturing = 1; next }
  capturing == 1 {
    if ($0 ~ /^[[:space:]]*$/) { print ""; next }
    line = $0
    sub(/^[[:space:]]*/, "", line)
    lead = length($0) - length(line)
    if (indent < 0) { indent = lead }
    if (lead < indent) { exit }
    print substr($0, indent + 1)
    next
  }
' indent=-1 "$workflow")

[[ -n $step_script ]] || fail "could not find the push step's run block in $workflow"

scratch=$(mktemp -d "${TMPDIR:-/tmp}/update-dependencies-push-order.XXXXXX")
trap 'rm -rf -- "$scratch"' EXIT

git_bin=$(command -v git) || fail 'git is required'

run_push_step() {
  local worktree=$1
  (cd "$worktree" && bash -c "$step_script")
}

setup_clone() {
  local name=$1
  local origin=$scratch/$name-origin.git
  local clone=$scratch/$name-clone
  "$git_bin" init -q --bare "$origin"
  # A sandboxed HOME carries no init.defaultBranch, so a bare init's HEAD
  # symref defaults to refs/heads/master. Pin it to main before anything
  # clones this repo, or a second clone after the first push follows a HEAD
  # that points at a branch nothing ever populated.
  "$git_bin" --git-dir "$origin" symbolic-ref HEAD refs/heads/main
  "$git_bin" clone -q "$origin" "$clone"
  "$git_bin" -C "$clone" config user.email t@example.invalid
  "$git_bin" -C "$clone" config user.name Test
  "$git_bin" -C "$clone" checkout -qb main
  printf 'base\n' >"$clone/tracked.txt"
  printf '/fmt.log\n/check.log\n' >"$clone/.gitignore"
  "$git_bin" -C "$clone" add tracked.txt .gitignore
  "$git_bin" -C "$clone" commit -qm init
  "$git_bin" -C "$clone" push -q "$origin" main
  printf '%s %s\n' "$origin" "$clone"
}

# --- origin/main unchanged: the exact case that failed every production run
read -r origin clone <<<"$(setup_clone same)"
printf 'changed\n' >>"$clone/tracked.txt"
printf 'nix fmt output\n' >"$clone/fmt.log"
printf 'nix flake check output\n' >"$clone/check.log"
if ! run_push_step "$clone"; then
  fail 'the push step failed against an unchanged origin/main (dirty-tree rebase regression)'
fi
pushed=$("$git_bin" --git-dir "$origin" log -1 --format=%s main)
[[ $pushed == "chore(deps): update dependencies" ]] ||
  fail "origin/main does not carry the pushed commit: $pushed"
tracked=$("$git_bin" --git-dir "$origin" ls-tree -r --name-only main)
[[ $tracked != *"fmt.log"* && $tracked != *"check.log"* ]] ||
  fail "verification logs were committed to main: $tracked"
pass 'succeeds, pushes, and never commits the verify step'\''s fmt.log/check.log'

# --- origin/main advanced with an unrelated commit: must rebase and push both
read -r origin clone <<<"$(setup_clone diverged)"
other=$scratch/diverged-other
"$git_bin" clone -q "$origin" "$other"
"$git_bin" -C "$other" config user.email o@example.invalid
"$git_bin" -C "$other" config user.name Other
printf 'concurrent\n' >"$other/other.txt"
"$git_bin" -C "$other" add other.txt
"$git_bin" -C "$other" commit -qm 'concurrent commit'
"$git_bin" -C "$other" push -q origin main

printf 'changed\n' >>"$clone/tracked.txt"
if ! run_push_step "$clone"; then
  fail 'the push step failed to rebase onto a diverged origin/main'
fi
log=$("$git_bin" --git-dir "$origin" log --format=%s main)
[[ $log == *"chore(deps): update dependencies"* ]] ||
  fail "origin/main is missing the rebased commit: $log"
[[ $log == *"concurrent commit"* ]] ||
  fail "origin/main lost the concurrent commit it should have rebased onto: $log"
pass 'rebases onto a diverged origin/main and pushes both commits'
