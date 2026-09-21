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
# - the runner image is pinned, never ubuntu-latest
# - a concurrency group exists and is keyed on the issue or pull request number
# - every job declares timeout-minutes
# - the job carries its author gate
# - the declared contents permission matches the workflow's role
#
# The two Nix workflows are deliberately not read: they pin
# cachix/install-nix-action without a version comment, so a repository-wide
# version-comment assertion would fail on day one.
#
# Each assertion fails inside the builder with its own message, so a content
# mutation is distinguishable from a Nix evaluation error. Deleting a workflow
# file instead fails at evaluation, which proves nothing about these assertions.

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

uses_lines() {
  grep -E '^\s*(- )?uses:' "$1" || true
}

job_keys() {
  awk '/^jobs:/ { in_jobs = 1; next }
       in_jobs && /^[^[:space:]]/ { in_jobs = 0 }
       in_jobs && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ { count++ }
       END { print count + 0 }' "$1"
}

count_matches() {
  grep -cE "$2" "$1" || true
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

  if ! grep -qE '^\s*runs-on:' "$file"; then
    fail "$label declares no runner"
  fi
  if grep -qE '^\s*runs-on:[[:space:]]*ubuntu-latest' "$file"; then
    fail "$label runs on ubuntu-latest; pin the runner image"
  fi

  if ! grep -qE '^concurrency:' "$file"; then
    fail "$label declares no concurrency group"
  fi
  if ! grep -qE '^\s*group:.*github\.event\.(issue|pull_request)\.number' "$file"; then
    fail "$label keys its concurrency group on something other than the issue or pull request number"
  fi

  local jobs timeouts
  jobs=$(job_keys "$file")
  timeouts=$(count_matches "$file" '^\s*timeout-minutes:')
  if [ "$jobs" -eq 0 ]; then
    fail "$label declares no jobs; the timeout assertion would pass vacuously"
  fi
  if [ "$timeouts" -ne "$jobs" ]; then
    fail "$label declares $jobs job(s) but $timeouts timeout-minutes"
  fi
}

check_common "$review" "the review workflow"
check_common "$mention" "the mention workflow"

if ! grep -qE "github\.event\.pull_request\.user\.type[[:space:]]*!=[[:space:]]*'Bot'" "$review"; then
  fail "the review workflow does not gate on a non-bot pull request author"
fi
if grep -qE '^\s*if:.*github\.actor' "$review"; then
  fail "the review workflow gates on github.actor; the agent's own push must still re-trigger it"
fi
if ! grep -qE '^\s*contents:[[:space:]]*read' "$review"; then
  fail "the review workflow does not declare contents: read"
fi
if grep -qE '^\s*contents:[[:space:]]*write' "$review"; then
  fail "the review workflow declares contents: write; it stays diff-only"
fi

if ! grep -q 'github\.repository_owner' "$mention"; then
  fail "the mention workflow does not gate on the repository owner authoring the triggering text"
fi
if ! grep -qE '^\s*contents:[[:space:]]*write' "$mention"; then
  fail "the mention workflow does not declare contents: write"
fi
if grep -qE 'Bash\(git ' "$mention"; then
  fail "the mention workflow allows a git tool; commits go through the action's signing path"
fi
if ! grep -qE '^\s*use_commit_signing:[[:space:]]*true' "$mention"; then
  fail "the mention workflow does not enable commit signing"
fi

echo "agent workflow conventions hold"
