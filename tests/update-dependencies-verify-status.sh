#!/usr/bin/env bash
#
# Check interface:
#
#   bash tests/update-dependencies-verify-status.sh <update-dependencies-workflow>
#
# Extracts the literal script of the "Verify updates" step from the given
# workflow file and runs it the way GitHub Actions runs a `run:` block
# (`bash -e`, no pipefail) against a stub `nix` on PATH. The step pipes each
# nix command through `tee`, so a status read from `$?` is tee's and always 0:
# a failing `nix flake check` then reports status=success and the next step
# pushes the unverified lock straight to main. Each scenario asserts the
# status the step writes to GITHUB_OUTPUT.

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

[[ -n $step_script ]] || fail "could not find the verify step's run block in $workflow"

scratch=$(mktemp -d "${TMPDIR:-/tmp}/update-dependencies-verify-status.XXXXXX")
trap 'rm -rf -- "$scratch"' EXIT

# A stub nix whose `fmt` and `flake check` exit with the status the scenario
# sets, after printing something for tee to copy.
mkdir -p "$scratch/bin"
bash_bin=$(command -v bash) || fail 'bash is required'
printf '#!%s\n' "$bash_bin" >"$scratch/bin/nix"
cat >>"$scratch/bin/nix" <<'EOF'
case $1 in
  fmt) echo 'stub nix fmt'; exit "${STUB_FMT_EXIT:?}" ;;
  flake) echo 'stub nix flake check'; exit "${STUB_CHECK_EXIT:?}" ;;
esac
exit 99
EOF
chmod +x "$scratch/bin/nix"

# Runs the step and prints the status it wrote to GITHUB_OUTPUT.
run_verify_step() {
  local fmt_exit=$1 check_exit=$2 dir
  dir=$(mktemp -d "$scratch/run.XXXXXX")
  : >"$dir/output"
  : >"$dir/summary"
  (
    cd "$dir"
    PATH="$scratch/bin:$PATH" STUB_FMT_EXIT=$fmt_exit STUB_CHECK_EXIT=$check_exit \
      GITHUB_OUTPUT="$dir/output" GITHUB_STEP_SUMMARY="$dir/summary" \
      bash -e -c "$step_script"
  ) >/dev/null || fail "the verify step itself exited non-zero (fmt=$fmt_exit check=$check_exit)"
  sed -n 's/^status=//p' "$dir/output"
}

status=$(run_verify_step 0 0)
[[ $status == success ]] || fail "passing fmt and check reported status=$status"
pass 'passing fmt and check report success'

status=$(run_verify_step 0 1)
[[ $status == failure ]] || fail "a failing nix flake check reported status=$status"
pass 'a failing nix flake check reports failure'

status=$(run_verify_step 1 0)
[[ $status == failure ]] || fail "a failing nix fmt reported status=$status"
pass 'a failing nix fmt reports failure'
