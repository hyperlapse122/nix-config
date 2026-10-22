#!/usr/bin/env bash
#
# Check interface:
#
#   bash tests/update-dependencies-reconcile.sh <update-dependencies-workflow>
#
# Covers the updater's failure path, its schedule, and the T3 Code bump:
#
# - The "Open reconciliation PR on failure" step's literal script runs
#   against a sandboxed git remote and a stub `gh` that rejects any
#   `--label`, the way the real repository does: it has no `dependencies`
#   or `automated` label, and the workflow cannot create one. With no open
#   PR, the step must push the fix branch, open the PR, and exit 0. With a
#   PR already open, the fix branch may carry fix commits that a reset would
#   discard: the step must leave the branch alone and refresh the PR body
#   with the new logs. When the open-PR query itself fails, the step must
#   fail without touching the branch or any PR.
# - The PR body asks a person to push a fix and merge by hand; it never
#   calls the updater hourly, promises an automatic merge, or names Claude.
# - The PR step runs only for a changed update that failed verification.
# - No step may run `gh pr merge`: main requires no check, and the PR gets
#   CI only because it is opened with GH_TOKEN_FOR_UPDATES (a PR opened with
#   the GITHUB_TOKEN fallback triggers none), so auto-merge could land an
#   unverified fix on main.
# - The cron must fire twice an hour and never at minute 0.
# - The "Push verified updates directly to main" step must commit a T3 Code
#   pin change on its own, as `chore(packages): bump t3code to <version>`.
# - The update step must run t3code-release, and a failing t3code-release
#   must warn and keep the pin rather than abort the other updates.
# - The same holds for opencode-release and the OpenCode pin, which the push
#   step commits on its own as `chore(packages): bump opencode to <version>`.
# - The same holds for antigravity-acp-release and the Antigravity ACP
#   runtime pin, committed as `chore(packages): bump antigravity-acp to
#   <version>`. When that update also changes t3code-release.json, the
#   commit contains both files. A T3-only change stays its own commit.
# - A failing antigravity-acp-release keeps a T3 version bump already in
#   t3code-release.json and restores only that file's antigravity section.
# - The update step runs pi-release, and a failing pi-release warns, keeps
#   the pin, and lets the other updates through. It runs npm-release for
#   pi-acp and then acpx, each with its pin and lock file, and a failure for
#   one restores both of that package's files, warns naming it, and still
#   updates the other.
# - The catalog snapshot runs in its own step, the only step that receives
#   the SYNTHETIC_API_KEY secret, and a failing refresh warns, restores the
#   committed snapshot, and lets the job go on.
# - The push step commits each changed pin on its own: the snapshot as
#   `chore(agents): refresh the synthetic catalog snapshot`, the Pi pin as
#   `chore(packages): bump pi to <version>`, and each of pi-acp and acpx as
#   `chore(packages): bump <package> to <version>` with its pin and lock file
#   together, and nothing else.

set -euo pipefail

workflow=${1:-}
if [[ $# -ne 1 || -z $workflow || ! -f $workflow ]]; then
  printf 'usage: %s WORKFLOW_FILE\n' "${0##*/}" >&2
  exit 2
fi

fail() { printf 'update-dependencies-reconcile: FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'update-dependencies-reconcile: ok - %s\n' "$*"; }

fix_branch=update-dependencies-fix

# step_run <name>: the dedented `run: |` block of the named step.
step_run() {
  awk -v step="- name: $1" '
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
  ' indent=-1 "$workflow"
}

# step_block <name>: every line of the named step, up to the next step. A
# step starts at a `- ` line at the step list's indent; some steps have no
# name, so the end is found by indent rather than by `- name:`.
step_block() {
  awk -v step="- name: $1" '
    found == 0 && index($0, step) > 0 {
      found = 1
      line = $0
      sub(/^[[:space:]]*/, "", line)
      indent = length($0) - length(line)
      print
      next
    }
    found == 1 {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      lead = length($0) - length(line)
      if (line != "" && lead <= indent) { exit }
      print
    }
  ' "$workflow"
}

scratch=$(mktemp -d "${TMPDIR:-/tmp}/update-dependencies-reconcile.XXXXXX")
trap 'rm -rf -- "$scratch"' EXIT

git_bin=$(command -v git) || fail 'git is required'

# setup_clone <name>: a bare origin with main and a clone of it.
setup_clone() {
  local name=$1
  local origin=$scratch/$name-origin.git
  local clone=$scratch/$name-clone
  "$git_bin" init -q --bare "$origin"
  # A sandboxed HOME has no init.defaultBranch; pin HEAD to main.
  "$git_bin" --git-dir "$origin" symbolic-ref HEAD refs/heads/main
  "$git_bin" clone -q "$origin" "$clone"
  "$git_bin" -C "$clone" config user.email t@example.invalid
  "$git_bin" -C "$clone" config user.name Test
  "$git_bin" -C "$clone" checkout -qb main
  mkdir -p "$clone/packages"
  printf '{"version": "0.0.46-nightly.20261003.2600"}\n' >"$clone/packages/t3code-release.json"
  printf '{"version": "2.0.31", "platforms": {}}\n' >"$clone/packages/opencode-release.json"
  printf '{"version": "1.4.1", "platforms": {}}\n' >"$clone/packages/antigravity-acp-release.json"
  printf '{"version": "1.4.0", "platforms": {}}\n' >"$clone/packages/pi-release.json"
  mkdir -p "$clone/packages/pi-acp" "$clone/packages/acpx" "$clone/home/h82/agents"
  printf '{"version": "0.0.33"}\n' >"$clone/packages/pi-acp-release.json"
  printf '{"lockfileVersion": 3, "name": "pi-acp"}\n' >"$clone/packages/pi-acp/package-lock.json"
  printf '{"version": "0.20.0"}\n' >"$clone/packages/acpx-release.json"
  printf '{"lockfileVersion": 3, "name": "acpx"}\n' >"$clone/packages/acpx/package-lock.json"
  printf '{"data": []}\n' >"$clone/home/h82/agents/synthetic-catalog.json"
  printf 'base\n' >"$clone/tracked.txt"
  "$git_bin" -C "$clone" add tracked.txt packages/t3code-release.json packages/opencode-release.json \
    packages/antigravity-acp-release.json packages/pi-release.json packages/pi-acp-release.json \
    packages/pi-acp/package-lock.json packages/acpx-release.json packages/acpx/package-lock.json \
    home/h82/agents/synthetic-catalog.json
  "$git_bin" -C "$clone" commit -qm init
  "$git_bin" -C "$clone" push -q origin main
  printf '%s %s\n' "$origin" "$clone"
}

# --- reconciliation PR step -------------------------------------------------

pr_block=$(step_block 'Open reconciliation PR on failure')
[[ -n $pr_block ]] || fail "could not find the reconciliation PR step in $workflow"
grep -Eq "^[[:space:]]*BRANCH:[[:space:]]*${fix_branch}[[:space:]]*$" <<<"$pr_block" ||
  fail "the reconciliation PR step does not set BRANCH to $fix_branch"
pr_script=$(step_run 'Open reconciliation PR on failure')
[[ -n $pr_script ]] || fail "could not find the reconciliation PR step's run block in $workflow"

# run_pr_step <name> <mode> <want-status>: runs the step with a stub `gh`
# whose open-PR query (`pr list --state open`) finds no PR (mode none) or
# one PR (open), or whose `pr list` and `pr view` fail the way an API or
# auth error does (error). Under open and error, the remote fix branch
# already carries a fix commit, the way it does once a person has pushed to
# the reconciliation PR. The step must exit 0 when <want-status>
# is 0 and non-zero otherwise. The stub logs each call to gh.log, copies
# --body-file to body.md, and fails on any --label, as `gh` does when the
# label does not exist. Prints the origin.
run_pr_step() {
  local name=$1 mode=$2 want=$3 origin clone status=0
  read -r origin clone <<<"$(setup_clone "$name")"
  if [[ $mode != none ]]; then
    "$git_bin" -C "$clone" checkout -qb "$fix_branch"
    printf 'fix\n' >"$clone/fix.txt"
    "$git_bin" -C "$clone" add fix.txt
    "$git_bin" -C "$clone" commit -qm 'fix: reconcile the update'
    "$git_bin" -C "$clone" push -q origin "$fix_branch"
    "$git_bin" -C "$clone" checkout -q main
  fi
  mkdir -p "$scratch/$name-bin"
  cat >"$scratch/$name-bin/gh" <<EOF
#!$BASH
printf '%s\n' "\$*" >>"$scratch/$name-gh.log"
prev=
jq=0
open=0
for arg in "\$@"; do
  if [[ \$arg == --label || \$arg == --label=* || \$arg == --add-label* ]]; then
    echo "could not add label: 'dependencies' not found" >&2
    exit 1
  fi
  if [[ \$prev == --body-file ]]; then cp "\$arg" "$scratch/$name-body.md"; fi
  if [[ \$arg == --jq || \$arg == -q ]]; then jq=1; fi
  if [[ \$prev == --state && \$arg == open ]]; then open=1; fi
  prev=\$arg
done
if [[ $mode == error && \$1 == pr && ( \$2 == list || \$2 == view ) ]]; then
  echo 'HTTP 502: Bad Gateway (https://api.github.com/graphql)' >&2
  exit 1
fi
if [[ \$1 == pr && \$2 == list ]] && ((open)); then
  case $mode in
    open) if ((jq)); then echo 1; else echo '[{"number":7}]'; fi ;;
    *) if ((jq)); then echo 0; else echo '[]'; fi ;;
  esac
  exit 0
fi
if [[ \$1 == pr && \$2 == view ]]; then
  echo 'no pull requests found' >&2
  exit 1
fi
exit 0
EOF
  chmod +x "$scratch/$name-bin/gh"
  : >"$scratch/$name-gh.log"
  printf 'changed\n' >>"$clone/tracked.txt"
  printf 'nix flake check output\n' >"$clone/check.log"
  printf 'nix build vmChecks output\n' >"$clone/vm-check.log"
  (
    cd "$clone"
    PATH=$scratch/$name-bin:$PATH BRANCH=$fix_branch \
      bash -e -c "$pr_script"
  ) >"$scratch/$name-step.log" 2>&1 || status=$?
  if ((want == 0 && status != 0)); then
    fail "the reconciliation PR step exited $status ($name): $(tail -n 5 "$scratch/$name-step.log")"
  elif ((want != 0 && status == 0)); then
    fail "the reconciliation PR step exited 0 ($name): $(tail -n 5 "$scratch/$name-step.log")"
  fi
  printf '%s\n' "$origin"
}

origin=$(run_pr_step create none 0)
"$git_bin" --git-dir "$origin" rev-parse -q --verify "refs/heads/$fix_branch" >/dev/null ||
  fail "with no open PR, the step did not push $fix_branch"
pushed=$("$git_bin" --git-dir "$origin" log -1 --format=%s "$fix_branch")
[[ $pushed == "chore(deps): automated dependency update (reconciliation required)" ]] ||
  fail "with no open PR, $fix_branch does not carry this run's update: $pushed"
grep -q '^pr create' "$scratch/create-gh.log" ||
  fail "with no open PR, the step did not run gh pr create: $(cat "$scratch/create-gh.log")"
pass "with no open PR and no labels, the step pushes $fix_branch, opens the PR, and exits 0"

# check_body <name>: the PR body a run wrote asks a person to push a fix and
# never calls the updater hourly, promises an automatic merge, or names Claude.
check_body() {
  local body
  body=$(cat "$scratch/$1-body.md")
  [[ $body == *"Push a fix to this branch"* ]] || fail "the $1 PR body does not ask for a fix to be pushed"
  [[ $body != *hourly* ]] || fail "the $1 PR body still calls the updater hourly"
  [[ $body != *"merged automatically"* ]] || fail "the $1 PR body still promises an automatic merge"
  [[ $body != *Claude* ]] || fail "the $1 PR body still mentions Claude"
}

check_body create
pass 'the created PR body asks for a fix and neither calls the updater hourly, promises an automatic merge, nor mentions Claude'

origin=$(run_pr_step open open 0)
head_subject=$("$git_bin" --git-dir "$origin" log -1 --format=%s "$fix_branch")
[[ $head_subject == 'fix: reconcile the update' ]] ||
  fail "with a PR already open, the step reset $fix_branch over its fix commit; its head is now: $head_subject"
grep -q '^pr edit' "$scratch/open-gh.log" ||
  fail "with a PR already open, the step did not run gh pr edit: $(cat "$scratch/open-gh.log")"
if grep -q '^pr create' "$scratch/open-gh.log"; then
  fail 'with a PR already open, the step still ran gh pr create'
fi
grep -q 'nix flake check output' "$scratch/open-body.md" ||
  fail 'with a PR already open, the refreshed PR body lacks the new failure logs'
check_body open
pass "with a PR already open, the step keeps $fix_branch and refreshes the PR body with the new logs and the fix request"

origin=$(run_pr_step error error 1)
head_subject=$("$git_bin" --git-dir "$origin" log -1 --format=%s "$fix_branch")
[[ $head_subject == 'fix: reconcile the update' ]] ||
  fail "with the open-PR query failing, the step reset $fix_branch over its fix commit; its head is now: $head_subject"
if grep -Eq '^pr (create|edit)' "$scratch/error-gh.log"; then
  fail "with the open-PR query failing, the step still created or edited a PR: $(cat "$scratch/error-gh.log")"
fi
pass "with the open-PR query failing, the step exits non-zero and leaves $fix_branch and the PR alone"

# The whole expression, not its terms: the test runs the step's script
# directly, so an extra conjunct that GitHub evaluates false (`false && ...`)
# would skip the step in CI while every substring check still passed.
cond=$(sed -n 's/^[[:space:]]*if:[[:space:]]*//p' <<<"$pr_block")
want_cond="steps.update.outputs.changed == 'true' && steps.verify.outputs.status == 'failure'"
[[ $cond == "$want_cond" ]] ||
  fail "the reconciliation PR step's if: is '$cond', not '$want_cond'"
pass 'the reconciliation PR step gates on exactly a changed, failing update'

# --- auto-merge -------------------------------------------------------------

if grep -Eq 'gh[[:space:]]+pr[[:space:]]+merge' "$workflow"; then
  fail 'a step runs gh pr merge, which would merge an unverified fix into main'
fi
pass 'no step runs gh pr merge'

# --- schedule ---------------------------------------------------------------

crons=$(sed -n "s/^[[:space:]]*-[[:space:]]*cron:[[:space:]]*['\"]\([^'\"]*\)['\"].*/\1/p" "$workflow")
[[ -n $crons ]] || fail "could not find a cron schedule in $workflow"
[[ $(wc -l <<<"$crons") -eq 1 ]] || fail "expected one cron schedule, found: $crons"
read -r minutes hours dom month dow extra <<<"$crons"
[[ -z $extra && $hours == '*' && $dom == '*' && $month == '*' && $dow == '*' ]] ||
  fail "the cron does not run every hour of every day: $crons"
IFS=, read -r -a minute_list <<<"$minutes"
for minute in "${minute_list[@]}"; do
  if [[ ! $minute =~ ^[0-9]+$ ]] || ((10#$minute > 59)); then
    fail "cron minute '$minute' is not a single minute, so it may include :00: $crons"
  fi
  ((10#$minute != 0)) || fail "the cron fires at minute 0: $crons"
done
((${#minute_list[@]} == 2)) || fail "the cron fires ${#minute_list[@]} times an hour, not twice: $crons"
pass "the cron fires twice an hour, never on the hour ($crons)"

# --- T3 Code bump commit ----------------------------------------------------

push_script=$(step_run 'Push verified updates directly to main')
[[ -n $push_script ]] || fail "could not find the push step's run block in $workflow"
command -v jq >/dev/null || fail 'jq is required'

read -r origin clone <<<"$(setup_clone t3code)"
new_version=0.0.46-nightly.20261004.2644
printf '{"version": "%s"}\n' "$new_version" >"$clone/packages/t3code-release.json"
(cd "$clone" && bash -e -c "$push_script") >"$scratch/t3code-step.log" 2>&1 ||
  fail "the push step failed on a T3 Code pin change: $(tail -n 5 "$scratch/t3code-step.log")"
subject=$("$git_bin" --git-dir "$origin" log -1 --format=%s main)
[[ $subject == "chore(packages): bump t3code to $new_version" ]] ||
  fail "a T3 Code pin change was not committed as its own bump: $subject"
files=$("$git_bin" --git-dir "$origin" show --format= --name-only main)
[[ $files == packages/t3code-release.json ]] ||
  fail "the t3code bump commit carries more than the pin: $files"
pass 'a T3 Code pin change lands as its own chore(packages): bump t3code commit'

# --- T3 Code update ---------------------------------------------------------

update_script=$(step_run 'Update flake inputs, agent plugins, and packages')
[[ -n $update_script ]] || fail "could not find the update step's run block in $workflow"
grep -Eq '^[^#]*nix run \.#t3code-release -- --output packages/t3code-release\.json' <<<"$update_script" ||
  fail 'the update step no longer runs t3code-release against packages/t3code-release.json'
pass 'the update step runs t3code-release against packages/t3code-release.json'

# The T3 Code part of the update step: from its numbered comment to the next
# blank line. A nightly can be published before its assets and digests are,
# so t3code-release failing must leave the pin alone and let the step go on
# to the other updates instead of aborting it under `set -e`.
t3_script=$(awk '/^# [0-9]+\. Update T3 Code/ { on = 1 } on && /^$/ { exit } on' <<<"$update_script")
[[ -n $t3_script ]] || fail "could not find the T3 Code part of the update step in $workflow"

# run_t3_step <name> <fails>: runs the T3 Code part with `set -euo pipefail`
# and a stub `nix` that fails when <fails> is 1 and otherwise writes a new
# pin, then a marker line that must still run.
run_t3_step() {
  local name=$1 fails=$2 origin clone
  read -r origin clone <<<"$(setup_clone "$name")"
  mkdir -p "$scratch/$name-bin"
  cat >"$scratch/$name-bin/nix" <<EOF
#!$BASH
if [[ $fails == 1 ]]; then
  printf '{"version": "partial' >packages/t3code-release.json
  echo 'release 0.0.47-nightly has no digest for linux-x64' >&2
  exit 1
fi
printf '{"version": "0.0.47-nightly.20261005.2700"}\n' >packages/t3code-release.json
EOF
  chmod +x "$scratch/$name-bin/nix"
  (
    cd "$clone"
    PATH=$scratch/$name-bin:$PATH bash -e -c "set -euo pipefail
$t3_script
echo after-t3code"
  ) >"$scratch/$name-step.log" 2>&1 ||
    fail "the T3 Code update aborted the update step ($name): $(tail -n 5 "$scratch/$name-step.log")"
  grep -qx after-t3code "$scratch/$name-step.log" ||
    fail "the update step stopped after the T3 Code update ($name)"
  printf '%s\n' "$clone"
}

clone=$(run_t3_step t3-fails 1)
grep -q '^::warning' "$scratch/t3-fails-step.log" ||
  fail "a failing t3code-release emitted no ::warning:: annotation: $(cat "$scratch/t3-fails-step.log")"
[[ -z $("$git_bin" -C "$clone" status --porcelain packages/t3code-release.json) ]] ||
  fail 'a failing t3code-release left packages/t3code-release.json changed'
pass 'a failing t3code-release warns, keeps the pin, and lets the update step go on'

clone=$(run_t3_step t3-succeeds 0)
grep -q '0.0.47-nightly.20261005.2700' "$clone/packages/t3code-release.json" ||
  fail 'a succeeding t3code-release did not update the pin'
if grep -q '^::warning' "$scratch/t3-succeeds-step.log"; then
  fail 'a succeeding t3code-release still emitted a warning'
fi
pass 'a succeeding t3code-release updates the pin without a warning'

# --- OpenCode bump commit ---------------------------------------------------

read -r origin clone <<<"$(setup_clone opencode)"
oc_version=2.0.32
printf '{"version": "%s", "platforms": {}}\n' "$oc_version" >"$clone/packages/opencode-release.json"
# A second changed file, so a commit that sweeps in more than the pin shows.
printf 'changed\n' >>"$clone/tracked.txt"
base_sha=$("$git_bin" --git-dir "$origin" rev-parse main)
(cd "$clone" && bash -e -c "$push_script") >"$scratch/opencode-step.log" 2>&1 ||
  fail "the push step failed on an OpenCode pin change: $(tail -n 5 "$scratch/opencode-step.log")"
bump_shas=$("$git_bin" --git-dir "$origin" log --format=%H \
  --grep "^chore(packages): bump opencode to $oc_version\$" "$base_sha..main")
[[ -n $bump_shas && $(wc -l <<<"$bump_shas") -eq 1 ]] ||
  fail "an OpenCode pin change did not land as exactly one bump commit: ${bump_shas:-none}"
files=$("$git_bin" --git-dir "$origin" show --format= --name-only "$bump_shas")
[[ $files == packages/opencode-release.json ]] ||
  fail "the opencode bump commit carries more than the pin: $files"
pass 'an OpenCode pin change lands as its own chore(packages): bump opencode commit'

# --- OpenCode update --------------------------------------------------------

grep -Eq '^[^#]*nix run \.#opencode-release -- --output packages/opencode-release\.json' <<<"$update_script" ||
  fail 'the update step no longer runs opencode-release against packages/opencode-release.json'
pass 'the update step runs opencode-release against packages/opencode-release.json'

# The OpenCode part of the update step, cut the way the T3 Code part is. A
# release can be published before all of its platform packages are, so opencode-release
# failing must leave the pin alone and let the step go on.
oc_script=$(awk '/^# [0-9]+\. Update OpenCode/ { on = 1 } on && /^$/ { exit } on' <<<"$update_script")
[[ -n $oc_script ]] || fail "could not find the OpenCode part of the update step in $workflow"

# run_opencode_step <name> <fails>: as run_t3_step, for the OpenCode part.
run_opencode_step() {
  local name=$1 fails=$2 origin clone
  read -r origin clone <<<"$(setup_clone "$name")"
  mkdir -p "$scratch/$name-bin"
  cat >"$scratch/$name-bin/nix" <<EOF
#!$BASH
if [[ $fails == 1 ]]; then
  printf '{"version": "partial' >packages/opencode-release.json
  echo '@opencode/cli 2.0.32 does not list @opencode/cli-linux-x64 at 2.0.32; refusing to write an incomplete pin' >&2
  exit 1
fi
printf '{"version": "2.0.32", "platforms": {}}\n' >packages/opencode-release.json
EOF
  chmod +x "$scratch/$name-bin/nix"
  (
    cd "$clone"
    PATH=$scratch/$name-bin:$PATH bash -e -c "set -euo pipefail
$oc_script
echo after-opencode"
  ) >"$scratch/$name-step.log" 2>&1 ||
    fail "the OpenCode update aborted the update step ($name): $(tail -n 5 "$scratch/$name-step.log")"
  grep -qx after-opencode "$scratch/$name-step.log" ||
    fail "the update step stopped after the OpenCode update ($name)"
  printf '%s\n' "$clone"
}

clone=$(run_opencode_step oc-fails 1)
grep -q '^::warning' "$scratch/oc-fails-step.log" ||
  fail "a failing opencode-release emitted no ::warning:: annotation: $(cat "$scratch/oc-fails-step.log")"
[[ -z $("$git_bin" -C "$clone" status --porcelain packages/opencode-release.json) ]] ||
  fail 'a failing opencode-release left packages/opencode-release.json changed'
pass 'a failing opencode-release warns, keeps the pin, and lets the update step go on'

clone=$(run_opencode_step oc-succeeds 0)
grep -q '"2.0.32"' "$clone/packages/opencode-release.json" ||
  fail 'a succeeding opencode-release did not update the pin'
if grep -q '^::warning' "$scratch/oc-succeeds-step.log"; then
  fail 'a succeeding opencode-release still emitted a warning'
fi
pass 'a succeeding opencode-release updates the pin without a warning'

# --- Antigravity ACP runtime bump commit ------------------------------------

read -r origin clone <<<"$(setup_clone acp)"
acp_version=1.5.0
printf '{"version": "%s", "platforms": {}}\n' "$acp_version" >"$clone/packages/antigravity-acp-release.json"
# A second changed file, so a commit that sweeps in more than the pin shows.
printf 'changed\n' >>"$clone/tracked.txt"
base_sha=$("$git_bin" --git-dir "$origin" rev-parse main)
(cd "$clone" && bash -e -c "$push_script") >"$scratch/acp-step.log" 2>&1 ||
  fail "the push step failed on an Antigravity ACP pin change: $(tail -n 5 "$scratch/acp-step.log")"
bump_shas=$("$git_bin" --git-dir "$origin" log --format=%H \
  --grep "^chore(packages): bump antigravity-acp to $acp_version\$" "$base_sha..main")
[[ -n $bump_shas && $(wc -l <<<"$bump_shas") -eq 1 ]] ||
  fail "an Antigravity ACP pin change did not land as exactly one bump commit: ${bump_shas:-none}"
files=$("$git_bin" --git-dir "$origin" show --format= --name-only "$bump_shas")
[[ $files == packages/antigravity-acp-release.json ]] ||
  fail "the antigravity-acp bump commit carries more than the pin: $files"
pass 'an Antigravity ACP pin change lands as its own chore(packages): bump antigravity-acp commit'

read -r origin clone <<<"$(setup_clone acp-both)"
base_sha=$("$git_bin" --git-dir "$origin" rev-parse main)
printf '%s\n' '{"version":"0.0.47-nightly.20261021.1","antigravity":{"x86_64-linux":{"version":"1.5.0"}}}' \
  >"$clone/packages/t3code-release.json"
printf '%s\n' '{"version":"1.5.0","platforms":{}}' >"$clone/packages/antigravity-acp-release.json"
(cd "$clone" && bash -e -c "$push_script") >"$scratch/acp-both-step.log" 2>&1 ||
  fail "the push step failed when both Antigravity pins changed: $(tail -n 5 "$scratch/acp-both-step.log")"
new_count=$("$git_bin" --git-dir "$origin" rev-list --count "$base_sha..main")
[[ $new_count -eq 1 ]] ||
  fail "both Antigravity pins should land as one commit, found $new_count: $("$git_bin" --git-dir "$origin" log --oneline "$base_sha..main")"
subject=$("$git_bin" --git-dir "$origin" log -1 --format=%s main)
[[ $subject == "chore(packages): bump antigravity-acp to 1.5.0" ]] ||
  fail "the joint pin commit subject was '$subject'"
body=$("$git_bin" --git-dir "$origin" log -1 --format=%b main)
[[ $body == *"Also bumps t3code to 0.0.47-nightly.20261021.1."* ]] ||
  fail "the joint pin commit did not name the T3 version bump: $body"
files=$("$git_bin" --git-dir "$origin" show --format= --name-only main)
file_count=$(printf '%s\n' "$files" | grep -c .)
[[ $file_count -eq 2 ]] ||
  fail "the joint pin commit should carry two files: $files"
grep -qx 'packages/antigravity-acp-release.json' <<<"$files" ||
  fail "the joint pin commit omitted the PATH pin: $files"
grep -qx 'packages/t3code-release.json' <<<"$files" ||
  fail "the joint pin commit omitted the t3 pin: $files"
while read -r sha; do
  path_ver=$("$git_bin" --git-dir "$origin" show "$sha:packages/antigravity-acp-release.json" | jq -r .version)
  agy_ver=$("$git_bin" --git-dir "$origin" show "$sha:packages/t3code-release.json" | jq -r '.antigravity["x86_64-linux"].version // empty')
  if [[ $agy_ver == 1.5.0 && $path_ver != 1.5.0 ]]; then
    fail "commit $sha has antigravity 1.5.0 beside PATH pin $path_ver"
  fi
done < <("$git_bin" --git-dir "$origin" rev-list "$base_sha..main")
pass 'both Antigravity pins land in one commit, and no revision splits them'

read -r origin clone <<<"$(setup_clone acp-section-only)"
base_sha=$("$git_bin" --git-dir "$origin" rev-parse main)
printf '%s\n' '{"version":"0.0.46-nightly.20261003.2600","antigravity":{"x86_64-linux":{"version":"1.5.0"}}}' \
  >"$clone/packages/t3code-release.json"
printf '%s\n' '{"version":"1.5.0","platforms":{}}' >"$clone/packages/antigravity-acp-release.json"
(cd "$clone" && bash -e -c "$push_script") >"$scratch/acp-section-step.log" 2>&1 ||
  fail "the push step failed when the antigravity section and the PATH pin changed: $(tail -n 5 "$scratch/acp-section-step.log")"
subject=$("$git_bin" --git-dir "$origin" log -1 --format=%s main)
[[ $subject == "chore(packages): bump antigravity-acp to 1.5.0" ]] ||
  fail "a section-only joint commit subject was '$subject'"
body=$("$git_bin" --git-dir "$origin" log -1 --format=%b main)
[[ -z $body ]] || fail "a section-only joint commit added a body: $body"
new_count=$("$git_bin" --git-dir "$origin" rev-list --count "$base_sha..main")
[[ $new_count -eq 1 ]] ||
  fail "a section-only Antigravity update should be one commit, found $new_count"
pass 'an antigravity section update with an unchanged T3 version shares the ACP commit and names no T3 bump'

# --- Antigravity ACP runtime update -----------------------------------------

grep -Eq '^[^#]*nix run \.#antigravity-acp-release -- --output packages/antigravity-acp-release\.json' <<<"$update_script" ||
  fail 'the update step no longer runs antigravity-acp-release against packages/antigravity-acp-release.json'
pass 'the update step runs antigravity-acp-release against packages/antigravity-acp-release.json'

# The Antigravity ACP part of the update step, cut the way the T3 Code part
# is. A probe or a download can fail, so antigravity-acp-release failing must
# leave the pin alone and let the step go on.
acp_script=$(awk '/^# [0-9]+\. Update the Antigravity ACP runtime/ { on = 1 } on && /^$/ { exit } on' <<<"$update_script")
[[ -n $acp_script ]] || fail "could not find the Antigravity ACP part of the update step in $workflow"

# run_acp_step <name> <fails>: as run_t3_step, for the Antigravity ACP part.
run_acp_step() {
  local name=$1 fails=$2 origin clone
  read -r origin clone <<<"$(setup_clone "$name")"
  mkdir -p "$scratch/$name-bin"
  cat >"$scratch/$name-bin/nix" <<EOF
#!$BASH
if [[ $fails == 1 ]]; then
  printf '{"version": "partial' >packages/antigravity-acp-release.json
  echo 'antigravity-acp-release: an archive downloaded 1 bytes, not the 2 its HEAD reported' >&2
  exit 1
fi
if [[ $fails == 2 ]]; then
  jq --indent 2 '.antigravity = {"broken": true}' packages/t3code-release.json > packages/t3code-release.json.tmp &&
    mv packages/t3code-release.json.tmp packages/t3code-release.json
  printf '{"version": "partial' >packages/antigravity-acp-release.json
  echo 'antigravity-acp-release: an archive downloaded 1 bytes, not the 2 its HEAD reported' >&2
  exit 1
fi
printf '{"version": "1.5.0", "platforms": {}}\n' >packages/antigravity-acp-release.json
EOF
  chmod +x "$scratch/$name-bin/nix"
  if [[ $fails == 2 ]]; then
    jq --indent 2 '.version = "0.0.47-nightly.20261021.1" | .antigravity = {"x86_64-linux": {"version": "1.4.1"}}' \
      "$clone/packages/t3code-release.json" >"$clone/packages/t3code-release.json.tmp"
    mv "$clone/packages/t3code-release.json.tmp" "$clone/packages/t3code-release.json"
  fi
  (
    cd "$clone"
    PATH=$scratch/$name-bin:$PATH bash -e -c "set -euo pipefail
$acp_script
echo after-acp"
  ) >"$scratch/$name-step.log" 2>&1 ||
    fail "the Antigravity ACP update aborted the update step ($name): $(tail -n 5 "$scratch/$name-step.log")"
  grep -qx after-acp "$scratch/$name-step.log" ||
    fail "the update step stopped after the Antigravity ACP update ($name)"
  printf '%s\n' "$clone"
}

clone=$(run_acp_step acp-fails 1)
grep -q '^::warning' "$scratch/acp-fails-step.log" ||
  fail "a failing antigravity-acp-release emitted no ::warning:: annotation: $(cat "$scratch/acp-fails-step.log")"
[[ -z $("$git_bin" -C "$clone" status --porcelain packages/antigravity-acp-release.json) ]] ||
  fail 'a failing antigravity-acp-release left packages/antigravity-acp-release.json changed'
pass 'a failing antigravity-acp-release warns, keeps the pin, and lets the update step go on'

clone=$(run_acp_step acp-succeeds 0)
grep -q '"1.5.0"' "$clone/packages/antigravity-acp-release.json" ||
  fail 'a succeeding antigravity-acp-release did not update the pin'
if grep -q '^::warning' "$scratch/acp-succeeds-step.log"; then
  fail 'a succeeding antigravity-acp-release still emitted a warning'
fi
pass 'a succeeding antigravity-acp-release updates the pin without a warning'

clone=$(run_acp_step acp-fails-keeps-t3 2)
jq -e '.version == "0.0.47-nightly.20261021.1" and .antigravity == {"x86_64-linux": {"version": "1.4.1"}}' \
  "$clone/packages/t3code-release.json" >/dev/null ||
  fail "a failing antigravity-acp-release did not keep the T3 version and restore only the antigravity section: $(cat "$clone/packages/t3code-release.json")"
[[ -z $("$git_bin" -C "$clone" status --porcelain packages/antigravity-acp-release.json) ]] ||
  fail 'a failing antigravity-acp-release left the PATH pin changed while restoring the t3 section'
pass 'a failing antigravity-acp-release keeps a T3 version bump and restores the antigravity section'

# --- Pi, its ACP packages, and the catalog snapshot -------------------------

# run_part <name> <script> <stub>: runs <script> in a fresh clone with
# `set -euo pipefail` and a `nix` on PATH whose body is <stub>, then a marker
# line that must still run.
run_part() {
  local name=$1 script=$2 stub=$3 origin clone
  read -r origin clone <<<"$(setup_clone "$name")"
  mkdir -p "$scratch/$name-bin"
  printf '#!%s\n%s\n' "$BASH" "$stub" >"$scratch/$name-bin/nix"
  chmod +x "$scratch/$name-bin/nix"
  (
    cd "$clone"
    PATH=$scratch/$name-bin:$PATH bash -e -c "set -euo pipefail
$script
echo after-part"
  ) >"$scratch/$name-step.log" 2>&1 ||
    fail "the $name part aborted its step: $(tail -n 5 "$scratch/$name-step.log")"
  grep -qx after-part "$scratch/$name-step.log" ||
    fail "the step stopped after the $name part"
  printf '%s\n' "$clone"
}

grep -Eq '^[^#]*nix run \.#pi-release -- --output packages/pi-release\.json' <<<"$update_script" ||
  fail 'the update step no longer runs pi-release against packages/pi-release.json'
pi_script=$(awk '/^# [0-9]+\. Update Pi\./ { on = 1 } on && /^$/ { exit } on' <<<"$update_script")
[[ -n $pi_script ]] || fail "could not find the Pi part of the update step in $workflow"
pi_stub='if [[ ${FAIL:-0} == 1 ]]; then
  printf "{\"version\": \"partial" >packages/pi-release.json
  echo "pi-release: release v1.5.0 has no pi-linux-arm64.tar.gz" >&2
  exit 1
fi
printf "{\"version\": \"1.5.0\", \"platforms\": {}}\n" >packages/pi-release.json'

clone=$(FAIL=1 run_part pi-fails "$pi_script" "$pi_stub")
grep -q '^::warning' "$scratch/pi-fails-step.log" ||
  fail "a failing pi-release emitted no ::warning:: annotation: $(cat "$scratch/pi-fails-step.log")"
[[ -z $("$git_bin" -C "$clone" status --porcelain packages/pi-release.json) ]] ||
  fail 'a failing pi-release left packages/pi-release.json changed'
clone=$(run_part pi-succeeds "$pi_script" "$pi_stub")
grep -q '"1.5.0"' "$clone/packages/pi-release.json" || fail 'a succeeding pi-release did not update the pin'
if grep -q '^::warning' "$scratch/pi-succeeds-step.log"; then fail 'a succeeding pi-release still emitted a warning'; fi
pass 'pi-release runs against packages/pi-release.json; a failure warns and keeps the pin, a success updates it'

npm_script=$(awk '/^# [0-9]+\. Update Pi.s ACP adapter and client/ { on = 1 } on && /^$/ { exit } on' <<<"$update_script")
[[ -n $npm_script ]] || fail "could not find the Pi ACP part of the update step in $workflow"
# The stub records each package it was asked for, checks the paths it was
# given, and fails for the packages FAIL names after leaving both files
# half-written.
npm_stub='package= output= lock=
while [[ $# -gt 0 ]]; do
  case $1 in
    --package) package=$2; shift ;;
    --output) output=$2; shift ;;
    --lock) lock=$2; shift ;;
  esac
  shift
done
echo "$package" >>npm-calls.log
[[ $output == "packages/$package-release.json" && $lock == "packages/$package/package-lock.json" ]] || {
  echo "npm-release got --output $output --lock $lock for $package" >&2
  exit 9
}
if [[ " ${FAIL:-} " == *" $package "* ]]; then
  printf "{\"version\": \"partial" >"$output"
  printf "partial" >"$lock"
  echo "npm-release: npm could not write a lock file" >&2
  exit 1
fi
printf "{\"version\": \"9.9.9\"}\n" >"$output"
printf "{\"lockfileVersion\": 3, \"new\": true}\n" >"$lock"'

clone=$(FAIL=pi-acp run_part npm-one-fails "$npm_script" "$npm_stub")
[[ $(paste -sd ' ' "$clone/npm-calls.log") == "pi-acp acpx" ]] ||
  fail "the update step ran npm-release for $(paste -sd ' ' "$clone/npm-calls.log"), not pi-acp then acpx"
grep -q '^::warning title=pi-acp update skipped' "$scratch/npm-one-fails-step.log" ||
  fail "a failing npm-release for pi-acp emitted no warning naming it: $(cat "$scratch/npm-one-fails-step.log")"
[[ -z $("$git_bin" -C "$clone" status --porcelain packages/pi-acp-release.json packages/pi-acp/package-lock.json) ]] ||
  fail 'a failing npm-release for pi-acp left its pin or lock file changed'
grep -q '"9.9.9"' "$clone/packages/acpx-release.json" && grep -q '"new": true' "$clone/packages/acpx/package-lock.json" ||
  fail 'a failing pi-acp update kept acpx from updating its pin and lock file'
clone=$(FAIL='pi-acp acpx' run_part npm-both-fail "$npm_script" "$npm_stub")
[[ -z $("$git_bin" -C "$clone" status --porcelain packages) ]] ||
  fail "failing npm-release runs left changes: $("$git_bin" -C "$clone" status --porcelain packages)"
[[ $(grep -c '^::warning' "$scratch/npm-both-fail-step.log") == 2 ]] ||
  fail 'two failing npm-release runs did not each warn'
pass 'npm-release runs for pi-acp and acpx; a failure restores that package'\''s pin and lock file and lets the other update'

snapshot_block=$(step_block 'Refresh the Synthetic catalog snapshot')
[[ -n $snapshot_block ]] || fail "could not find the catalog snapshot step in $workflow"
grep -Eq '^[[:space:]]+SYNTHETIC_API_KEY: \$\{\{ secrets\.SYNTHETIC_API_KEY \}\}$' <<<"$snapshot_block" ||
  fail 'the catalog snapshot step does not receive the SYNTHETIC_API_KEY secret'
[[ $(grep -c 'secrets\.SYNTHETIC_API_KEY' "$workflow") == 1 ]] ||
  fail 'a step other than the catalog snapshot step receives the SYNTHETIC_API_KEY secret'
snapshot_script=$(step_run 'Refresh the Synthetic catalog snapshot')
grep -Eq '^[^#]*nix run \.#synthetic-models-watch -- --snapshot home/h82/agents/synthetic-catalog\.json' <<<"$snapshot_script" ||
  fail 'the catalog snapshot step no longer refreshes home/h82/agents/synthetic-catalog.json'
snapshot_stub='if [[ ${FAIL:-0} == 1 ]]; then
  printf "{\"data\": [" >home/h82/agents/synthetic-catalog.json
  echo "synthetic-models-watch: the catalog lacks hf:moonshotai/Kimi-K3" >&2
  exit 1
fi
printf "{\"data\": [{\"id\": \"hf:new/Model\"}]}\n" >home/h82/agents/synthetic-catalog.json'
clone=$(FAIL=1 run_part snapshot-fails "$snapshot_script" "$snapshot_stub")
grep -q '^::warning' "$scratch/snapshot-fails-step.log" ||
  fail "a failing snapshot refresh emitted no ::warning:: annotation"
[[ -z $("$git_bin" -C "$clone" status --porcelain home) ]] ||
  fail 'a failing snapshot refresh left home/h82/agents/synthetic-catalog.json changed'
clone=$(run_part snapshot-succeeds "$snapshot_script" "$snapshot_stub")
grep -q 'hf:new/Model' "$clone/home/h82/agents/synthetic-catalog.json" ||
  fail 'a succeeding snapshot refresh did not write the snapshot'
pass 'the snapshot step alone gets the secret; a failure warns and restores the snapshot, a success writes it'

# Every pin this section adds changed at once: the push step must make one
# commit per pin, each holding only its own files.
read -r origin clone <<<"$(setup_clone pi-push)"
base_sha=$("$git_bin" -C "$clone" rev-parse HEAD)
printf '{"data": [{"id": "hf:new/Model"}]}\n' >"$clone/home/h82/agents/synthetic-catalog.json"
printf '{"version": "1.5.0", "platforms": {}}\n' >"$clone/packages/pi-release.json"
printf '{"version": "0.0.34"}\n' >"$clone/packages/pi-acp-release.json"
printf '{"lockfileVersion": 3, "name": "pi-acp", "new": true}\n' >"$clone/packages/pi-acp/package-lock.json"
printf '{"version": "0.21.0"}\n' >"$clone/packages/acpx-release.json"
printf '{"lockfileVersion": 3, "name": "acpx", "new": true}\n' >"$clone/packages/acpx/package-lock.json"
(cd "$clone" && bash -e -c "$push_script") >"$scratch/pi-push-step.log" 2>&1 ||
  fail "the push step failed on the Pi pins: $(tail -n 5 "$scratch/pi-push-step.log")"
commits=$("$git_bin" --git-dir "$origin" log --reverse --format='%H %s' "$base_sha..main")
[[ $(wc -l <<<"$commits") == 4 ]] || fail "the Pi pins should land as four commits, found: $commits"
for expected in \
  'chore(agents): refresh the synthetic catalog snapshot|home/h82/agents/synthetic-catalog.json' \
  'chore(packages): bump pi to 1.5.0|packages/pi-release.json' \
  'chore(packages): bump pi-acp to 0.0.34|packages/pi-acp-release.json packages/pi-acp/package-lock.json' \
  'chore(packages): bump acpx to 0.21.0|packages/acpx-release.json packages/acpx/package-lock.json'; do
  subject=${expected%%|*} want=${expected#*|}
  sha=$(awk -v s="$subject" '{ sha = $1; sub(/^[^ ]+ /, "") } $0 == s { print sha }' <<<"$commits")
  [[ -n $sha ]] || fail "no commit '$subject' among: $commits"
  files=$("$git_bin" --git-dir "$origin" show --format= --name-only "$sha" | sort | paste -sd ' ')
  [[ $files == "$want" ]] || fail "'$subject' carries $files, want $want"
done
pass 'the snapshot, Pi, pi-acp, and acpx changes each land as their own commit with only their files'
