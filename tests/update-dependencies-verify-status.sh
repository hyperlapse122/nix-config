#!/usr/bin/env bash
#
# Check interface:
#
#   bash tests/update-dependencies-verify-status.sh <update-dependencies-workflow>
#
# Extracts the literal script of the "Verify updates" step and runs it the
# way GitHub runs an unspecified shell (`bash -e`, no pipefail) against a
# stubbed `nix`. The push step lands on main whenever this step reports
# status=success, so the status must follow every command it gates:
#
# - `nix fmt`, `nix flake check`, and the `.#vmChecks.all` build each fail in
#   turn, and each run must report status=failure. A step that reads `$?`
#   after `| tee` sees tee's status and reports success here, which is the
#   bug this check was written for. A step that stopped building the VM
#   tests, or stopped gating on them, reports success when only that build
#   fails.
# - all three succeed, and the run must report status=success.
# - a failing VM build must leave its log in vm-check.log, not check.log, so
#   the failure tail of `nix flake check` stays readable.

set -euo pipefail

workflow=${1:-}
if [[ $# -ne 1 || -z $workflow || ! -f $workflow ]]; then
  printf 'usage: %s WORKFLOW_FILE\n' "${0##*/}" >&2
  exit 2
fi

fail() { printf 'update-dependencies-verify-status: FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'update-dependencies-verify-status: ok - %s\n' "$*"; }

step_script=$(awk -v step="- name: Verify updates" '
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

[[ -n $step_script ]] || fail "could not find the Verify updates step's run block in $workflow"

scratch=$(mktemp -d "${TMPDIR:-/tmp}/update-dependencies-verify-status.XXXXXX")
trap 'rm -rf -- "$scratch"' EXIT

# run_step <failing>: runs the step with a stub `nix` that fails the named
# command (fmt, flake, build, or none) and prints the status it reported.
run_step() {
  local failing=$1 dir=$scratch/$1
  mkdir -p "$dir/bin"
  # The running bash, not /usr/bin/env: the Nix build sandbox has no env.
  cat >"$dir/bin/nix" <<EOF
#!$BASH
echo "stub nix \$*"
if [[ \$1 == "$failing" ]]; then
  echo "stub nix \$1 failed"
  exit 1
fi
exit 0
EOF
  chmod +x "$dir/bin/nix"
  : >"$dir/output"
  (
    cd "$dir"
    PATH=$dir/bin:$PATH GITHUB_OUTPUT=$dir/output GITHUB_STEP_SUMMARY=$dir/summary \
      bash -e -c "$step_script" >/dev/null 2>&1
  ) || fail "the step itself exited non-zero with $failing failing"
  grep -E '^status=' "$dir/output" || true
}

for failing in fmt flake build; do
  status=$(run_step "$failing")
  [[ $status == "status=failure" ]] ||
    fail "a failing nix $failing reported '$status', so the push step would land the update on main"
  pass "a failing nix $failing reports status=failure"
done

status=$(run_step none)
[[ $status == "status=success" ]] || fail "all commands succeeding reported '$status'"
pass 'all commands succeeding reports status=success'

grep -q 'stub nix build failed' "$scratch/build/vm-check.log" 2>/dev/null ||
  fail 'the VM build log is not in vm-check.log'
if grep -q 'stub nix build' "$scratch/build/check.log"; then
  fail 'the VM build log was written into check.log, burying the nix flake check tail'
fi
pass 'the VM build log goes to vm-check.log, not check.log'
