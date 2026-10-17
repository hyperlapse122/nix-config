#!/usr/bin/env bash
# Drives the opencode wrapper against a stub OpenCode that records its argv
# and the environment it was given.
#
#   opencode.sh SCRIPT                      the source, placeholders rendered here
#   opencode.sh --packaged BIN TOKEN_FILE   a built copy, checked for its constants
set -euo pipefail

usage() {
  printf 'usage: %s SCRIPT | --packaged BIN TOKEN_FILE\n' "${0##*/}" >&2
  exit 2
}

mode=source
if [[ ${1:-} == --packaged ]]; then
  [[ $# -eq 3 ]] || usage
  mode=packaged
  target=$2
  want_token_file=$3
  [[ -n $want_token_file ]] || usage
else
  [[ $# -eq 1 ]] || usage
  target=$1
fi
[[ -f $target ]] || usage
target=$(cd -- "$(dirname -- "$target")" && pwd -P)/$(basename -- "$target")

fail() { printf 'opencode: FAIL (%s): %s\n' "$mode" "$*" >&2; exit 1; }
pass() { printf 'opencode: ok (%s) - %s\n' "$mode" "$*"; }

# --- packaging ---------------------------------------------------------------

# The packaged wrapper execs the real OpenCode, so it is checked for what the
# build substituted; the source run below covers its behaviour.
if [[ $mode == packaged ]]; then
  [[ -x $target ]] || fail "$target is not executable"
  if grep -qE '@[A-Z_]+@' "$target"; then
    fail "a placeholder survived in $target: $(grep -oE '@[A-Z_]+@' "$target" | head -n1)"
  fi
  shebang=$(head -n1 "$target")
  store=${NIX_STORE:-/nix/store}
  [[ $shebang == "#!$store/"*/bin/bash ]] || fail "shebang is not a store bash: $shebang"
  grep -qxF "TOKEN_FILE='$want_token_file'" "$target" ||
    fail "TOKEN_FILE is $(grep -m1 '^TOKEN_FILE=' "$target"), want '$want_token_file'"
  opencode=$(sed -nE "s/^OPENCODE='(.*)'$/\1/p" "$target")
  [[ $opencode == "$store/"* && -x $opencode ]] || fail "OPENCODE '$opencode' is not an executable store path"
  rg_bin=$(sed -nE "s/^RIPGREP_BIN='(.*)'$/\1/p" "$target")
  [[ -x $rg_bin/rg ]] || fail "RIPGREP_BIN '$rg_bin' holds no rg"
  pass 'the constants are substituted and point at the token file, OpenCode, and ripgrep'
  printf 'opencode: all checks passed (%s)\n' "$mode"
  exit 0
fi

scratch=$(mktemp -d "${TMPDIR:-/tmp}/opencode-tests.XXXXXX")
trap 'chmod -R u+rwx "$scratch" 2>/dev/null; rm -rf -- "$scratch"' EXIT

bash_bin=$(command -v bash) || fail 'bash is required'
token_file=$scratch/token
file_token=fake-opencode-key-123

rec=$scratch/rec
rg_dir=$scratch/rg-bin
home=$scratch/home
stub=$scratch/opencode-stub
mkdir -p "$rg_dir" "$home"

wrapper=$scratch/opencode
sed -e "s|@TOKEN_FILE@|$token_file|" -e "s|@OPENCODE@|$stub|" -e "s|@RIPGREP_BIN@|$rg_dir|" \
  -e "1s|.*|#!$bash_bin|" "$target" >"$wrapper"
chmod +x "$wrapper"

cat >"$stub" <<STUB
#!$bash_bin
# Builtins only: the wrapper may run with a PATH that holds nothing useful.
printf '%s\0' "\$@" >"$rec/argv"
printf '%s' "\$#" >"$rec/argc"
[[ -n \${OPENCODE_API_KEY+x} ]] && printf '%s' "\$OPENCODE_API_KEY" >"$rec/key"
for var in OPENCODE_DISABLE_AUTOUPDATE OPENCODE_DISABLE_PROJECT_CONFIG OPENCODE_CONFIG_PROJECT_DISABLE OPENCODE_DISABLE_CLAUDE_CODE PATH; do
  [[ -n \${!var+x} ]] && printf '%s' "\${!var}" >"$rec/\$var"
done
printf 'stub-opencode ran\n'
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
  set +e
  env -i HOME="$home" PATH=/caller/bin "${assigns[@]}" "$wrapper" "$@" \
    >"$scratch/stdout" 2>"$scratch/stderr"
  rc=$?
  set -e
}

stub_ran() { [[ -f $rec/argv ]]; }
recorded() { [[ -f $rec/$1 ]] && cat -- "$rec/$1"; }

set_token_file() {
  chmod -R u+rwx "$token_file" 2>/dev/null || true
  rm -rf -- "$token_file"
  if [[ $# -gt 0 ]]; then printf '%s' "$1" >"$token_file"; fi
}

# The key must reach OpenCode only through its environment.
assert_key_hidden() {
  local key=$1 f
  for f in "$rec/argv" "$scratch/stdout" "$scratch/stderr"; do
    if [[ -f $f ]] && grep -aqF -- "$key" "$f"; then
      fail "the key appeared in ${f##*/}"
    fi
  done
  if grep -raqF -- "$key" "$home"; then
    fail "the key was written under $home"
  fi
}

assert_switches() {
  local label=$1 var
  for var in OPENCODE_DISABLE_AUTOUPDATE OPENCODE_DISABLE_PROJECT_CONFIG OPENCODE_CONFIG_PROJECT_DISABLE OPENCODE_DISABLE_CLAUDE_CODE; do
    [[ $(recorded "$var") == true ]] || fail "$label: $var is '$(recorded "$var")', want 'true'"
  done
}

echo 0 >"$scratch/status"
set_token_file "$file_token"

# --- arguments and exit status ---------------------------------------------

echo 3 >"$scratch/status"
run run --model "opencode/a b" "two words"
stub_ran || fail 'the stub opencode never ran'
[[ $(recorded argc) == 4 ]] || fail "OpenCode got $(recorded argc) arguments, want 4"
mapfile -d '' argv <"$rec/argv"
expected=(run --model "opencode/a b" "two words")
[[ ${#argv[@]} -eq ${#expected[@]} ]] || fail "argv has ${#argv[@]} words: ${argv[*]}"
for i in "${!expected[@]}"; do
  [[ ${argv[i]} == "${expected[i]}" ]] || fail "argv[$i] is '${argv[i]}', want '${expected[i]}'"
done
[[ $rc -eq 3 ]] || fail "exit status $rc, want the stub's 3"
pass 'arguments reach OpenCode unchanged and the exit status is kept'
echo 0 >"$scratch/status"

run
[[ $(recorded argc) == 0 ]] || fail "a bare run passed $(recorded argc) words: $(tr '\0' ' ' <"$rec/argv")"
[[ $rc -eq 0 ]] || fail "a bare run exited $rc"
pass 'a bare run passes no arguments'

# --- switches and PATH -------------------------------------------------------

run
assert_switches 'default run'
run OPENCODE_DISABLE_AUTOUPDATE=false OPENCODE_DISABLE_PROJECT_CONFIG=0 OPENCODE_CONFIG_PROJECT_DISABLE=0 OPENCODE_DISABLE_CLAUDE_CODE=
assert_switches 'caller values'
pass 'the self-update, project-config, and Claude Code switches are always true'

run
[[ $(recorded PATH) == "$rg_dir:/caller/bin" ]] || fail "PATH is '$(recorded PATH)', want ripgrep first"
run PATH=
[[ $(recorded PATH) == "$rg_dir" ]] || fail "with an empty PATH it is '$(recorded PATH)'"
pass 'ripgrep is prepended to the caller PATH'

# --- key -------------------------------------------------------------------

run serve
[[ -f $rec/key ]] || fail 'the key file did not reach OPENCODE_API_KEY'
[[ $(recorded key) == "$file_token" ]] || fail 'OPENCODE_API_KEY is not the file key'
assert_key_hidden "$file_token"
pass 'the key file reaches OPENCODE_API_KEY and nowhere else'

run OPENCODE_API_KEY=caller-key serve
[[ $(recorded key) == caller-key ]] || fail 'the file key replaced the caller key'
assert_key_hidden "$file_token"
pass 'a caller-exported OPENCODE_API_KEY wins over the key file'

run OPENCODE_API_KEY= serve
[[ $(recorded key) == "$file_token" ]] || fail 'an empty caller key blocked the file key'
pass 'an empty caller OPENCODE_API_KEY falls back to the key file'

echo 4 >"$scratch/status"
check_no_key() {
  local label=$1
  run serve --port 1
  stub_ran || fail "$label: the stub did not run"
  [[ $rc -eq 4 ]] || fail "$label: exit status $rc, want the stub's 4"
  mapfile -d '' argv <"$rec/argv"
  [[ ${argv[*]} == 'serve --port 1' ]] || fail "$label: argv is '${argv[*]}'"
  if [[ -f $rec/key ]]; then
    fail "$label: OPENCODE_API_KEY was set to '$(recorded key)'"
  fi
  if [[ -n $(<"$scratch/stderr") ]]; then
    fail "$label: the wrapper printed to stderr: $(cat "$scratch/stderr")"
  fi
  assert_switches "$label"
  run OPENCODE_API_KEY= serve
  if [[ -f $rec/key ]]; then fail "$label: an empty caller key was passed on"; fi
}

set_token_file
check_no_key 'missing key file'
pass 'a missing key file runs without a key and keeps the exit status'

set_token_file ''
check_no_key 'empty key file'
set_token_file $'\n'
check_no_key 'newline-only key file'
pass 'an empty key file behaves like a missing one'

set_token_file 'fake key'
check_no_key 'key with a space'
set_token_file $'fake-key\nsecond-line'
check_no_key 'two-line key file'
set_token_file $'fake\x01key'
check_no_key 'key with a control character'
set_token_file "$(printf 'x%.0s' {1..8193})"
check_no_key 'oversize key file'
pass 'a whitespace-bearing, control-bearing, or oversize key file behaves like a missing one'

echo 0 >"$scratch/status"
longest=$(printf 'x%.0s' {1..8192})
set_token_file "$longest"
run serve
[[ $(recorded key) == "$longest" ]] || fail 'an 8192-character key was not accepted'
pass 'a key of exactly 8192 characters is accepted'

set_token_file $'fake-key-456\n'
run serve
[[ $(recorded key) == fake-key-456 ]] || fail 'a trailing newline was not stripped'
pass 'a trailing newline after the key is stripped'

echo 4 >"$scratch/status"
set_token_file "$file_token"
chmod 000 "$token_file"
if [[ -r $token_file ]]; then
  printf 'opencode: skip (%s) - running as a user that can read mode 000\n' "$mode"
else
  check_no_key 'unreadable key file'
  pass 'an unreadable key file behaves like a missing one'
fi

set_token_file
mkdir "$token_file"
check_no_key 'key path is a directory'
rmdir "$token_file"
pass 'a directory at the key path behaves like a missing file'

printf 'opencode: all checks passed (%s)\n' "$mode"
