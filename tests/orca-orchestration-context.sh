#!/usr/bin/env bash
# Drives the session-start context script against stub Orca CLIs that print a
# generated guide, fail, hang, or leak a token to stderr.
#
#   orca-orchestration-context.sh SCRIPT          the source, placeholders rendered here
#   orca-orchestration-context.sh --packaged BIN  a built copy with its pinned CLI
set -euo pipefail

usage() {
  printf 'usage: %s SCRIPT | --packaged BIN\n' "${0##*/}" >&2
  exit 2
}

mode=source
if [[ ${1:-} == --packaged ]]; then
  [[ $# -eq 2 ]] || usage
  mode=packaged
  target=$2
else
  [[ $# -eq 1 ]] || usage
  target=$1
fi
[[ -f $target ]] || usage

scratch=$(mktemp -d "${TMPDIR:-/tmp}/orca-orchestration-context-tests.XXXXXX")
trap 'rm -rf -- "$scratch"' EXIT

fail() { printf 'orca-orchestration-context: FAIL (%s): %s\n' "$mode" "$*" >&2; exit 1; }
pass() { printf 'orca-orchestration-context: ok (%s) - %s\n' "$mode" "$*"; }

bash_bin=$(command -v bash) || fail 'bash is required'
# The stubs run under the test's bare PATH, so they name their tools by path.
cat_bin=$(command -v cat) || fail 'cat is required'
sleep_bin=$(command -v sleep) || fail 'sleep is required'
bin=$scratch/bin
mkdir -p "$bin"
ln -s "$bash_bin" "$bin/bash"

# A bare `orca` on PATH stands in for the GNOME screen reader: reaching it is
# a failure no matter what else the run prints.
screen_reader_mark=$scratch/screen-reader-ran
cat >"$bin/orca" <<STUB
#!$bash_bin
: >'$screen_reader_mark'
printf 'screen reader\n'
STUB
chmod +x "$bin/orca"

if [[ $mode == source ]]; then
  jq_bin=$(command -v jq) || fail 'jq is required'
  timeout_bin=$(command -v timeout) || fail 'timeout is required'
  pinned=$scratch/pinned-orca-cli
  script=$scratch/orca-orchestration-context
  sed -e "s|@ORCA_CLI@|$pinned|" -e "s|@JQ@|$jq_bin|" -e "s|@TIMEOUT@|$timeout_bin|" \
    -e "s|@CLAUDE_PARTS@|3|" -e "s|@CLI_PATH@|$(dirname "$cat_bin")|" \
    "$target" >"$script"
  chmod +x "$script"
  grep -q '@[A-Z_]*@' "$script" && fail 'a placeholder survived rendering'
else
  script=$target
  [[ -x $script ]] || fail "$script is not executable"
  # The pinned CLI must be the extracted AppImage's Node-mode entry point,
  # never the wrapper's GUI launcher.
  pinned=$(sed -n "s/^ORCA_CLI='\(.*\)'$/\1/p" "$script")
  [[ $pinned == /nix/store/*-extracted/resources/bin/orca-ide ]] ||
    fail "pinned CLI is '$pinned', not the extracted resources/bin/orca-ide"
  grep -q '@[A-Z_]*@' "$script" && fail 'a placeholder survived packaging'
  pass 'pinned CLI is the extracted Node-mode entry point'
fi

# --- stub CLIs ----------------------------------------------------------------

guide_file=$scratch/guide
calls=$scratch/calls

# Prints $guide_file for `skills get orchestration` and records each call.
make_cli() {
  local path=$1
  cat >"$path" <<STUB
#!$bash_bin
printf '%s\n' "\$0 \$*" >>'$calls'
[[ \$* == 'skills get orchestration' ]] || exit 3
printf 'ORCA_AGENT_HOOK_TOKEN=%s\n' "\${ORCA_AGENT_HOOK_TOKEN:-}" >&2
'$cat_bin' '$guide_file'
STUB
  chmod +x "$path"
}

good_cli=$scratch/good-cli
make_cli "$good_cli"
failing_cli=$scratch/failing-cli
printf '#!%s\n%q %q\nexit 1\n' "$bash_bin" "$cat_bin" "$guide_file" >"$failing_cli"
empty_cli=$scratch/empty-cli
printf '#!%s\nprintf "  \\n\\n"\n' "$bash_bin" >"$empty_cli"
slow_cli=$scratch/slow-cli
printf '#!%s\nexec %q 30\n' "$bash_bin" "$sleep_bin" >"$slow_cli"
chmod +x "$failing_cli" "$empty_cli" "$slow_cli"

# A deterministic guide of about $1 bytes: numbered lines, a blank line every
# tenth line, and non-ASCII text, so part boundaries and rejoining are tested
# on the shapes the real guide has.
write_guide() {
  local target_bytes=$1 i=0
  : >"$guide_file"
  while (($(stat -c %s "$guide_file") < target_bytes)); do
    i=$((i + 1))
    if ((i % 10 == 0)); then
      printf '\n' >>"$guide_file"
    else
      printf 'line %04d: coordinate workers — "quoted" \\ backslash 한국어\n' "$i" >>"$guide_file"
    fi
  done
  # Command substitution drops trailing newlines, so the guide ends on text.
  printf 'end of guide\n' >>"$guide_file"
}

# Runs the script with an explicit environment: PATH offers only bash and the
# screen-reader stub, so nothing is found by accident.
run() {
  env -i PATH="$bin" HOME="$scratch" ORCA_AGENT_HOOK_TOKEN=fake-hook-token-123 "$@"
}

in_orca() {
  run ORCA_PANE_KEY=pane-1 "$@"
}

# --- the Claude parts reassemble the guide ------------------------------------

write_guide 13000
: >"$calls"
for index in 1 2 3; do
  in_orca ORCA_CLI_COMMAND="$good_cli" "$script" --harness claude --part "$index" \
    >"$scratch/part$index" || fail "part $index exited non-zero"
done
[[ -s $scratch/part1 && -s $scratch/part2 ]] || fail 'a 13,000-byte guide did not produce two parts'
[[ ! -s $scratch/part3 ]] || fail 'part 3 printed text for a two-part guide'
for index in 1 2; do
  bytes=$(stat -c %s "$scratch/part$index")
  ((bytes < 10000)) || fail "part $index is $bytes bytes, over Claude Code's 10,000 cap"
  header=$(head -n 1 "$scratch/part$index")
  [[ $header == "Orca orchestration guide (injected at session start), part $index of 2" ]] ||
    fail "part $index header is '$header'"
  tail -n +3 "$scratch/part$index" >"$scratch/body$index"
done
# The Claude Code wait note is the last line of the last part and only there.
wait_note="Claude Code: run every Orca command that waits on an agent"
tail -n 1 "$scratch/part2" | grep -qF "$wait_note" || fail 'the last part does not end with the background-wait note'
grep -q 'run_in_background' "$scratch/part2" || fail 'the wait note does not name run_in_background'
grep -qF "$wait_note" "$scratch/part1" && fail 'the background-wait note appeared before the last part'
[[ -z $(tail -n 2 "$scratch/part2" | head -n 1) ]] || fail 'the wait note is not set off by a blank line'
head -n -2 "$scratch/body2" >"$scratch/body2.guide"
mv "$scratch/body2.guide" "$scratch/body2"
# Each body ends with the newline the script prints, which stands in for the
# newline between parts, so concatenating the bodies restores the guide.
cat "$scratch/body1" "$scratch/body2" >"$scratch/rejoined"
cmp -s "$scratch/rejoined" "$guide_file" || fail 'the parts do not rejoin to the guide byte for byte'
grep -q fake-hook-token-123 "$scratch"/part* && fail 'a token from the environment reached the output'
[[ $(wc -l <"$calls") -eq 3 ]] || fail 'each handler should call the CLI exactly once'
pass 'a 13,000-byte guide splits into two labeled parts that rejoin exactly'

# --- a guide past three parts names the full command --------------------------

write_guide 30000
in_orca ORCA_CLI_COMMAND="$good_cli" "$script" --harness claude --part 3 >"$scratch/part3" ||
  fail 'part 3 exited non-zero'
head -n 1 "$scratch/part3" | grep -q 'part 3 of 4$' || fail 'part 3 of a four-part guide is mislabeled'
tail -n 3 "$scratch/part3" | head -n 1 | grep -qF "Run \`$good_cli skills get orchestration\` for the rest." ||
  fail 'part 3 of an oversized guide does not point at the full command before the wait note'
tail -n 1 "$scratch/part3" | grep -qF "$wait_note" || fail 'part 3 of an oversized guide does not end with the wait note'
(($(stat -c %s "$scratch/part3") < 10000)) || fail 'part 3 with the overflow line is over the cap'
in_orca ORCA_CLI_COMMAND="$good_cli" "$script" --harness claude --part 4 >"$scratch/part4"
[[ -s $scratch/part4 ]] || fail 'part 4 is empty although the guide has four parts'
grep -qF "$wait_note" "$scratch/part4" && fail 'part 4 repeats the wait note Claude Code never receives'
pass 'a guide past three parts ends part 3 with the full command'

# --- Antigravity gets every part in order as one document ---------------------

write_guide 13000
in_orca ORCA_CLI_COMMAND="$good_cli" "$script" --harness antigravity >"$scratch/agy.json" ||
  fail 'antigravity exited non-zero'
jq_check=${jq_bin:-$(command -v jq)}
"$jq_check" -e '.injectSteps | length == 2 and all(.[]; keys == ["ephemeralMessage"])' \
  "$scratch/agy.json" >/dev/null || fail 'antigravity output is not two ephemeralMessage steps'
"$jq_check" -j '.injectSteps | map(.ephemeralMessage | split("\n\n") | .[1:] | join("\n\n")) | join("\n")' \
  "$scratch/agy.json" >"$scratch/agy-rejoined"
printf '\n' >>"$scratch/agy-rejoined"
cmp -s "$scratch/agy-rejoined" "$guide_file" || fail 'antigravity steps do not rejoin to the guide'
grep -qF "$wait_note" "$scratch/agy.json" && fail 'antigravity received the Claude Code wait note'
"$jq_check" -e '.injectSteps[0].ephemeralMessage | startswith("Orca orchestration guide (injected at session start), part 1 of 2")' \
  "$scratch/agy.json" >/dev/null || fail 'antigravity steps are out of order or unlabeled'
pass 'antigravity receives the parts in order as one injectSteps document'

# --- outside Orca, and every failure, prints nothing --------------------------

expect_silent() {
  local what=$1
  shift
  local out status=0
  out=$("$@" 2>&1) || status=$?
  ((status == 0)) || fail "$what: exited $status"
  [[ -z $out ]] || fail "$what: printed '$out'"
}

for args in '--harness claude --part 1' '--harness antigravity'; do
  # shellcheck disable=SC2086
  expect_silent "no ORCA_PANE_KEY ($args)" run ORCA_CLI_COMMAND="$good_cli" "$script" $args
  # shellcheck disable=SC2086
  expect_silent "empty ORCA_PANE_KEY ($args)" run ORCA_PANE_KEY= ORCA_CLI_COMMAND="$good_cli" "$script" $args
  # shellcheck disable=SC2086
  expect_silent "failing CLI ($args)" in_orca ORCA_CLI_COMMAND="$failing_cli" "$script" $args
  # shellcheck disable=SC2086
  expect_silent "blank guide ($args)" in_orca ORCA_CLI_COMMAND="$empty_cli" "$script" $args
  # shellcheck disable=SC2086
  expect_silent "missing CLI ($args)" in_orca ORCA_CLI_COMMAND="$scratch/absent" "$script" $args
done
started=$SECONDS
expect_silent 'hanging CLI' in_orca ORCA_CLI_COMMAND="$slow_cli" "$script" --harness claude --part 1
((SECONDS - started < 15)) || fail 'a hanging CLI was not cut off by the timeout'
for args in '--harness codex' '--harness claude' '--harness claude --part 0' \
  '--harness claude --part x' '--harness antigravity --part 1' '--bogus' '--harness'; do
  # shellcheck disable=SC2086
  expect_silent "arguments '$args'" in_orca ORCA_CLI_COMMAND="$good_cli" "$script" $args
done
pass 'outside Orca, failures, and bad arguments print nothing and exit 0'

# --- executable resolution ----------------------------------------------------

write_guide 2000
dev_bin=$scratch/dev-bin
mkdir -p "$dev_bin"
ln -s "$bash_bin" "$dev_bin/bash"
make_cli "$dev_bin/orca-dev"
: >"$calls"
in_orca PATH="$dev_bin:$bin" ORCA_DEV_REPO_ROOT=/src/orca "$script" --harness claude --part 1 >"$scratch/dev-part" ||
  fail 'orca-dev run exited non-zero'
grep -q "^$dev_bin/orca-dev skills get orchestration$" "$calls" || fail 'ORCA_DEV_REPO_ROOT did not select orca-dev'
[[ -s $scratch/dev-part ]] || fail 'orca-dev output was not injected'
expect_silent 'ORCA_DEV_REPO_ROOT without orca-dev' in_orca ORCA_DEV_REPO_ROOT=/src/orca "$script" --harness claude --part 1

if [[ $mode == source ]]; then
  # Orca's real entry point is a bash script that calls dirname and readlink
  # from PATH, and a hook inherits whatever PATH the agent started with. The
  # stub fails the same way under the test's bare PATH unless the script
  # supplies its own.
  make_cli "$pinned"
  sed -i "2i command -v dirname >/dev/null || exit 9" "$pinned"
  : >"$calls"
  in_orca "$script" --harness claude --part 1 >"$scratch/pinned-part" || fail 'pinned run exited non-zero'
  grep -q "^$pinned skills get orchestration$" "$calls" || fail 'the pinned CLI was not used by default'
  [[ -s $scratch/pinned-part ]] || fail 'the pinned CLI did not get the tools it needs on PATH'
fi
[[ ! -e $screen_reader_mark ]] || fail 'a bare orca on PATH was executed'
pass 'the CLI resolves as ORCA_CLI_COMMAND, then orca-dev, then the pinned path, never bare orca'
