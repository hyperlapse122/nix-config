#!/usr/bin/env bash
# Drives scripts/enroll-fingerprint with the reader and the authenticator both
# stubbed.
#
# The authenticator is reached through the build-time @PAMTESTER@ constant
# rather than an environment variable, so this harness renders its own copy of
# the source the way tests/nr.sh does. That distinction is the point of the
# "environment overrides cannot skip the password" assertion below: a rendered
# copy is a test artifact, while the installed binary carries a store path no
# environment variable can displace.
set -euo pipefail

script=${1:-}
if [[ $# -ne 1 || -z $script || ! -f $script ]]; then
  printf 'usage: %s ENROLL_FINGERPRINT_SCRIPT\n' "${0##*/}" >&2
  exit 2
fi
script=$(cd -- "$(dirname -- "$script")" && pwd -P)/$(basename -- "$script")

scratch=$(mktemp -d "${TMPDIR:-/tmp}/enroll-fingerprint-tests.XXXXXX")
trap 'rm -rf -- "$scratch"' EXIT

fail() { printf 'enroll-fingerprint: FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'enroll-fingerprint: ok - %s\n' "$*"; }

bin=$scratch/bin
mkdir -p "$bin"
calls=$scratch/calls

# Stubs record that they ran, so an assertion can prove a step was skipped
# rather than merely that the exit code looked right.
#
# The shebang names the bash running this harness rather than /usr/bin/env: the
# Nix build sandbox has no /usr/bin/env, and a stub that cannot execute reads
# exactly like the failure it is standing in for.
bash_bin=$(command -v bash) || fail 'bash is required'
make_stub() {
  local name=$1 status=$2 body=${3:-}
  {
    printf '#!%s\n' "$bash_bin"
    printf 'printf "%%s %%s\\n" %s "$*" >> %s\n' "$name" "$calls"
    printf '%s\n' "$body"
    printf 'exit %s\n' "$status"
  } >"$bin/$name"
  chmod +x "$bin/$name"
}

render() {
  local auth_status=$1 rendered=$scratch/enroll-fingerprint
  make_stub pamtester "$auth_status"
  sed -e "s|@PAMTESTER@|$bin/pamtester|" \
      -e "s|@FPRINTD_ENROLL@|/nonexistent/fprintd-enroll|" \
      -e "s|@FPRINTD_LIST@|/nonexistent/fprintd-list|" \
      "$script" >"$rendered"
  chmod +x "$rendered"
  printf '%s' "$rendered"
}

run() {
  : >"$calls"
  set +e
  ENROLL_FP_ENROLL=$bin/fprintd-enroll \
  ENROLL_FP_LIST=$bin/fprintd-list \
  ENROLL_FP_SUDO=$bin/sudo \
    "$@" >"$scratch/out" 2>"$scratch/err"
  status=$?
  set -e
}

# sudo is a pass-through so the enroll stub's own exit code is what surfaces.
make_stub sudo 0 'shift; exec "$@"'

# --- happy path ------------------------------------------------------------

rendered=$(render 0)
make_stub fprintd-list 0 'printf "Fingers enrolled for %s:\n" "$1"'
make_stub fprintd-enroll 0
run "$rendered"
[[ $status -eq 0 ]] || fail "happy path exited $status: $(cat "$scratch/err")"
grep -q 'enrolled right-index-finger' "$scratch/out" ||
  fail "happy path did not report the enrollment: $(cat "$scratch/out")"
pass 'a working reader and a correct password enroll the default finger'

# --- the password gate -----------------------------------------------------

rendered=$(render 1)
run "$rendered"
[[ $status -ne 0 ]] || fail 'a failed password authentication still exited 0'
grep -qF 'fprintd-enroll' "$calls" &&
  fail 'enrollment ran even though password authentication failed'
pass 'a failed password authentication enrolls nothing'

# Every environment override the script honours, set at once, must not reach
# the authenticator.
#
# The decoy must exist and succeed. Pointing it at something absent would make
# this pass whether or not the script honours the override, because a missing
# command fails the same way a refused password does -- the fixture would then
# be unable to tell the bug from the fix.
make_stub authenticator-decoy 0
rendered=$(render 1)
ENROLL_FP_PAMTESTER=$bin/authenticator-decoy PAMTESTER=$bin/authenticator-decoy run "$rendered"
[[ $status -ne 0 ]] || fail 'an environment override skipped the password demand'
grep -qF 'authenticator-decoy' "$calls" &&
  fail 'an environment override reached the authenticator'
grep -qF 'fprintd-enroll' "$calls" &&
  fail 'an environment override let enrollment run without the password'
pass 'no environment override can skip the password demand'

# --- absent reader vs failed capture ---------------------------------------

rendered=$(render 0)
make_stub fprintd-list 1
run "$rendered"
[[ $status -eq 3 ]] || fail "an absent reader exited $status, expected 3"
grep -qi 'no fingerprint reader' "$scratch/err" ||
  fail "the absent-reader message did not name the reader: $(cat "$scratch/err")"
grep -qF 'pamtester' "$calls" &&
  fail 'the password was demanded before the reader was found to be missing'
pass 'an absent reader exits 3, names the reader, and asks for no password'

make_stub fprintd-list 0 'printf "Fingers enrolled for %s:\n" "$1"'
make_stub fprintd-enroll 1
run "$rendered"
[[ $status -eq 4 ]] || fail "a failed capture exited $status, expected 4"
grep -qi 'capturing right-index-finger failed' "$scratch/err" ||
  fail "the failed-capture message was not distinct: $(cat "$scratch/err")"
pass 'a failed capture exits 4 with a message distinct from an absent reader'

# --- re-enrollment ---------------------------------------------------------

make_stub fprintd-list 0 'printf "Fingers enrolled for %s:\n - #0: right-index-finger\n" "$1"'
make_stub fprintd-enroll 0
run "$rendered"
[[ $status -eq 0 ]] || fail "re-enrollment exited $status"
grep -qi 'already enrolled; it will be replaced' "$scratch/err" ||
  fail "re-enrollment did not report replacement: $(cat "$scratch/err")"
pass 'enrolling an already-enrolled finger reports replacement, not a second record'

# --- refuses root ----------------------------------------------------------

if [[ $(id -u) -eq 0 ]]; then
  run "$rendered"
  [[ $status -ne 0 ]] || fail 'running as root was allowed'
  grep -qF 'pamtester' "$calls" && fail 'root reached the password step'
  pass 'running as root is refused'
else
  # id is resolved through PATH, so a stub proves the guard without root.
  make_stub id 0 'case "$*" in -u) echo 0 ;; -un) echo root ;; esac'
  : >"$calls"
  set +e
  PATH=$bin:$PATH "$rendered" >"$scratch/out" 2>"$scratch/err"
  status=$?
  set -e
  [[ $status -ne 0 ]] || fail 'running as root was allowed'
  grep -qi 'must not run as root' "$scratch/err" ||
    fail "the root refusal was not reported: $(cat "$scratch/err")"
  rm -f "$bin/id"
  pass 'running as root is refused'
fi

# --- usage -----------------------------------------------------------------

run "$rendered" --finger
[[ $status -eq 1 ]] || fail "a missing --finger value exited $status, expected 1"
run "$rendered" --nonsense
[[ $status -eq 2 ]] || fail "an unknown argument exited $status, expected 2"
pass 'argument errors exit 1 and 2 rather than proceeding'

printf 'enroll-fingerprint: all checks passed\n'
