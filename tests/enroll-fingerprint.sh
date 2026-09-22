#!/usr/bin/env bash
# Drives scripts/enroll-fingerprint with every external command stubbed.
#
# The script carries build-time constants and no environment fallbacks, so this
# harness renders its own copy the way tests/nr.sh does. That is the point of
# the shape: the installed helper's authenticator and escalation target are
# store paths nothing in the environment can displace, and the assertion below
# proves no ENROLL_FP_* variable changes anything.
#
# Every block asserts that the step it is about actually ran, not only that the
# exit code looked right. A stub that cannot execute fails the same way a stub
# that ran and reported failure does, so an exit code alone cannot tell the two
# apart -- and a fixture that cannot tell them apart cannot tell a bug from its
# fix.
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
user=$(id -un)

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

ran() { grep -qF "$1" "$calls"; }

# Renders every constant, so the copy under test reaches only stubs.
render() {
  local auth_status=$1 rendered=$scratch/enroll-fingerprint
  make_stub pamtester "$auth_status"
  sed -e "s|@PAMTESTER@|$bin/pamtester|" \
      -e "s|@FPRINTD_ENROLL@|$bin/fprintd-enroll|" \
      -e "s|@FPRINTD_LIST@|$bin/fprintd-list|" \
      -e "s|@SUDO@|$bin/sudo|" \
      "$script" >"$rendered"
  chmod +x "$rendered"
  printf '%s' "$rendered"
}

run() {
  : >"$calls"
  set +e
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

# The service the helper authenticates against is half the design: a helper
# that prompted against polkit-1 would be authenticating through a stack that
# carries the fingerprint, so one finger would mint another.
grep -qxF "pamtester enroll-fingerprint $user authenticate" "$calls" ||
  fail "the helper did not authenticate against enroll-fingerprint: $(cat "$calls")"
pass 'the password is demanded against the fingerprint-free enroll-fingerprint service'

# The script makes ordering deliberate: the reader is probed before the
# password is asked for, and enrollment happens only after both.
order=$(cut -d' ' -f1 "$calls" | tr '\n' ' ')
[[ $order == "fprintd-list fprintd-list pamtester sudo fprintd-enroll "* ]] ||
  fail "steps ran out of order: $order"
pass 'the reader is probed, then the password demanded, then the finger captured'

# --- the password gate -----------------------------------------------------

rendered=$(render 1)
run "$rendered"
[[ $status -ne 0 ]] || fail 'a failed password authentication still exited 0'
ran 'pamtester' || fail 'the authenticator was never reached'
! ran 'fprintd-enroll' || fail 'enrollment ran even though password authentication failed'
pass 'a failed password authentication is reached, and enrolls nothing'

# Every ENROLL_FP_* name the earlier design honoured, set at once. The decoy
# must exist and succeed: pointing it at something absent would make this pass
# whether or not the script honours an override, because a missing command
# fails the same way a refused password does.
make_stub authenticator-decoy 0
rendered=$(render 1)
ENROLL_FP_PAMTESTER=$bin/authenticator-decoy \
PAMTESTER=$bin/authenticator-decoy \
ENROLL_FP_ENROLL=$bin/authenticator-decoy \
ENROLL_FP_LIST=$bin/authenticator-decoy \
ENROLL_FP_SUDO=$bin/authenticator-decoy \
  run "$rendered"
[[ $status -ne 0 ]] || fail 'an environment override skipped the password demand'
! ran 'authenticator-decoy' || fail 'an environment override displaced a build-time constant'
ran 'pamtester' || fail 'the real authenticator was not reached'
pass 'no environment variable displaces a build-time constant'

# --- absent reader vs failed capture ---------------------------------------

rendered=$(render 0)
make_stub fprintd-list 1
run "$rendered"
[[ $status -eq 3 ]] || fail "an absent reader exited $status, expected 3"
ran 'fprintd-list' || fail 'the reader probe never ran'
grep -qi 'no fingerprint reader' "$scratch/err" ||
  fail "the absent-reader message did not name the reader: $(cat "$scratch/err")"
! ran 'pamtester' || fail 'the password was demanded before the reader was found to be missing'
pass 'an absent reader is probed, exits 3, and asks for no password'

make_stub fprintd-list 0 'printf "Fingers enrolled for %s:\n" "$1"'
make_stub fprintd-enroll 1
run "$rendered"
[[ $status -eq 4 ]] || fail "a failed capture exited $status, expected 4"
ran 'fprintd-enroll' || fail 'the capture step never ran, so exit 4 proves nothing'
grep -qi 'capturing right-index-finger failed' "$scratch/err" ||
  fail "the failed-capture message was not distinct: $(cat "$scratch/err")"
pass 'a failed capture actually ran, exits 4, and reads differently from an absent reader'

# --- re-enrollment ---------------------------------------------------------

make_stub fprintd-list 0 'printf "Fingers enrolled for %s:\n - #0: right-index-finger\n" "$1"'
make_stub fprintd-enroll 0
run "$rendered"
[[ $status -eq 0 ]] || fail "re-enrollment exited $status"
grep -qi 'already enrolled; it will be replaced' "$scratch/err" ||
  fail "re-enrollment did not report replacement: $(cat "$scratch/err")"
pass 'enrolling an already-enrolled finger reports replacement, not a second record'

# --- refuses root ----------------------------------------------------------

make_stub id 0 'case "$*" in -u) echo 0 ;; -un) echo root ;; esac'
: >"$calls"
set +e
PATH=$bin:$PATH "$rendered" >"$scratch/out" 2>"$scratch/err"
status=$?
set -e
[[ $status -ne 0 ]] || fail 'running as root was allowed'
grep -qi 'must not run as root' "$scratch/err" ||
  fail "the root refusal was not reported: $(cat "$scratch/err")"
! ran 'pamtester' || fail 'root reached the password step'
rm -f "$bin/id"
pass 'running as root is refused before anything else runs'

# --- usage -----------------------------------------------------------------

run "$rendered" --finger
[[ $status -eq 1 ]] || fail "a missing --finger value exited $status, expected 1"
run "$rendered" --nonsense
[[ $status -eq 2 ]] || fail "an unknown argument exited $status, expected 2"
pass 'argument errors exit 1 and 2 rather than proceeding'

printf 'enroll-fingerprint: all checks passed\n'
