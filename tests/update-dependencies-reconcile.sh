#!/usr/bin/env bash
#
# Check interface:
#
#   bash tests/update-dependencies-reconcile.sh <update-dependencies-workflow>
#
# Covers the updater's failure path, its schedule, and the T3 Code bump:
#
# - The "Open reconciliation PR on failure" step's literal script runs
#   against a sandboxed git remote and a stub `gh` that rejects any
#   `--label`, the way the real repository does: it has no `dependencies`
#   or `automated` label, and the workflow cannot create one. The step must
#   push the fix branch, open the PR, and exit 0, so the Claude step after
#   it runs. With a PR already open on the branch, it must edit that PR
#   instead of creating another.
# - The Claude step must set CLAUDE_BRANCH to the fix branch. On a scheduled
#   run claude-code-action otherwise commits to GITHUB_REF_NAME, which is
#   main. Its allowed tools must include the action's commit tool, or it
#   cannot commit at all.
# - No step may run `gh pr merge`: a PR opened with GITHUB_TOKEN triggers no
#   CI, and main requires no check, so auto-merge would land an unverified
#   fix on main.
# - The cron must fire twice an hour and never at minute 0.
# - The "Push verified updates directly to main" step must commit a T3 Code
#   pin change on its own, as `chore(packages): bump t3code to <version>`.

set -euo pipefail

workflow=${1:-}
if [[ $# -ne 1 || -z $workflow || ! -f $workflow ]]; then
  printf 'usage: %s WORKFLOW_FILE\n' "${0##*/}" >&2
  exit 2
fi

fail() { printf 'update-dependencies-reconcile: FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'update-dependencies-reconcile: ok - %s\n' "$*"; }

fix_branch=update-dependencies-fix

# step_run <name>: the dedented `run: |` block of the named step.
step_run() {
  awk -v step="- name: $1" '
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
  ' indent=-1 "$workflow"
}

# step_block <name>: every line of the named step, up to the next step. A
# step starts at a `- ` line at the step list's indent; some steps have no
# name, so the end is found by indent rather than by `- name:`.
step_block() {
  awk -v step="- name: $1" '
    found == 0 && index($0, step) > 0 {
      found = 1
      line = $0
      sub(/^[[:space:]]*/, "", line)
      indent = length($0) - length(line)
      print
      next
    }
    found == 1 {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      lead = length($0) - length(line)
      if (line != "" && lead <= indent) { exit }
      print
    }
  ' "$workflow"
}

scratch=$(mktemp -d "${TMPDIR:-/tmp}/update-dependencies-reconcile.XXXXXX")
trap 'rm -rf -- "$scratch"' EXIT

git_bin=$(command -v git) || fail 'git is required'

# setup_clone <name>: a bare origin with main and a clone of it.
setup_clone() {
  local name=$1
  local origin=$scratch/$name-origin.git
  local clone=$scratch/$name-clone
  "$git_bin" init -q --bare "$origin"
  # A sandboxed HOME has no init.defaultBranch; pin HEAD to main.
  "$git_bin" --git-dir "$origin" symbolic-ref HEAD refs/heads/main
  "$git_bin" clone -q "$origin" "$clone"
  "$git_bin" -C "$clone" config user.email t@example.invalid
  "$git_bin" -C "$clone" config user.name Test
  "$git_bin" -C "$clone" checkout -qb main
  mkdir -p "$clone/packages"
  printf '{"version": "0.0.46-nightly.20261003.2600"}\n' >"$clone/packages/t3code-release.json"
  printf 'base\n' >"$clone/tracked.txt"
  "$git_bin" -C "$clone" add tracked.txt packages/t3code-release.json
  "$git_bin" -C "$clone" commit -qm init
  "$git_bin" -C "$clone" push -q origin main
  printf '%s %s\n' "$origin" "$clone"
}

# --- reconciliation PR step -------------------------------------------------

pr_block=$(step_block 'Open reconciliation PR on failure')
[[ -n $pr_block ]] || fail "could not find the reconciliation PR step in $workflow"
grep -Eq "^[[:space:]]*BRANCH:[[:space:]]*${fix_branch}[[:space:]]*$" <<<"$pr_block" ||
  fail "the reconciliation PR step does not set BRANCH to $fix_branch"
pr_script=$(step_run 'Open reconciliation PR on failure')
[[ -n $pr_script ]] || fail "could not find the reconciliation PR step's run block in $workflow"

# run_pr_step <name> <existing>: runs the step with a stub `gh` whose
# `pr view` reports an open PR when <existing> is 1. The stub logs each
# call to gh.log, copies --body-file to body.md, and fails on any --label,
# as `gh` does when the label does not exist.
run_pr_step() {
  local name=$1 existing=$2 origin clone
  read -r origin clone <<<"$(setup_clone "$name")"
  mkdir -p "$scratch/$name-bin"
  cat >"$scratch/$name-bin/gh" <<EOF
#!$BASH
printf '%s\n' "\$*" >>"$scratch/$name-gh.log"
prev=
for arg in "\$@"; do
  if [[ \$arg == --label || \$arg == --label=* || \$arg == --add-label* ]]; then
    echo "could not add label: 'dependencies' not found" >&2
    exit 1
  fi
  if [[ \$prev == --body-file ]]; then cp "\$arg" "$scratch/$name-body.md"; fi
  prev=\$arg
done
if [[ \$1 == pr && \$2 == view ]]; then
  [[ $existing == 1 ]] && { echo '{"number": 7}'; exit 0; }
  echo 'no pull requests found' >&2
  exit 1
fi
exit 0
EOF
  chmod +x "$scratch/$name-bin/gh"
  : >"$scratch/$name-gh.log"
  printf 'changed\n' >>"$clone/tracked.txt"
  printf 'nix flake check output\n' >"$clone/check.log"
  printf 'nix build vmChecks output\n' >"$clone/vm-check.log"
  (
    cd "$clone"
    PATH=$scratch/$name-bin:$PATH BRANCH=$fix_branch bash -e -c "$pr_script"
  ) >"$scratch/$name-step.log" 2>&1 ||
    fail "the reconciliation PR step exited non-zero ($name): $(tail -n 5 "$scratch/$name-step.log")"
  "$git_bin" --git-dir "$origin" rev-parse -q --verify "refs/heads/$fix_branch" >/dev/null ||
    fail "the reconciliation PR step did not push $fix_branch ($name)"
  printf '%s\n' "$origin"
}

origin=$(run_pr_step create 0)
grep -q '^pr create' "$scratch/create-gh.log" ||
  fail "with no open PR, the step did not run gh pr create: $(cat "$scratch/create-gh.log")"
pass "with no labels in the repository, the step pushes $fix_branch, opens the PR, and exits 0"

body=$(cat "$scratch/create-body.md")
[[ $body != *hourly* ]] || fail 'the PR body still calls the updater hourly'
[[ $body != *"merged automatically"* ]] || fail 'the PR body still promises an automatic merge'
pass 'the PR body neither calls the updater hourly nor promises an automatic merge'

run_pr_step edit 1 >/dev/null
grep -q '^pr edit' "$scratch/edit-gh.log" ||
  fail "with a PR already open, the step did not run gh pr edit: $(cat "$scratch/edit-gh.log")"
if grep -q '^pr create' "$scratch/edit-gh.log"; then
  fail 'with a PR already open, the step still ran gh pr create'
fi
pass 'with a PR already open, the step edits it instead of creating one'

# --- Claude step and auto-merge ---------------------------------------------

claude_block=$(step_block 'Reconcile breakages with Claude Code')
[[ -n $claude_block ]] || fail "could not find the Claude reconciliation step in $workflow"
grep -Eq "^[[:space:]]*CLAUDE_BRANCH:[[:space:]]*${fix_branch}[[:space:]]*$" <<<"$claude_block" ||
  fail "the Claude step does not set CLAUDE_BRANCH to $fix_branch, so its commits go to main"
grep -q 'mcp__github_file_ops__commit_files' <<<"$claude_block" ||
  fail "the Claude step's allowed tools omit mcp__github_file_ops__commit_files"
pass "the Claude step commits to $fix_branch with the action's commit tool allowed"

if grep -Eq 'gh[[:space:]]+pr[[:space:]]+merge' "$workflow"; then
  fail 'a step runs gh pr merge, which would merge an unverified fix into main'
fi
pass 'no step runs gh pr merge'

# --- schedule ---------------------------------------------------------------

crons=$(sed -n "s/^[[:space:]]*-[[:space:]]*cron:[[:space:]]*['\"]\([^'\"]*\)['\"].*/\1/p" "$workflow")
[[ -n $crons ]] || fail "could not find a cron schedule in $workflow"
[[ $(wc -l <<<"$crons") -eq 1 ]] || fail "expected one cron schedule, found: $crons"
read -r minutes hours dom month dow extra <<<"$crons"
[[ -z $extra && $hours == '*' && $dom == '*' && $month == '*' && $dow == '*' ]] ||
  fail "the cron does not run every hour of every day: $crons"
IFS=, read -r -a minute_list <<<"$minutes"
for minute in "${minute_list[@]}"; do
  if [[ ! $minute =~ ^[0-9]+$ ]] || ((10#$minute > 59)); then
    fail "cron minute '$minute' is not a single minute, so it may include :00: $crons"
  fi
  ((10#$minute != 0)) || fail "the cron fires at minute 0: $crons"
done
((${#minute_list[@]} == 2)) || fail "the cron fires ${#minute_list[@]} times an hour, not twice: $crons"
pass "the cron fires twice an hour, never on the hour ($crons)"

# --- T3 Code bump commit ----------------------------------------------------

push_script=$(step_run 'Push verified updates directly to main')
[[ -n $push_script ]] || fail "could not find the push step's run block in $workflow"
command -v jq >/dev/null || fail 'jq is required'

read -r origin clone <<<"$(setup_clone t3code)"
new_version=0.0.46-nightly.20261004.2644
printf '{"version": "%s"}\n' "$new_version" >"$clone/packages/t3code-release.json"
(cd "$clone" && bash -e -c "$push_script") >"$scratch/t3code-step.log" 2>&1 ||
  fail "the push step failed on a T3 Code pin change: $(tail -n 5 "$scratch/t3code-step.log")"
subject=$("$git_bin" --git-dir "$origin" log -1 --format=%s main)
[[ $subject == "chore(packages): bump t3code to $new_version" ]] ||
  fail "a T3 Code pin change was not committed as its own bump: $subject"
files=$("$git_bin" --git-dir "$origin" show --format= --name-only main)
[[ $files == packages/t3code-release.json ]] ||
  fail "the t3code bump commit carries more than the pin: $files"
pass 'a T3 Code pin change lands as its own chore(packages): bump t3code commit'
