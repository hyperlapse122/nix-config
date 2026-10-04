#!/usr/bin/env bash
#
# Check interface:
#
#   bash tests/check-workflow-docs-skip.sh <check.yml>
#
# Asserts the docs-only CI skip wiring in .github/workflows/check.yml:
#
# - flake-check, hosts, and build each depend on `changes` and declare an
#   `if:` that runs them on any non-pull_request event, or when the changes
#   job did not complete successfully, and skips only a definitive
#   docs_only:true (KTD4/R6/R7 in the docs-skip-markdown-lint plan).
#   flake-check and hosts declare exactly `needs: changes`; build also
#   needs hosts, so it may list `changes` among others (KTD9 in the
#   host-generic composition plan).
# - build reads its matrix from the hosts job's output, so the workflow
#   never lists host names (R19). build-linux does the same for the
#   non-NixOS outputs and aarch64 fixture checks, and sends aarch64 targets
#   to the ubuntu-24.04-arm runner so nothing is built under emulation.
# - check-shard-names and check-shards carry the same gate, so every flake
#   check still builds on every non-docs-only PR and on push now that
#   flake-check only evaluates. check-shards reads its matrix from
#   check-shard-names, so a check added to `checks` joins CI without a
#   workflow edit. Both listers fail on an empty name list.
# - vm-check-names and vm-checks carry the same gate, so the NixOS VM tests
#   that live outside `nix flake check` still run on every non-docs-only
#   PR and on push. vm-checks reads its matrix from vm-check-names, so a
#   VM test added to tests/vm-checks.nix joins CI without a workflow edit.
# - markdown-lint declares the complementary condition: it runs only on
#   a genuine docs_only:true PR, the one case no check-shards entry
#   already builds it, so it is exercised exactly once per event instead
#   of twice on ordinary PRs and push.
# - fmt carries no such conditional -- it always runs.
#
# Each assertion fails inside an explicit if/exit branch, never a
# negated `! grep`, per this repository's decorative-assertion
# learning (mutation-testing-reveals-decorative-nix-check-assertions.md):
# a `! grep` is exempt from `set -e` and would prove nothing.
#
# Every assertion feeds its input through a here-string, never
# `printf ... | grep -q`: grep -q exits at its first match, the printf
# still writing later lines then fails with a broken pipe, and pipefail
# reports that as a miss.

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

# needs_pattern scalar|list: the needs: line a gated job must carry.
# scalar is exactly `needs: changes`; list also accepts a flow list that
# names `changes` as one of its entries, e.g. `needs: [changes, hosts]`.
needs_pattern() {
  case $1 in
    scalar) echo '^[[:space:]]*needs:[[:space:]]*changes[[:space:]]*$' ;;
    list) echo '^[[:space:]]*needs:[[:space:]]*(changes|\[([^]]*,)?[[:space:]]*changes[[:space:]]*(,[^]]*)?\])[[:space:]]*$' ;;
    *) fail "unknown needs form: $1" ;;
  esac
}

assert_gated() {
  local job=$1 needs_form=${2:-scalar} block
  block=$(job_block "$job" "$file")
  if [ -z "$block" ]; then
    fail "job '$job' not found in $file"
  fi
  if ! grep -qE "$(needs_pattern "$needs_form")" <<<"$block"; then
    fail "job '$job' does not declare 'changes' in needs: ($needs_form form)"
  fi
  local if_line expected
  if_line=$(grep -E '^[[:space:]]*if:' <<<"$block" || true)
  if [ -z "$if_line" ]; then
    fail "job '$job' declares no if: condition"
  fi
  # The full literal condition as one fixed string, connectives included --
  # three independent substring checks would each still match a mutation
  # that swaps || for && (a real, verified false pass): only an exact match
  # on the whole expression proves the clauses are joined the way R1/R6/R7
  # require, not just present somewhere in the line.
  expected="!cancelled() && (github.event_name != 'pull_request' || needs.changes.result != 'success' || needs.changes.outputs.docs_only != 'true')"
  if ! grep -qF -- "$expected" <<<"$if_line"; then
    fail "job '$job' if: does not match the expected fail-open condition exactly (R1/R6/R7/KTD4); got: $if_line"
  fi
  echo "check-workflow-docs-skip: ok - job '$job' is gated on the changes job (R1/R6/R7/KTD4)"
}

assert_unconditional() {
  local job=$1 block
  block=$(job_block "$job" "$file")
  if [ -z "$block" ]; then
    fail "job '$job' not found in $file"
  fi
  if grep -qE '^[[:space:]]*if:' <<<"$block"; then
    fail "job '$job' declares an if: condition; it must always run (R2)"
  fi
  if grep -qE '^[[:space:]]*needs:' <<<"$block"; then
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
  if ! grep -qE '^[[:space:]]*needs:[[:space:]]*changes[[:space:]]*$' <<<"$block"; then
    fail "job '$job' does not declare 'needs: changes'"
  fi
  local if_line expected
  if_line=$(grep -E '^[[:space:]]*if:' <<<"$block" || true)
  if [ -z "$if_line" ]; then
    fail "job '$job' declares no if: condition"
  fi
  # Exact match on the whole expression, connectives included -- see the
  # comment in assert_gated for why independent substring checks do not
  # prove the clauses are joined with &&.
  expected="!cancelled() && github.event_name == 'pull_request' && needs.changes.result == 'success' && needs.changes.outputs.docs_only == 'true'"
  if ! grep -qF -- "$expected" <<<"$if_line"; then
    fail "job '$job' if: does not match the expected docs-only-only condition exactly; got: $if_line"
  fi
  echo "check-workflow-docs-skip: ok - job '$job' runs only on a genuine docs-only PR"
}

# assert_matrix_from <job> <producer> <output> <key>: the job lists the
# producer in needs: and reads its matrix <key> from that job's JSON output
# instead of a literal list.
assert_matrix_from() {
  local job=$1 producer=$2 output=$3 key=$4 block
  block=$(job_block "$job" "$file")
  if ! grep -qE "^[[:space:]]*needs:[[:space:]]*\[([^]]*,)?[[:space:]]*${producer}[[:space:]]*(,[^]]*)?\][[:space:]]*$" <<<"$block"; then
    fail "job '$job' does not list '$producer' in needs:"
  fi
  if ! grep -qE "^[[:space:]]*${key}:[[:space:]]*\\\$\\{\\{[[:space:]]*fromJSON\\(needs\\.${producer}\\.outputs\\.${output}\\)[[:space:]]*\\}\\}[[:space:]]*$" <<<"$block"; then
    fail "job '$job' matrix $key is not fromJSON(needs.$producer.outputs.$output)"
  fi
  echo "check-workflow-docs-skip: ok - $job reads its matrix from the $producer job"
}

# assert_matrix_from_hosts <job> <output>: the job depends on the hosts job
# and reads its matrix from that job's JSON output instead of a literal host
# list (R19).
assert_matrix_from_hosts() {
  local job=$1 output=$2 block
  block=$(job_block "$job" "$file")
  if ! grep -qE '^[[:space:]]*needs:[[:space:]]*\[([^]]*,)?[[:space:]]*hosts[[:space:]]*(,[^]]*)?\][[:space:]]*$' <<<"$block"; then
    fail "job '$job' does not list 'hosts' in needs: (R19/KTD9)"
  fi
  if ! grep -qE "^[[:space:]]*target:[[:space:]]*\\\$\\{\\{[[:space:]]*fromJSON\\(needs\\.hosts\\.outputs\\.$output\\)[[:space:]]*\\}\\}[[:space:]]*\$" <<<"$block"; then
    fail "job '$job' matrix target is not fromJSON(needs.hosts.outputs.$output) (R19/KTD9)"
  fi
  echo "check-workflow-docs-skip: ok - $job reads its matrix from the hosts job (R19/KTD9)"
}

# assert_empty_list_fails <job>: the lister fails on an empty name list,
# because an empty matrix skips its consumer and leaves the run green with
# no evidence. The test, its failure exit, and the output write must appear
# in that order, so a lister that publishes before checking does not pass.
assert_empty_list_fails() {
  local job=$1 block
  block=$(job_block "$job" "$file" | grep -vE '^[[:space:]]*#')
  if ! awk '
    /^[[:space:]]*if \[ "\$names" = "\[\]" \]; then[[:space:]]*$/ { if (!seen_if) seen_if = NR }
    seen_if && !seen_exit && NR > seen_if && /^[[:space:]]*exit 1[[:space:]]*$/ { seen_exit = NR }
    !seen_exit && /GITHUB_OUTPUT/ { early = 1 }
    seen_exit && NR > seen_exit && /names=\$names.*GITHUB_OUTPUT/ { ok = 1 }
    END { exit !(ok && !early) }
  ' <<<"$block"; then
    fail "job '$job' does not fail on an empty name list before publishing it"
  fi
  echo "check-workflow-docs-skip: ok - $job fails on an empty name list"
}

# assert_ifd_realised_before_no_build: flake-check runs `nix flake check
# --no-build`, which refuses to build import-from-derivation sources, so a
# plain `nix eval` of the checks' drvPaths must run first. Without it the
# job fails on a fresh runner while passing on any machine whose store
# already holds those sources.
assert_ifd_realised_before_no_build() {
  local block
  block=$(job_block flake-check "$file" | grep -vE '^[[:space:]]*#')
  if ! awk '
    /^[[:space:]]*(run:[[:space:]]*)?nix eval .*\.#checks\.x86_64-linux .*drvPath/ { if (!seen_eval) seen_eval = NR }
    /^[[:space:]]*(run:[[:space:]]*)?nix flake check --no-build/ { if (seen_eval && NR > seen_eval) ok = 1; else early = 1 }
    END { exit !(ok && !early) }
  ' <<<"$block"; then
    fail "job 'flake-check' does not realise the checks' drvPaths before nix flake check --no-build"
  fi
  echo "check-workflow-docs-skip: ok - flake-check realises import-from-derivation sources before --no-build"
}

# assert_native_arm: build-linux sends aarch64 targets to the arm runner, so
# no aarch64 output is ever built under emulation (KTD13 in the non-NixOS
# hosts plan).
assert_native_arm() {
  local block expected
  block=$(job_block build-linux "$file")
  expected="runs-on: \${{ matrix.target.system == 'aarch64-linux' && 'ubuntu-24.04-arm' || 'ubuntu-24.04' }}"
  if ! grep -qF -- "$expected" <<<"$block"; then
    fail "job 'build-linux' does not route aarch64 targets to ubuntu-24.04-arm (KTD13)"
  fi
  echo "check-workflow-docs-skip: ok - build-linux builds aarch64 targets on the arm runner (KTD13)"
}

assert_gated flake-check
assert_ifd_realised_before_no_build
assert_gated hosts
assert_gated build list
assert_gated build-linux list
assert_matrix_from_hosts build targets
assert_matrix_from_hosts build-linux linux_targets
assert_native_arm
assert_gated check-shard-names
assert_gated check-shards list
assert_empty_list_fails check-shard-names
assert_matrix_from check-shards check-shard-names names name
assert_gated vm-check-names
assert_gated vm-checks list
assert_empty_list_fails vm-check-names
assert_matrix_from vm-checks vm-check-names names name
assert_unconditional fmt
assert_docs_only_only markdown-lint

echo "check-workflow-docs-skip: ok - all wiring assertions passed"
