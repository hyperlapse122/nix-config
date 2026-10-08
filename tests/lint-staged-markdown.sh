#!/usr/bin/env bash
#
# Check interface:
#
#   bash tests/lint-staged-markdown.sh <script> <hook> <config> <toml_version> <lock_version> <nixpkgs_version> <task_run>
#
# Verifies scripts/lint-staged-markdown, .githooks/pre-commit, the run command
# of the mise task lint-staged-markdown (<task_run>, relative to the directory
# holding scripts/), and that the mise.toml and mise.lock markdownlint-cli2 pins
# equal the nixpkgs version.
set -euo pipefail

if [[ $# -ne 7 ]]; then
  printf "usage: %s SCRIPT HOOK CONFIG TOML_VER LOCK_VER NIXPKGS_VER TASK_RUN\n" "${0##*/}" >&2
  exit 2
fi
abspath() { printf "%s/%s\n" "$(cd "$(dirname "$1")" && pwd)" "$(basename "$1")"; }
script=$(abspath "$1")
hook=$(abspath "$2")
config=$(abspath "$3")
toml_version=$4
lock_version=$5
nixpkgs_version=$6
task_run=$7

fail() { printf "lint-staged-markdown: FAIL: %s\n" "$*" >&2; exit 1; }
pass() { printf "lint-staged-markdown: ok - %s\n" "$*"; }

assert_version_parity() {
  local toml_ver=$1
  local lock_ver=$2
  local nixpkgs_ver=$3

  if [[ -z "$toml_ver" || -z "$lock_ver" || -z "$nixpkgs_ver" ]]; then
    fail "version parity: missing version input (toml='$toml_ver', lock='$lock_ver', nixpkgs='$nixpkgs_ver')"
  fi

  if [[ "$toml_ver" != "$nixpkgs_ver" ]]; then
    fail "version parity mismatch: mise.toml pins npm:markdownlint-cli2 at '$toml_ver', but nixpkgs markdownlint-cli2 is '$nixpkgs_ver'"
  fi

  if [[ "$lock_ver" != "$nixpkgs_ver" ]]; then
    fail "version parity mismatch: mise.lock pins npm:markdownlint-cli2 at '$lock_ver', but nixpkgs markdownlint-cli2 is '$nixpkgs_ver'"
  fi
}

assert_version_parity "$toml_version" "$lock_version" "$nixpkgs_version"
pass "version parity holds (mise.toml=$toml_version, mise.lock=$lock_version, nixpkgs=$nixpkgs_version)"

# The parity assertion must reject each mismatched input.
if (assert_version_parity "0.0.1" "$lock_version" "$nixpkgs_version") 2>/dev/null; then
  fail "version parity assertion did not fail on mismatched toml version"
fi
if (assert_version_parity "$toml_version" "0.0.1" "$nixpkgs_version") 2>/dev/null; then
  fail "version parity assertion did not fail on mismatched lock version"
fi
if (assert_version_parity "$toml_version" "$lock_version" "0.0.1") 2>/dev/null; then
  fail "version parity assertion did not fail on mismatched nixpkgs version"
fi
pass "version parity assertion fails on mismatched version inputs"

# Setup isolated test environment
TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

export HOME="$TEST_TMPDIR/home"
mkdir -p "$HOME"

export GIT_AUTHOR_NAME="Test Author"
export GIT_AUTHOR_EMAIL="author@example.com"
export GIT_COMMITTER_NAME="Test Committer"
export GIT_COMMITTER_EMAIL="committer@example.com"

export GIT_CONFIG_GLOBAL="$TEST_TMPDIR/gitconfig"
cat > "$GIT_CONFIG_GLOBAL" <<EOF
[init]
    defaultBranch = main
[user]
    name = Test Author
    email = author@example.com
EOF

make_test_repo() {
  local repo_dir=$1
  mkdir -p "$repo_dir"
  git -C "$repo_dir" init -q
  cp "$config" "$repo_dir/.markdownlint-cli2.jsonc"
  git -C "$repo_dir" add .markdownlint-cli2.jsonc
  git -C "$repo_dir" commit -q -m "initial commit"
}

bad_md_content=$'# Title\n\nSome text\n- item 1\n- item 2\n'
clean_md_content=$'# Title\n\nSome text.\n\n- item 1\n- item 2\n'

# Scenario: Staged docs/bad.md with MD032 exits non-zero and outputs docs/bad.md, line number, MD032
repo1="$TEST_TMPDIR/repo1"
make_test_repo "$repo1"
mkdir -p "$repo1/docs"
printf "%s" "$bad_md_content" > "$repo1/docs/bad.md"
git -C "$repo1" add docs/bad.md
status=0
out=$( (cd "$repo1" && bash "$script") 2>&1 ) || status=$?
[[ $status -ne 0 ]] || fail "staged bad markdown exited 0"
[[ $out == *"docs/bad.md"* ]] || fail "staged bad markdown output missing filename"
[[ $out =~ docs/bad\.md:[0-9]+ ]] || fail "staged bad markdown output missing line number"
[[ $out == *"MD032"* ]] || fail "staged bad markdown output missing MD032"
[[ $out == *"mise exec -- markdownlint-cli2 --no-globs --fix <file>"* ]] || fail "staged bad markdown missing fix instructions"
[[ $out == *"git commit --no-verify"* ]] || fail "staged bad markdown missing no-verify instructions"
pass "staged docs/bad.md exits non-zero and reports file, line number, and MD032"

# Scenario: Staged clean docs/ok.md exits 0
repo2="$TEST_TMPDIR/repo2"
make_test_repo "$repo2"
mkdir -p "$repo2/docs"
printf "%s" "$clean_md_content" > "$repo2/docs/ok.md"
git -C "$repo2" add docs/ok.md
(cd "$repo2" && bash "$script") || fail "staged clean docs/ok.md failed"
pass "staged clean docs/ok.md exits 0"

# Scenario: Commit staging only flake.nix exits 0 without running markdownlint-cli2 (proven by stub)
repo3="$TEST_TMPDIR/repo3"
make_test_repo "$repo3"
touch "$repo3/flake.nix"
git -C "$repo3" add flake.nix
stub_dir="$TEST_TMPDIR/failing_lint_bin"
mkdir -p "$stub_dir"
cat > "$stub_dir/markdownlint-cli2" <<'STUB_EOF'
#!/bin/sh
echo "FAIL_STUB_CALLED" >&2
exit 99
STUB_EOF
chmod +x "$stub_dir/markdownlint-cli2"
(cd "$repo3" && PATH="$stub_dir:$PATH" bash "$script") || fail "staging non-markdown called markdownlint-cli2"
pass "staging only flake.nix exits 0 without running markdownlint-cli2"

# Scenario: Staged secrets/bad.md with error exits 0 because outside globs
repo4="$TEST_TMPDIR/repo4"
make_test_repo "$repo4"
mkdir -p "$repo4/secrets"
printf "%s" "$bad_md_content" > "$repo4/secrets/bad.md"
git -C "$repo4" add secrets/bad.md
(cd "$repo4" && bash "$script") || fail "secrets/bad.md outside globs failed"
pass "staged secrets/bad.md exits 0 (outside config globs)"

# Scenario: Staged root README.md with error and .compound-engineering/artifacts/plans/bad.md with error each exit non-zero
repo5="$TEST_TMPDIR/repo5"
make_test_repo "$repo5"
printf "%s" "$bad_md_content" > "$repo5/README.md"
git -C "$repo5" add README.md
status=0
out=$( (cd "$repo5" && bash "$script") 2>&1 ) || status=$?
[[ $status -ne 0 ]] || fail "root README.md with error exited 0"
[[ $out == *"README.md"* && $out == *"MD032"* ]] || fail "root README.md error output incorrect"

mkdir -p "$repo5/.compound-engineering/artifacts/plans"
git -C "$repo5" rm -q -f README.md
printf "%s" "$bad_md_content" > "$repo5/.compound-engineering/artifacts/plans/bad.md"
git -C "$repo5" add .compound-engineering/artifacts/plans/bad.md
status=0
out=$( (cd "$repo5" && bash "$script") 2>&1 ) || status=$?
[[ $status -ne 0 ]] || fail "artifacts plan bad.md exited 0"
[[ $out == *".compound-engineering/artifacts/plans/bad.md"* && $out == *"MD032"* ]] || fail "artifacts plan bad.md error output incorrect"
pass "staged root README.md and .compound-engineering/artifacts/plans/*.md each exit non-zero on error"

# Scenario: The index holds a bad docs/x.md and the working tree a fixed copy: exits non-zero
repo6="$TEST_TMPDIR/repo6"
make_test_repo "$repo6"
mkdir -p "$repo6/docs"
printf "%s" "$bad_md_content" > "$repo6/docs/x.md"
git -C "$repo6" add docs/x.md
printf "%s" "$clean_md_content" > "$repo6/docs/x.md"
status=0
(cd "$repo6" && bash "$script") >/dev/null 2>&1 || status=$?
[[ $status -ne 0 ]] || fail "bad index with clean working tree exited 0"
pass "index holding bad docs/x.md with fixed working tree exits non-zero"

# Scenario: The index holds a clean docs/x.md and the working tree a broken copy: exits 0
repo7="$TEST_TMPDIR/repo7"
make_test_repo "$repo7"
mkdir -p "$repo7/docs"
printf "%s" "$clean_md_content" > "$repo7/docs/x.md"
git -C "$repo7" add docs/x.md
printf "%s" "$bad_md_content" > "$repo7/docs/x.md"
(cd "$repo7" && bash "$script") >/dev/null 2>&1 || fail "clean index with broken working tree exited non-zero"
pass "index holding clean docs/x.md with broken working tree exits 0"

# Scenario: A staged deletion of a Markdown file exits 0
repo8="$TEST_TMPDIR/repo8"
make_test_repo "$repo8"
mkdir -p "$repo8/docs"
printf "%s" "$clean_md_content" > "$repo8/docs/del.md"
git -C "$repo8" add docs/del.md
git -C "$repo8" commit -q -m "add del.md"
git -C "$repo8" rm -q docs/del.md
(cd "$repo8" && bash "$script") || fail "staged deletion of markdown file exited non-zero"
pass "staged deletion of a Markdown file exits 0"

# Scenario: A staged Markdown path containing a space is linted
repo9="$TEST_TMPDIR/repo9"
make_test_repo "$repo9"
mkdir -p "$repo9/docs"
printf "%s" "$bad_md_content" > "$repo9/docs/with space.md"
git -C "$repo9" add "docs/with space.md"
status=0
out=$( (cd "$repo9" && bash "$script") 2>&1 ) || status=$?
[[ $status -ne 0 ]] || fail "path with space and error exited 0"
[[ $out == *"with space.md"* && $out == *"MD032"* ]] || fail "path with space output incorrect: $out"

printf "%s" "$clean_md_content" > "$repo9/docs/with space.md"
git -C "$repo9" add "docs/with space.md"
(cd "$repo9" && bash "$script") || fail "clean path with space failed"
pass "staged Markdown path containing a space is linted correctly"

# Scenario: In a repository with no commits yet, a staged bad docs/bad.md still fails
repo10="$TEST_TMPDIR/repo10"
mkdir -p "$repo10/docs"
git -C "$repo10" init -q
cp "$config" "$repo10/.markdownlint-cli2.jsonc"
git -C "$repo10" add .markdownlint-cli2.jsonc
printf "%s" "$bad_md_content" > "$repo10/docs/bad.md"
git -C "$repo10" add docs/bad.md
status=0
out=$( (cd "$repo10" && bash "$script") 2>&1 ) || status=$?
[[ $status -ne 0 ]] || fail "unborn branch bad markdown exited 0"
[[ $out == *"docs/bad.md"* && $out == *"MD032"* ]] || fail "unborn branch output incorrect: $out"
pass "unborn repository with staged bad docs/bad.md fails"

# Scenario: a failing run leaves the index blob and the working-tree file unchanged
repo11="$TEST_TMPDIR/repo11"
make_test_repo "$repo11"
mkdir -p "$repo11/docs"
printf "%s" "$bad_md_content" > "$repo11/docs/bad.md"
git -C "$repo11" add docs/bad.md
wt_sha_before=$(git -C "$repo11" hash-object docs/bad.md)
idx_sha_before=$(git -C "$repo11" ls-files -s docs/bad.md | awk '{print $2}')
(cd "$repo11" && bash "$script") >/dev/null 2>&1 || true
wt_sha_after=$(git -C "$repo11" hash-object docs/bad.md)
idx_sha_after=$(git -C "$repo11" ls-files -s docs/bad.md | awk '{print $2}')
[[ "$wt_sha_before" == "$wt_sha_after" ]] || fail "working tree file modified by lint run"
[[ "$idx_sha_before" == "$idx_sha_after" ]] || fail "index blob modified by lint run"
pass "working-tree and index blobs byte-identical after failing run"

# Scenario: a staged Markdown symlink is linted through its target, as CI does
repo13="$TEST_TMPDIR/repo13"
make_test_repo "$repo13"
mkdir -p "$repo13/docs"
printf "%s" "$bad_md_content" > "$repo13/payload.txt"
ln -s ../payload.txt "$repo13/docs/linked.md"
git -C "$repo13" add payload.txt docs/linked.md
status=0
out=$( (cd "$repo13" && bash "$script") 2>&1 ) || status=$?
[[ $status -ne 0 ]] || fail "staged Markdown symlink to a bad target exited 0"
[[ $out == *"docs/linked.md"* && $out == *"MD032"* ]] || fail "symlink output incorrect: $out"
pass "staged Markdown symlink is linted through its target"

# Scenario: a nested markdownlint config applies to the staged file beneath it
repo14="$TEST_TMPDIR/repo14"
make_test_repo "$repo14"
mkdir -p "$repo14/docs"
printf '{ "MD013": true }\n' > "$repo14/docs/.markdownlint.json"
git -C "$repo14" add docs/.markdownlint.json
git -C "$repo14" commit -q -m "nested config"
long_line=$(printf 'word %.0s' {1..30})
long_line=${long_line% }
printf "# Title\n\n%s\n" "$long_line" > "$repo14/docs/x.md"
git -C "$repo14" add docs/x.md
status=0
out=$( (cd "$repo14" && bash "$script") 2>&1 ) || status=$?
[[ $status -ne 0 ]] || fail "nested config enabling MD013 was ignored"
[[ $out == *"docs/x.md"* && $out == *"MD013"* ]] || fail "nested config output incorrect: $out"
pass "nested markdownlint config applies to staged files beneath it"

# The hook runs the mise task, so the task must run the script under test.
task_script=$(abspath "$(dirname "$script")/../$task_run")
[[ $task_script == "$script" ]] || fail "mise task lint-staged-markdown runs '$task_run', not $script"
pass "mise task lint-staged-markdown runs the script under test"

# Hook wiring and linked worktrees
repo12="$TEST_TMPDIR/repo12"
make_test_repo "$repo12"
mkdir -p "$repo12/.githooks"
cp "$hook" "$repo12/.githooks/pre-commit"
chmod +x "$repo12/.githooks/pre-commit"
git -C "$repo12" add .githooks/pre-commit
git -C "$repo12" commit -q -m "add hook"
git -C "$repo12" config core.hooksPath .githooks

# Setup stub mise that delegates lint-staged-markdown to $script
stub_mise_dir="$TEST_TMPDIR/stub_mise_bin"
mkdir -p "$stub_mise_dir"
cat > "$stub_mise_dir/mise" <<STUB_MISE_EOF
#!/bin/sh
if [ "\$1" = "run" ] && [ "\$2" = "lint-staged-markdown" ]; then
  exec bash "$task_script"
fi
echo "Unexpected mise arguments: \$*" >&2
exit 1
STUB_MISE_EOF
chmod +x "$stub_mise_dir/mise"

# Create linked worktree
wt1="$TEST_TMPDIR/wt1"
git -C "$repo12" worktree add -q -b wt1-branch "$wt1"

# Bad commit in linked worktree fails and prints rule
mkdir -p "$wt1/docs"
printf "%s" "$bad_md_content" > "$wt1/docs/bad.md"
git -C "$wt1" add docs/bad.md
commit_status=0
commit_out=$( PATH="$stub_mise_dir:$PATH" git -C "$wt1" commit -m "commit bad" 2>&1 ) || commit_status=$?
[[ $commit_status -ne 0 ]] || fail "git commit with bad markdown succeeded"
[[ $commit_out == *"MD032"* ]] || fail "git commit failure output missing MD032"
pass "git commit in linked worktree with staged bad markdown fails and prints rule"

# Clean commit in linked worktree succeeds
printf "%s" "$clean_md_content" > "$wt1/docs/bad.md"
git -C "$wt1" add docs/bad.md
PATH="$stub_mise_dir:$PATH" git -C "$wt1" commit -q -m "commit clean" || fail "git commit with clean markdown failed"
pass "git commit in linked worktree with clean markdown succeeds"

# Branch without .githooks/ commits successfully
# Create a branch pointing at initial commit (before .githooks was added)
initial_commit=$(git -C "$repo12" rev-list --max-parents=0 HEAD)
git -C "$repo12" branch branch-no-hooks "$initial_commit"
wt2="$TEST_TMPDIR/wt2"
git -C "$repo12" worktree add -q "$wt2" branch-no-hooks
[[ ! -d "$wt2/.githooks" ]] || fail "wt2 unexpectedly has .githooks"
mkdir -p "$wt2/docs"
printf "%s" "$bad_md_content" > "$wt2/docs/bad.md"
git -C "$wt2" add docs/bad.md
PATH="$stub_mise_dir:$PATH" git -C "$wt2" commit -q -m "commit without hook" || fail "commit on branch without .githooks failed"
pass "linked worktree on branch without .githooks commits successfully"

# Running git config core.hooksPath twice leaves a single value
git -C "$repo12" config core.hooksPath .githooks
git -C "$repo12" config core.hooksPath .githooks
hooks_count=$(git -C "$repo12" config --get-all core.hooksPath | wc -l | tr -d " ")
[[ "$hooks_count" -eq 1 ]] || fail "git config core.hooksPath left multiple values: $hooks_count"
pass "running git config core.hooksPath twice leaves a single value"

pass "all lint-staged-markdown scenarios passed"
