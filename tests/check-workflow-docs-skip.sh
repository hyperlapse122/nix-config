#!/usr/bin/env bash
#
# Check interface:
#
#   bash tests/check-workflow-docs-skip.sh <check.yml>
#
# Asserts the docs-only CI skip wiring in .github/workflows/check.yml:
#
# - flake-check and build each declare `needs: changes` and an `if:`
#   that runs them on any non-pull_request event, or when the changes
#   job did not complete successfully, and skips only a definitive
#   docs_only:true (KTD4/R6/R7 in the docs-skip-markdown-lint plan).
# - markdown-lint declares the complementary condition: it runs only on
#   a genuine docs_only:true PR, the one case flake-check's own
#   `nix flake check` does not already build it, so it is exercised
#   exactly once per event instead of twice on ordinary PRs and push.
# - fmt carries no such conditional -- it always runs.
#
# Each assertion fails inside an explicit if/exit branch, never a
# negated `! grep`, per this repository's decorative-assertion
# learning (mutation-testing-reveals-decorative-nix-check-assertions.md):
# a `! grep` is exempt from `set -e` and would prove nothing.

set -euo pipefail

file=${1:-}
if [ "$#" -ne 1 ] || [ -z "$file" ] || [ ! -r "$file" ]; then
  printf 'usage: %s CHECK_YML\n' "${0##*/}" >&2
  exit 2
fi

fail() {
  echo "$1" >&2
  exit 1
}

# job_block <name> <file>: the job's own lines (two-space job key through
# the line before the next two-space job key, or EOF), so a job's `if:`
# is never mistaken for a step's `if:` sitting deeper in the file.
job_block() {
  local job=$1 file=$2
  awk -v job="$job" '
    /^jobs:/ { in_jobs = 1; next }
    in_jobs && /^[^[:space:]]/ { in_jobs = 0; printing = 0 }
    in_jobs && /^  [A-Za-z0-9_-]+:[[:space:]]*(#.*)?$/ {
      cur = $1
      sub(/:$/, "", cur)
      printing = (cur == job)
      next
    }
    printing { print }
  ' "$file"
}

assert_gated() {
  local job=$1 block
  block=$(job_block "$job" "$file")
  if [ -z "$block" ]; then
    fail "job '$job' not found in $file"
  fi
  if ! printf '%s\n' "$block" | grep -qE '^[[:space:]]*needs:[[:space:]]*changes[[:space:]]*$'; then
    fail "job '$job' does not declare 'needs: changes'"
  fi
  local if_line
  if_line=$(printf '%s\n' "$block" | grep -E '^[[:space:]]*if:' || true)
  if [ -z "$if_line" ]; then
    fail "job '$job' declares no if: condition"
  fi
  if ! printf '%s' "$if_line" | grep -qF "github.event_name != 'pull_request'"; then
    fail "job '$job' if: does not run on non-pull_request events (R7)"
  fi
  if ! printf '%s' "$if_line" | grep -qF 'needs.changes.result != '"'"'success'"'"; then
    fail "job '$job' if: does not fail open when the changes job did not succeed (R6/KTD4)"
  fi
  if ! printf '%s' "$if_line" | grep -qF "needs.changes.outputs.docs_only != 'true'"; then
    fail "job '$job' if: does not gate on a definitive docs_only:true (R1)"
  fi
  echo "check-workflow-docs-skip: ok - job '$job' is gated on the changes job (R1/R6/R7/KTD4)"
}

assert_unconditional() {
  local job=$1 block
  block=$(job_block "$job" "$file")
  if [ -z "$block" ]; then
    fail "job '$job' not found in $file"
  fi
  if printf '%s\n' "$block" | grep -qE '^[[:space:]]*if:'; then
    fail "job '$job' declares an if: condition; it must always run (R2)"
  fi
  if printf '%s\n' "$block" | grep -qE '^[[:space:]]*needs:'; then
    fail "job '$job' declares needs:; it must not depend on the classifier"
  fi
  echo "check-workflow-docs-skip: ok - job '$job' runs unconditionally"
}

# assert_docs_only_only <job>: the complement of assert_gated's condition
# -- this job runs ONLY when the classifier succeeded and found a genuine
# docs-only PR, i.e. only in the one case flake-check/build are skipped
# and nothing else would have exercised it.
assert_docs_only_only() {
  local job=$1 block
  block=$(job_block "$job" "$file")
  if [ -z "$block" ]; then
    fail "job '$job' not found in $file"
  fi
  if ! printf '%s\n' "$block" | grep -qE '^[[:space:]]*needs:[[:space:]]*changes[[:space:]]*$'; then
    fail "job '$job' does not declare 'needs: changes'"
  fi
  local if_line
  if_line=$(printf '%s\n' "$block" | grep -E '^[[:space:]]*if:' || true)
  if [ -z "$if_line" ]; then
    fail "job '$job' declares no if: condition"
  fi
  if ! printf '%s' "$if_line" | grep -qF "github.event_name == 'pull_request'"; then
    fail "job '$job' if: does not require a pull_request event"
  fi
  if ! printf '%s' "$if_line" | grep -qF 'needs.changes.result == '"'"'success'"'"; then
    fail "job '$job' if: does not require the classifier to have succeeded"
  fi
  if ! printf '%s' "$if_line" | grep -qF "needs.changes.outputs.docs_only == 'true'"; then
    fail "job '$job' if: does not require a definitive docs_only:true"
  fi
  echo "check-workflow-docs-skip: ok - job '$job' runs only on a genuine docs-only PR"
}

assert_gated flake-check
assert_gated build
assert_unconditional fmt
assert_docs_only_only markdown-lint

echo "check-workflow-docs-skip: ok - all wiring assertions passed"
