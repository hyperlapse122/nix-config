#!/usr/bin/env bash
# Behavior checks for scripts/repo-clones. A fake ghq clones from local bare
# repositories, so the helper's own validation, skip, and cleanup rules are
# exercised without a network. tests/repo-clones.nix covers the real ghq over
# HTTPS inside a VM.
set -euo pipefail

script=${1:-}
if [[ $# -ne 1 || -z $script || ! -f $script ]]; then
  printf 'usage: %s REPO_CLONES_SCRIPT\n' "${0##*/}" >&2
  exit 2
fi
script=$(cd -- "$(dirname -- "$script")" && pwd -P)/$(basename -- "$script")

scratch=$(mktemp -d "${TMPDIR:-/tmp}/repo-clones-tests.XXXXXX")
trap 'rm -rf -- "$scratch"' EXIT

failures=0
fail() {
  printf 'repo-clones: FAIL: %s\n' "$*" >&2
  failures=$((failures + 1))
}
pass() { printf 'repo-clones: ok - %s\n' "$*"; }

git_bin=$(command -v git) || {
  printf 'git is required\n' >&2
  exit 1
}

# Tools the helper and the fake ghq need, without git, so a PATH made only of
# this directory proves the helper supplies git itself.
tools=$scratch/tools
mkdir -p "$tools"
for tool in bash dirname rm mkdir id cat env; do
  ln -s "$(command -v "$tool")" "$tools/$tool"
done

fixtures=$scratch/fixtures
ghq_log=$scratch/ghq.log

# Bare origins served as https://example.test/<path>. HEAD is pinned so a
# clone checks out main even though init.defaultBranch is unset here.
make_origin() {
  local path=$1 work
  work=$scratch/work/$path
  mkdir -p "$work" "$fixtures/$path.git"
  "$git_bin" init -q -b main "$work"
  printf '%s\n' "$path" >"$work/README"
  "$git_bin" -C "$work" add README
  "$git_bin" -C "$work" -c user.email=t@example.invalid -c user.name=Test \
    -c commit.gpgsign=false commit -qm init
  "$git_bin" init -q --bare "$fixtures/$path.git"
  "$git_bin" -C "$fixtures/$path.git" symbolic-ref HEAD refs/heads/main
  "$git_bin" -C "$work" push -q "$fixtures/$path.git" main
}
make_origin owner/alpha
make_origin owner/beta
make_origin group/sub/gamma

fake_ghq=$scratch/ghq
cat >"$fake_ghq" <<EOF
#!$(command -v bash)
# Records every call, then clones https://example.test/<path> from the local
# fixtures. A URL whose path contains "broken" leaves a partial directory and
# fails, as an interrupted clone would.
set -u
printf 'args=%s allow=%s\n' "\$*" "\${GIT_ALLOW_PROTOCOL-unset}" >>"$ghq_log"
command -v git >/dev/null || { printf 'fake ghq: git not on PATH\n' >&2; exit 3; }
url=\${@: -1}
rel=\${url#https://}
rel=\${rel%.git}
target=\$GHQ_ROOT/\$rel
case \$rel in
  *broken*)
    mkdir -p "\$target/.git"
    exit 1
    ;;
esac
repo=\${rel#example.test/}
mkdir -p "\$(dirname -- "\$target")"
# The fixture is a local path, which the helper's https-only policy forbids.
GIT_ALLOW_PROTOCOL=file git clone -q "$fixtures/\$repo.git" "\$target"
EOF
chmod +x "$fake_ghq"

rendered=$scratch/repo-clones
sed -e "s|@GIT@|$git_bin|" -e "s|@GHQ@|$fake_ghq|" "$script" >"$rendered"
chmod +x "$rendered"

new_home() {
  home=$scratch/home-$1
  mkdir -p "$home"
  : >"$ghq_log"
}

run() {
  local list=$1
  set +e
  env -i HOME="$home" PATH="$tools" REPO_CLONES_EUID=1000 \
    "$rendered" "$list" >"$scratch/stdout" 2>"$scratch/stderr"
  status=$?
  set -e
}

# --- happy path, skips, and cleanup -----------------------------------------
new_home main
mkdir -p "$home/src/example.test/owner/beta"
printf 'local work\n' >"$home/src/example.test/owner/beta/keep"
mkdir -p "$scratch/elsewhere"
ln -s "$scratch/elsewhere" "$home/src/example.test/owner/linked" 2>/dev/null ||
  { mkdir -p "$home/src/example.test/owner" && ln -s "$scratch/elsewhere" "$home/src/example.test/owner/linked"; }

list=$scratch/list-main
cat >"$list" <<'EOF'
# comment line

https://example.test/owner/alpha.git
git@example.test:owner/ssh.git
https://example.test/owner/broken
ssh://example.test/owner/ssh2.git
example.test/owner/noscheme
https://user:FAKE_TOKEN@example.test/owner/secret.git
http://user:FAKE_TOKEN@example.test/owner/plain.git
https://example.test/owner/beta
https://example.test/owner/linked
  https://example.test/group/sub/gamma/
EOF
run "$list"

[[ $status == 0 ]] && pass 'exits 0 with a failed entry' || fail "exit status $status, want 0"

if [[ -f $home/src/example.test/owner/alpha/README ]]; then
  pass 'clones a missing https entry with .git stripped'
else
  fail 'owner/alpha was not cloned at host/path'
fi
if [[ -f $home/src/example.test/group/sub/gamma/README ]]; then
  pass 'clones a nested path listed after a failure and a trailing slash'
else
  fail 'group/sub/gamma was not cloned'
fi

if [[ -e $home/src/example.test/owner/broken ]]; then
  fail 'failed clone left a directory behind'
else
  pass 'removes the directory a failed clone left'
fi
if grep -q 'failed to clone example.test/owner/broken' "$scratch/stderr"; then
  pass 'names the failed entry'
else
  fail 'failed entry not named on stderr'
fi

if [[ -f $home/src/example.test/owner/beta/keep && ! -e $home/src/example.test/owner/beta/README ]]; then
  pass 'leaves an existing target untouched'
else
  fail 'existing owner/beta target was modified'
fi
if [[ -L $home/src/example.test/owner/linked ]]; then
  pass 'treats a symlinked target as existing'
else
  fail 'symlinked target was replaced'
fi
if grep -q 'owner/beta\|owner/linked' "$ghq_log"; then
  fail 'ghq was called for an existing target'
else
  pass 'never calls ghq for an existing target'
fi

if grep -q 'ssh\|noscheme' "$ghq_log"; then
  fail 'ghq was called for a non-https entry'
else
  pass 'never calls ghq for ssh entries'
fi
# The scp form's user is redacted like any other userinfo.
if grep -q 'skipping <redacted>@example.test:owner/ssh.git' "$scratch/stderr" &&
  grep -q 'skipping ssh://example.test/owner/ssh2.git' "$scratch/stderr"; then
  pass 'warns about each non-https entry'
else
  fail 'non-https entries were not reported'
fi

if grep -q FAKE_TOKEN "$scratch/stdout" "$scratch/stderr"; then
  fail 'a credential reached the output'
else
  pass 'never prints embedded credentials'
fi
if grep -q 'secret\|plain' "$ghq_log"; then
  fail 'ghq was called for an entry with credentials'
else
  pass 'never calls ghq for an entry with credentials'
fi

if grep -q 'args=get --no-recursive https://example.test/owner/alpha.git allow=https' "$ghq_log"; then
  pass 'calls ghq get --no-recursive with only https allowed'
else
  fail "unexpected ghq call: $(cat "$ghq_log")"
fi
if grep -q 'git not on PATH' "$scratch/stderr"; then
  fail 'ghq could not find git on PATH'
else
  pass 'puts git on the PATH ghq sees'
fi

if grep -q '2 cloned, 2 already present, 5 skipped, 1 failed' "$scratch/stdout"; then
  pass 'prints the summary counts'
else
  fail "unexpected summary: $(cat "$scratch/stdout")"
fi

# --- idempotence ---------------------------------------------------------------
: >"$ghq_log"
run "$list"
if grep -q 'alpha\|gamma' "$ghq_log"; then
  fail 'second run cloned again'
else
  pass 'a second run clones nothing already present'
fi

# --- missing list ---------------------------------------------------------------
new_home missing
run "$scratch/no-such-list"
if [[ $status == 0 ]] && grep -q 'missing or unreadable' "$scratch/stderr" && [[ ! -e $home/src ]]; then
  pass 'a missing list exits 0 without cloning'
else
  fail "missing list: status $status"
fi

# --- root guard -----------------------------------------------------------------
new_home root
set +e
env -i HOME="$home" PATH="$tools" REPO_CLONES_EUID=0 "$rendered" "$list" >/dev/null 2>"$scratch/stderr"
status=$?
set -e
if [[ $status != 0 && ! -e $home/src ]] && grep -q 'refusing to run as root' "$scratch/stderr"; then
  pass 'refuses to run as root'
else
  fail "root guard: status $status"
fi

if [[ $failures -gt 0 ]]; then
  printf 'repo-clones: %d failure(s)\n' "$failures" >&2
  exit 1
fi
