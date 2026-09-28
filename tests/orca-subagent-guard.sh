#!/usr/bin/env bash
# Drives the subagent guard with Claude Code and Antigravity PreToolUse
# payloads, inside and outside an Orca environment.
#
#   orca-subagent-guard.sh SCRIPT          the source, placeholders rendered here
#   orca-subagent-guard.sh --packaged BIN  a built copy with jq pinned
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

scratch=$(mktemp -d "${TMPDIR:-/tmp}/orca-subagent-guard-tests.XXXXXX")
trap 'rm -rf -- "$scratch"' EXIT

fail() { printf 'orca-subagent-guard: FAIL (%s): %s\n' "$mode" "$*" >&2; exit 1; }
pass() { printf 'orca-subagent-guard: ok (%s) - %s\n' "$mode" "$*"; }

jq_bin=$(command -v jq) || fail 'jq is required'
bash_bin=$(command -v bash) || fail 'bash is required'
bin=$scratch/bin
mkdir -p "$bin"
ln -s "$bash_bin" "$bin/bash"

if [[ $mode == source ]]; then
  script=$scratch/orca-subagent-guard
  sed -e "s|@JQ@|$jq_bin|" "$target" >"$script"
  chmod +x "$script"
  grep -q '@[A-Z_]*@' "$script" && fail 'a placeholder survived rendering'
else
  script=$target
  [[ -x $script ]] || fail "$script is not executable"
  grep -q '@[A-Z_]*@' "$script" && fail 'a placeholder survived packaging'
  pinned=$(sed -n "s/^JQ='\(.*\)'$/\1/p" "$script")
  [[ $pinned == /nix/store/*/bin/jq ]] || fail "jq is '$pinned', not a store path"
  pass 'jq is pinned by store path'
fi

# PATH offers only bash, so the guard cannot find jq by accident.
run() {
  local payload=$1
  shift
  printf '%s' "$payload" | env -i PATH="$bin" HOME="$scratch" ORCA_AGENT_HOOK_TOKEN=fake-hook-token-123 "$@"
}

in_orca() {
  local payload=$1
  shift
  run "$payload" ORCA_PANE_KEY=pane-1 "$@"
}

claude_payload() {
  printf '{"session_id":"s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":{"prompt":"hi"}}' "$1"
}

antigravity_payload() {
  printf '{"conversationId":"c","stepIdx":4,"toolCall":{"args":{"Subagents":[]},"name":"%s"},"workspacePaths":[]}' "$1"
}

expect_silent() {
  local what=$1
  shift
  local out status=0
  out=$("$@" 2>&1) || status=$?
  ((status == 0)) || fail "$what: exited $status"
  [[ -z $out ]] || fail "$what: printed '$out'"
}

# --- Claude Code --------------------------------------------------------------

for tool in Agent Task; do
  out=$(in_orca "$(claude_payload "$tool")" "$script" --harness claude) || fail "claude $tool exited non-zero"
  "$jq_bin" -e '.hookSpecificOutput.hookEventName == "PreToolUse"
    and .hookSpecificOutput.permissionDecision == "deny"
    and (.hookSpecificOutput.permissionDecisionReason | contains("/orchestration"))' \
    <<<"$out" >/dev/null || fail "claude $tool was not denied with an /orchestration reason: $out"
  grep -q fake-hook-token-123 <<<"$out" && fail 'a token from the environment reached the output'
done
out=$(in_orca 'not json' "$script" --harness claude) || fail 'claude unparseable payload exited non-zero'
"$jq_bin" -e '.hookSpecificOutput.permissionDecision == "deny"' <<<"$out" >/dev/null ||
  fail 'claude unparseable payload inside Orca was not denied'
pass 'claude denies Agent, Task, and an unparseable payload inside Orca'

# The reason is what the agent reads when it decides how to carry on. Skills
# fall back to inline or serial work when subagents are unavailable, so the
# reason must say the work still goes to Orca workers and never offer doing
# it in this session. The guide keeps the coordinator role for an explicit
# request to supervise, so the reason also says the denied call is one. A
# worker at Orca's nesting depth limit cannot start another, so that refusal
# alone permits in-session work.
check_reason() {
  local harness=$1 reason=$2 word
  for word in 'orchestration worker-start' 'worker_done' 'inline or serial fallback' 'does not mean' \
    'itself the request to supervise' 'however small' "Only if worker-start refuses because this session is at Orca's nesting depth limit"; do
    grep -qF -- "$word" <<<"$reason" || fail "the $harness deny reason does not say '$word': $reason"
  done
  grep -qiE 'or do the work yourself|do it yourself' <<<"$reason" &&
    fail "the $harness deny reason offers doing the delegated work inline: $reason"
  return 0
}
check_reason claude "$("$jq_bin" -r '.hookSpecificOutput.permissionDecisionReason' \
  <<<"$(in_orca "$(claude_payload Agent)" "$script" --harness claude)")"
pass 'the deny reason sends the denied work to Orca workers, not inline'

for tool in Workflow Bash AgentOutput; do
  expect_silent "claude $tool inside Orca" in_orca "$(claude_payload "$tool")" "$script" --harness claude
done
pass 'claude leaves Workflow and every other tool alone'

# --- Antigravity --------------------------------------------------------------

out=$(in_orca "$(antigravity_payload invoke_subagent)" "$script" --harness antigravity) ||
  fail 'antigravity invoke_subagent exited non-zero'
"$jq_bin" -e 'keys == ["decision", "reason"] and .decision == "deny" and (.reason | contains("/orchestration"))' \
  <<<"$out" >/dev/null || fail "antigravity invoke_subagent was not denied with an /orchestration reason: $out"
[[ $(wc -l <<<"$out") -eq 1 ]] || fail 'antigravity deny is not exactly one JSON line'
check_reason antigravity "$("$jq_bin" -r '.reason' <<<"$out")"
pass 'antigravity denies invoke_subagent inside Orca'

for tool in run_command define_subagent send_message; do
  expect_silent "antigravity $tool inside Orca" in_orca "$(antigravity_payload "$tool")" "$script" --harness antigravity
done
expect_silent 'antigravity unparseable payload' in_orca 'not json' "$script" --harness antigravity
expect_silent 'antigravity empty payload' in_orca '' "$script" --harness antigravity
pass 'antigravity prints nothing for other tools and unparseable payloads'

# --- outside Orca and bad arguments -------------------------------------------

expect_silent 'claude without ORCA_PANE_KEY' run "$(claude_payload Agent)" "$script" --harness claude
expect_silent 'claude with empty ORCA_PANE_KEY' run "$(claude_payload Agent)" ORCA_PANE_KEY= "$script" --harness claude
expect_silent 'antigravity without ORCA_PANE_KEY' run "$(antigravity_payload invoke_subagent)" "$script" --harness antigravity
expect_silent 'antigravity with empty ORCA_PANE_KEY' run "$(antigravity_payload invoke_subagent)" ORCA_PANE_KEY= "$script" --harness antigravity
for args in '' '--harness' '--harness codex' '--bogus' '--harness claude --part 1'; do
  # shellcheck disable=SC2086
  expect_silent "arguments '$args'" in_orca "$(claude_payload Agent)" "$script" $args
done
pass 'outside Orca and with bad arguments the guard prints nothing and exits 0'
