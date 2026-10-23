#!/usr/bin/env bash
# Drives the pi wrapper against a stub Pi that records its argv and its whole
# environment, and the pi-synthetic-key and pi-openrouter-key helpers against
# key files.
#
#   pi.sh WRAPPER KEY_HELPER    the sources, placeholders rendered here
#   pi.sh --packaged BINDIR SYNTHETIC_KEY_FILE EXA_KEY_FILE OPENROUTER_KEY_FILE
#                               a built copy, checked for its constants, then
#                               run like the sources with Pi and every key
#                               file retargeted into a scratch directory
set -euo pipefail

usage() {
  printf 'usage: %s WRAPPER KEY_HELPER | --packaged BINDIR SYNTHETIC_KEY_FILE EXA_KEY_FILE OPENROUTER_KEY_FILE\n' "${0##*/}" >&2
  exit 2
}

absolute() { printf '%s/%s' "$(cd -- "$(dirname -- "$1")" && pwd -P)" "$(basename -- "$1")"; }

mode=source
if [[ ${1:-} == --packaged ]]; then
  [[ $# -eq 5 && -d $2 && -n $3 && -n $4 && -n $5 ]] || usage
  mode=packaged
  bindir=$2
  want_key_file=$3
  want_exa_file=$4
  want_openrouter_file=$5
else
  [[ $# -eq 2 && -f $1 && -f $2 ]] || usage
  wrapper_src=$(absolute "$1")
  helper_src=$(absolute "$2")
fi

fail() { printf 'pi: FAIL (%s): %s\n' "$mode" "$*" >&2; exit 1; }
pass() { printf 'pi: ok (%s) - %s\n' "$mode" "$*"; }

# --- packaging ---------------------------------------------------------------

# The packaged wrapper execs the real Pi, so it is checked for what the build
# substituted here, and the run below drives a copy whose Pi and key-file
# paths point into the scratch directory.
if [[ $mode == packaged ]]; then
  store=${NIX_STORE:-/nix/store}
  for name in pi pi-synthetic-key pi-openrouter-key; do
    f=$bindir/$name
    [[ -x $f ]] || fail "$f is not executable"
    if grep -qE '@[A-Z_]+@' "$f"; then
      fail "a placeholder survived in $f: $(grep -oE '@[A-Z_]+@' "$f" | head -n1)"
    fi
    shebang=$(head -n1 "$f")
    [[ $shebang == "#!$store/"*/bin/bash ]] || fail "$name's shebang is not a store bash: $shebang"
  done
  pi=$(sed -nE "s/^PI='(.*)'$/\1/p" "$bindir/pi")
  [[ $pi == "$store/"* && -x $pi ]] || fail "PI '$pi' is not an executable store path"
  for spec in "pi-synthetic-key SYNTHETIC_API_KEY $want_key_file" \
    "pi-openrouter-key OPENROUTER_API_KEY $want_openrouter_file"; do
    read -r name var file <<<"$spec"
    grep -qxF "KEY_VAR='$var'" "$bindir/$name" ||
      fail "$name's KEY_VAR is $(grep -m1 '^KEY_VAR=' "$bindir/$name"), want '$var'"
    grep -qxF "KEY_FILE='$file'" "$bindir/$name" ||
      fail "$name's KEY_FILE is $(grep -m1 '^KEY_FILE=' "$bindir/$name"), want '$file'"
    [[ -z $(env -i "$bindir/$name") ]] || fail "$name printed a key from a missing key file"
    [[ $(env -i "$var=caller-key" "$bindir/$name") == caller-key ]] ||
      fail "$name did not print the caller key"
  done
  pass 'the constants are substituted and point at Pi and each key file'
fi

scratch=$(mktemp -d "${TMPDIR:-/tmp}/pi-tests.XXXXXX")
trap 'chmod -R u+rwx "$scratch" 2>/dev/null; rm -rf -- "$scratch"' EXIT

bash_bin=$(command -v bash) || fail 'bash is required'
env_bin=$(command -v env) || fail 'env is required'
synthetic_file=$scratch/keys/synthetic_api_key
exa_file=$scratch/keys/exa_api_key
openrouter_file=$scratch/keys/openrouter_api_key
synthetic_key=fake-synthetic-key-123
exa_key=fake-exa-key-456
openrouter_key=fake-openrouter-key-789
mkdir -p "$scratch/keys"

rec=$scratch/rec
home=$scratch/home
stub=$scratch/pi-stub
mkdir -p "$home"

# Both scripts get every placeholder, or in a built copy every constant, the
# build could substitute: a wrapper changed to read a key file reads the
# scratch one holding a key, and the checks below see it.
wrapper=$scratch/pi
synthetic_helper=$scratch/pi-synthetic-key
openrouter_helper=$scratch/pi-openrouter-key
if [[ $mode == packaged ]]; then
  for name in pi pi-synthetic-key pi-openrouter-key; do
    sed -e "s|^PI='.*'\$|PI='$stub'|" -e "s|$want_key_file|$synthetic_file|g" \
      -e "s|$want_exa_file|$exa_file|g" -e "s|$want_openrouter_file|$openrouter_file|g" \
      -e "s|$bindir/|$scratch/|g" "$bindir/$name" >"$scratch/$name"
  done
  grep -qxF "PI='$stub'" "$wrapper" || fail 'could not point the packaged wrapper copy at the stub'
else
  sed -e "s|@PI@|$stub|" -e "s|@SYNTHETIC_KEY_FILE@|$synthetic_file|g" \
    -e "s|@EXA_KEY_FILE@|$exa_file|g" -e "s|@OPENROUTER_KEY_FILE@|$openrouter_file|g" \
    -e "1s|.*|#!$bash_bin|" "$wrapper_src" >"$wrapper"
  for spec in "synthetic_helper SYNTHETIC_API_KEY $synthetic_file" \
    "openrouter_helper OPENROUTER_API_KEY $openrouter_file"; do
    read -r dst_var var file <<<"$spec"
    sed -e "s|@KEY_VAR@|$var|g" -e "s|@KEY_FILE@|$file|g" \
      -e "1s|.*|#!$bash_bin|" "$helper_src" >"${!dst_var}"
  done
fi
chmod +x "$wrapper" "$synthetic_helper" "$openrouter_helper"

cat >"$stub" <<STUB
#!$bash_bin
# The wrapper may run with a PATH that holds nothing useful, so env is
# called by its absolute path.
printf '%s\0' "\$@" >"$rec/argv"
printf '%s' "\$#" >"$rec/argc"
"$env_bin" -0 >"$rec/env"
printf 'stub-pi ran\n'
exit "\$(<"$scratch/status")"
STUB
chmod +x "$stub"

# run [VAR=value ...] ARGS... -- runs the wrapper in a clean environment and
# leaves its status in $rc and its output in $scratch/stdout and stderr.
run() {
  local -a assigns=()
  while [[ $# -gt 0 && $1 == *=* && $1 != -* ]]; do
    assigns+=("$1")
    shift
  done
  rm -rf -- "$rec"
  mkdir -p "$rec"
  : >"$rec/env"
  set +e
  env -i HOME="$home" PATH=/caller/bin "${assigns[@]}" "$wrapper" "$@" \
    >"$scratch/stdout" 2>"$scratch/stderr"
  rc=$?
  set -e
}

stub_ran() { [[ -f $rec/argv ]]; }
# The value the stub saw for one variable, or nonzero status when unset.
recorded() {
  local entry
  while IFS= read -r -d '' entry; do
    if [[ ${entry%%=*} == "$1" ]]; then
      printf '%s' "${entry#*=}"
      return 0
    fi
  done <"$rec/env"
  return 1
}

use_helper() {
  case $1 in
    pi-synthetic-key) helper=$synthetic_helper key_var=SYNTHETIC_API_KEY key_file=$synthetic_file ;;
    pi-openrouter-key) helper=$openrouter_helper key_var=OPENROUTER_API_KEY key_file=$openrouter_file ;;
  esac
  helper_name=$1
}

# Leaves the key helper's stdout in $out and its status in $rc.
helper() {
  set +e
  out=$(env -i HOME="$home" PATH=/caller/bin "$@" "$helper" 2>"$scratch/helper-stderr")
  rc=$?
  set -e
  [[ $rc -eq 0 ]] || fail "$helper_name exited $rc"
  [[ ! -s $scratch/helper-stderr ]] || fail "$helper_name printed to stderr: $(cat "$scratch/helper-stderr")"
}

set_key_file() {
  chmod -R u+rwx "$key_file" 2>/dev/null || true
  rm -rf -- "$key_file"
  if [[ $# -gt 0 ]]; then printf '%s' "$1" >"$key_file"; fi
}

key_files=("$synthetic_file" "$exa_file" "$openrouter_file")
fingerprint() { stat -c '%s %Y.%y' -- "${key_files[@]}" && cat -- "${key_files[@]}"; }

echo 0 >"$scratch/status"

# --- arguments, exit status, and switches ------------------------------------

echo 3 >"$scratch/status"
run --mode rpc --model "synthetic/a b" "two words"
stub_ran || fail 'the stub pi never ran'
mapfile -d '' argv <"$rec/argv"
expected=(--mode rpc --model "synthetic/a b" "two words")
[[ ${#argv[@]} -eq ${#expected[@]} ]] || fail "argv has ${#argv[@]} words: ${argv[*]}"
for i in "${!expected[@]}"; do
  [[ ${argv[i]} == "${expected[i]}" ]] || fail "argv[$i] is '${argv[i]}', want '${expected[i]}'"
done
[[ $rc -eq 3 ]] || fail "exit status $rc, want the stub's 3"
pass 'arguments, --mode rpc included, reach Pi unchanged and the exit status is kept'
echo 0 >"$scratch/status"

run
[[ $(<"$rec/argc") == 0 ]] || fail "a bare run passed $(<"$rec/argc") words"
pass 'a bare run passes no arguments'

for assigns in '' 'PI_SKIP_VERSION_CHECK=0 PI_TELEMETRY=1'; do
  # shellcheck disable=SC2086
  run $assigns
  [[ $(recorded PI_SKIP_VERSION_CHECK) == 1 ]] ||
    fail "PI_SKIP_VERSION_CHECK is '$(recorded PI_SKIP_VERSION_CHECK)' with '${assigns:-no caller values}'"
  [[ $(recorded PI_TELEMETRY) == 0 ]] ||
    fail "PI_TELEMETRY is '$(recorded PI_TELEMETRY)' with '${assigns:-no caller values}'"
done
[[ $(recorded PATH) == /caller/bin ]] || fail "PATH is '$(recorded PATH)', want the caller's"
pass 'PI_SKIP_VERSION_CHECK=1 and PI_TELEMETRY=0 hold over caller values, and PATH is the caller'"'"'s'

# --- keys stay out of the environment ----------------------------------------

printf '%s\n' "$synthetic_key" >"$synthetic_file"
printf '%s\n' "$exa_key" >"$exa_file"
printf '%s\n' "$openrouter_key" >"$openrouter_file"
chmod 0400 "${key_files[@]}"
touch -d '2001-02-03 04:05:06' "${key_files[@]}"
before=$(fingerprint)
run --mode rpc
stub_ran || fail 'the stub did not run with every key file present'
for var in SYNTHETIC_API_KEY EXA_API_KEY OPENROUTER_API_KEY; do
  if recorded "$var" >/dev/null; then fail "Pi's environment holds $var"; fi
done
for needle in "$synthetic_key" "$exa_key" "$openrouter_key" "${key_files[@]}" "$scratch/keys"; do
  if grep -aqF -- "$needle" "$rec/env" "$rec/argv" "$scratch/stdout" "$scratch/stderr"; then
    fail "'$needle' reached Pi's environment, argv, or the wrapper's output"
  fi
done
# A variable naming any key or key file is caught by its name or its value
# as well, whatever path or name a changed wrapper would use.
while IFS= read -r -d '' entry; do
  name=${entry%%=*} value=${entry#*=}
  if [[ $name == *KEY* || $value == *_api_key* ]]; then fail "Pi's environment holds $name='$value'"; fi
done <"$rec/env"
if grep -raqF -e "$synthetic_key" -e "$exa_key" -e "$openrouter_key" "$home"; then fail "a key was written under $home"; fi
[[ $(fingerprint) == "$before" ]] || fail 'a key file changed'
pass 'with every key file present, Pi sees no key nor a variable naming a key file, and no file changes'

# A key the caller exported is the documented way to test another account:
# it passes through to Pi unchanged, and the helper Pi runs with that
# environment prints it instead of the file key.
run SYNTHETIC_API_KEY=caller-synthetic-key EXA_API_KEY=caller-exa-key \
  OPENROUTER_API_KEY=caller-openrouter-key --mode rpc
for spec in SYNTHETIC_API_KEY=caller-synthetic-key EXA_API_KEY=caller-exa-key \
  OPENROUTER_API_KEY=caller-openrouter-key; do
  var=${spec%%=*}
  [[ $(recorded "$var") == "${spec#*=}" ]] ||
    fail "an exported $var reached Pi as '$(recorded "$var" || echo unset)'"
done
for needle in "$synthetic_key" "$exa_key" "$openrouter_key" "${key_files[@]}"; do
  if grep -aqF -- "$needle" "$rec/env"; then fail "'$needle' reached Pi's environment beside an exported key"; fi
done
for name in pi-synthetic-key pi-openrouter-key; do
  use_helper "$name"
  exported=$(recorded "$key_var")
  helper "$key_var=$exported"
  [[ $out == "$exported" ]] || fail "$name under Pi's environment printed '$out', want the exported key"
done
pass 'an exported key reaches Pi unchanged and wins in its helper, and no file key joins it'

chmod u+w "${key_files[@]}"
rm -f -- "${key_files[@]}"
echo 4 >"$scratch/status"
run --mode rpc
stub_ran || fail 'the stub did not run with no key files'
[[ $rc -eq 4 ]] || fail "exit status $rc with no key files, want the stub's 4"
[[ ! -s $scratch/stderr ]] || fail "the wrapper printed to stderr: $(cat "$scratch/stderr")"
pass 'with no key files, Pi still runs and stderr is empty'
echo 0 >"$scratch/status"

check_no_key() {
  helper
  [[ -z $out ]] || fail "$1: $helper_name printed '$out'"
}

# Both helpers follow one set of rules, each for its own variable and file.
for name in pi-synthetic-key pi-openrouter-key; do
  use_helper "$name"
  set_key_file "$synthetic_key"
  helper
  [[ $out == "$synthetic_key" ]] || fail "$helper_name printed '$out', want the file key"
  set_key_file $'fake-key-789\n'
  helper
  [[ $out == fake-key-789 ]] || fail "$helper_name: a trailing newline was not stripped: '$out'"
  pass "$helper_name prints the key file's contents"

  set_key_file "$synthetic_key"
  helper "$key_var=caller-key"
  [[ $out == caller-key ]] || fail "$helper_name printed '$out', want the caller key"
  helper "$key_var="
  [[ $out == "$synthetic_key" ]] || fail "$helper_name: an empty caller key blocked the file key"
  pass "$helper_name: a caller-exported $key_var wins, and an empty one falls back to the file"

  set_key_file
  check_no_key 'missing key file'
  set_key_file ''
  check_no_key 'empty key file'
  set_key_file 'fake key'
  check_no_key 'key with a space'
  set_key_file $'fake-key\nsecond-line'
  check_no_key 'two-line key file'
  set_key_file $'fake\x01key'
  check_no_key 'key with a control character'
  set_key_file "$(printf 'x%.0s' {1..8193})"
  check_no_key 'oversize key file'
  set_key_file
  mkdir "$key_file"
  check_no_key 'key path is a directory'
  rmdir "$key_file"
  pass "$helper_name: a missing, empty, whitespace-bearing, control-bearing, oversize, or directory key file prints nothing"

  longest=$(printf 'x%.0s' {1..8192})
  set_key_file "$longest"
  helper
  [[ $out == "$longest" ]] || fail "$helper_name: an 8192-character key was not accepted"
  pass "$helper_name accepts a key of exactly 8192 characters"
done

printf 'pi: all checks passed (%s)\n' "$mode"
