#!/usr/bin/env bash
#
# Check interface:
#
#   bash tests/github-workflow-conventions.sh <review-workflow> <mention-workflow>
#
# Asserts that the two agent workflows keep the conventions check.yml sets, plus
# the access controls this repository depends on.
#
# Verifies, for each agent workflow:
# - every `uses:` pins a 40-character commit SHA and carries a version comment
# - every job pins its runner, and the runner is never ubuntu-latest
# - every job declares timeout-minutes
# - a concurrency group exists and is keyed on the issue or pull request number
# - the job carries its author gate, on every trigger branch
# - the declared contents permission matches the workflow's role
# And, for the mention workflow, that its tool allowlist holds nothing beyond
# the fast operations it is meant to run.
#
# Per-job rather than per-file: a file-wide count cannot tell "every job is
# bounded" from "one job is bounded twice", and a step-level timeout-minutes
# would satisfy the count while the job it belongs to runs unbounded.
#
# The two Nix workflows are deliberately not read: they pin
# cachix/install-nix-action without a version comment, so a repository-wide
# version-comment assertion would fail on day one.
#
# Each assertion fails inside the builder with its own message, so a content
# mutation is distinguishable from a Nix evaluation error. Deleting a workflow
# file instead fails at evaluation, which proves nothing about these assertions.
#
# The version-comment assertion checks the comment's shape, not that the SHA it
# names really is that tag; a sandboxed check has no network to resolve it.

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <review-workflow> <mention-workflow>" >&2
  exit 1
fi

review=$1
mention=$2

fail() {
  echo "$1" >&2
  exit 1
}

for workflow in "$review" "$mention"; do
  if [ ! -r "$workflow" ]; then
    fail "cannot read workflow file: $workflow"
  fi
done

uses_lines() {
  grep -E '^\s*(- )?uses:' "$1" || true
}

# One line per job: "<name> <has runs-on> <has timeout-minutes>". Job keys sit at
# two-space indent under `jobs:`; a job's own keys sit at four. A step's keys are
# deeper still, so they cannot satisfy a job's obligation.
job_facts() {
  awk '
    /^jobs:/ { in_jobs = 1; next }
    in_jobs && /^[^[:space:]]/ { in_jobs = 0; cur = "" }
    in_jobs && /^  [A-Za-z0-9_-]+:[[:space:]]*(#.*)?$/ {
      cur = $1
      sub(/:$/, "", cur)
      order[++n] = cur
      runs[cur] = 0
      timeout[cur] = 0
      next
    }
    cur != "" && /^    runs-on:/ { runs[cur] = 1 }
    cur != "" && /^    timeout-minutes:/ { timeout[cur] = 1 }
    END {
      for (i = 1; i <= n; i++) {
        job = order[i]
        print job, runs[job], timeout[job]
      }
    }
  ' "$1"
}

# The job condition, with full-line comments removed so prose about a rule never
# stands in for the rule.
job_condition() {
  grep -vE '^[[:space:]]*#' "$1" | awk '
    /^[[:space:]]+if:/ { in_if = 1; print; next }
    in_if && /^[[:space:]]{6,}/ { print; next }
    in_if { in_if = 0 }
  '
}

check_common() {
  local file=$1
  local label=$2

  local uses
  uses=$(uses_lines "$file")
  if [ -z "$uses" ]; then
    fail "$label declares no actions; the pinning assertions would pass vacuously"
  fi

  while IFS= read -r line; do
    if ! printf '%s' "$line" | grep -qE '@[0-9a-f]{40}([[:space:]]|$)'; then
      fail "$label pins an action without a 40-character commit SHA: $line"
    fi
    if ! printf '%s' "$line" | grep -qE '@[0-9a-f]{40}[[:space:]]+# v[0-9]'; then
      fail "$label pins an action without a version comment: $line"
    fi
  done <<<"$uses"

  local facts
  facts=$(job_facts "$file")
  if [ -z "$facts" ]; then
    fail "$label declares no jobs; the per-job assertions would pass vacuously"
  fi

  while read -r job has_runs_on has_timeout; do
    if [ "$has_runs_on" -ne 1 ]; then
      fail "$label job '$job' does not pin a runner"
    fi
    if [ "$has_timeout" -ne 1 ]; then
      fail "$label job '$job' declares no timeout-minutes"
    fi
  done <<<"$facts"

  if grep -qE '^\s*runs-on:[[:space:]]*ubuntu-latest' "$file"; then
    fail "$label runs on ubuntu-latest; pin the runner image"
  fi

  if ! grep -qE '^concurrency:' "$file"; then
    fail "$label declares no concurrency group"
  fi
  if ! grep -qE '^\s*group:.*github\.event\.(issue|pull_request)\.number' "$file"; then
    fail "$label keys its concurrency group on something other than the issue or pull request number"
  fi
}

check_common "$review" "the review workflow"
check_common "$mention" "the mention workflow"

# The review workflow must exclude only the agent's own bot. Excluding every bot
# would skip the review on this repository's own flake.lock pull requests, whose
# skipped review then reads as missing evidence and holds them forever.
if ! grep -qE "github\.event\.pull_request\.user\.login[[:space:]]*!=[[:space:]]*'claude\[bot\]'" "$review"; then
  fail "the review workflow does not exclude the agent's own bot as pull request author"
fi
if grep -vE '^[[:space:]]*#' "$review" | grep -q 'github\.actor'; then
  fail "the review workflow gates on github.actor; the agent's own push must still re-trigger it"
fi
if ! grep -qE '^\s*contents:[[:space:]]*read[[:space:]]*$' "$review"; then
  fail "the review workflow does not declare contents: read"
fi
if grep -qE '^\s*contents:[[:space:]]*write' "$review"; then
  fail "the review workflow declares contents: write; it stays diff-only"
fi

# Every trigger branch of the mention workflow must carry the owner comparison.
# The action validates whoever assigned an issue, not whoever wrote its body, so
# a branch missing the comparison is the hole this gate exists to close.
mention_condition=$(job_condition "$mention")
branches=$(printf '%s' "$mention_condition" | grep -cE 'github\.event_name[[:space:]]*==' || true)
owner_gates=$(printf '%s' "$mention_condition" | grep -cE 'user\.login[[:space:]]*==[[:space:]]*github\.repository_owner' || true)
if [ "${branches:-0}" -eq 0 ]; then
  fail "the mention workflow's job condition names no trigger branch"
fi
if [ "${owner_gates:-0}" -ne "${branches:-0}" ]; then
  fail "the mention workflow gates ${owner_gates:-0} of ${branches:-0} trigger branches on the repository owner"
fi
if ! grep -qE '^\s*contents:[[:space:]]*write' "$mention"; then
  fail "the mention workflow does not declare contents: write"
fi
if ! grep -qE '^\s*use_commit_signing:[[:space:]]*true' "$mention"; then
  fail "the mention workflow does not enable commit signing"
fi

# An allowlist, not a denylist: naming what may run catches a widened entry that
# a ban on one spelling would miss.
allowed_tools=$(grep -oE '\--allowedTools "[^"]*"' "$mention" | head -n 1 | sed -E 's/^--allowedTools "//; s/"$//')
if [ -z "$allowed_tools" ]; then
  fail "the mention workflow declares no --allowedTools list"
fi
IFS=',' read -r -a tool_entries <<<"$allowed_tools"
for tool in "${tool_entries[@]}"; do
  case "$tool" in
    'Bash(nix fmt:*)' | 'Bash(nix eval:*)' | 'Bash(nix build:*)' | 'Bash(nix flake metadata:*)' | 'Bash(mise install:*)' | 'Bash(sleep:*)') ;;
    *) fail "the mention workflow allows an unexpected tool: $tool" ;;
  esac
done
if grep -qE 'dangerously-skip-permissions|--permission-mode' "$mention"; then
  fail "the mention workflow relaxes the action's permission handling"
fi

echo "agent workflow conventions hold"
