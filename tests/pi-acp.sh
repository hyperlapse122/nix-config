#!/usr/bin/env bash
# Drives the packaged acpx through its `pi` and `pi-readonly` agents.
#
#   pi-acp.sh stub ACPX PI_COMMAND READONLY_COMMAND
#     ACPX was built over a Pi stub that records its argv and environment
#     under $PI_STUB_LOG and exits. Asserts what each agent hands Pi.
#   pi-acp.sh real ACPX PI
#     ACPX was built over the packaged Pi wrapper PI. Asserts that each agent
#     opens a session through Pi in RPC mode, and that a checkout's
#     .pi/extensions/ and .acpxrc.json run nothing.
#   pi-acp.sh mutant ACPX PI
#     ACPX was built over a Pi that exits at once. Asserts that the session
#     the real case expects never comes back, so the real case reaches Pi.
set -euo pipefail

fail() {
  echo "pi-acp: $*" >&2
  exit 1
}

mode=$1
acpx=$2/bin/acpx

work=$(mktemp -d)
export HOME=$work/home
repo=$work/repo
mkdir -p "$HOME/.pi/agent" "$repo" "$work/bin"

# acpx falls back to npx for a built-in agent it cannot resolve; an npx that
# runs leaves a mark.
cat > "$work/bin/npx" <<EOF
#!$BASH
touch '$work/npx-ran'
exit 1
EOF
chmod +x "$work/bin/npx"
export PATH=$work/bin:$PATH

# Exported keys a calling session might carry; neither may reach Pi.
export SYNTHETIC_API_KEY=fake-synthetic-key-for-tests
export EXA_API_KEY=fake-exa-key-for-tests
# A caller's own choice of Pi must not win over the packaged one.
export PI_ACP_PI_COMMAND=/var/empty/not-pi

new_session() {
  local agent=$1
  shift
  (cd "$repo" && "$acpx" --format json --cwd "$repo" "$agent" sessions new --name "$agent-$RANDOM" "$@")
}

# The last line of `sessions new` in JSON format names the ACP session and
# the acpx record that holds the argv acpx started.
session_id() {
  printf '%s\n' "$1" | tail -n 1 | jq -r '.acpxSessionId // empty'
}

agent_argv() {
  local record
  record=$(printf '%s\n' "$1" | tail -n 1 | jq -r '.acpxRecordId')
  jq -r '.agent_argv | join(" ")' "$HOME/.acpx/sessions/$record.json"
}

pi_settings() {
  cat > "$HOME/.pi/agent/settings.json" <<EOF
{"defaultProjectTrust": "$1", "defaultProvider": "synthetic", "defaultModel": "hf:test/model"}
EOF
}

case $mode in
  stub)
    pi_command=$3
    readonly_command=$4
    export PI_STUB_LOG=$work/log
    for agent in pi pi-readonly; do
      rm -rf "$PI_STUB_LOG"
      mkdir -p "$PI_STUB_LOG"
      # The stub exits before answering, so the session fails; only what
      # reached the stub matters here.
      new_session "$agent" > "$work/out" 2>&1 || true
      [ -s "$PI_STUB_LOG/argv" ] || {
        cat "$work/out" >&2
        fail "$agent never started Pi"
      }
      if [ "$agent" = pi ]; then expected=$pi_command; else expected=$readonly_command; fi
      grep -qxF "PI_ACP_PI_COMMAND=$expected" "$PI_STUB_LOG/env" ||
        fail "$agent did not set PI_ACP_PI_COMMAND to $expected: $(grep '^PI_ACP_PI_COMMAND=' "$PI_STUB_LOG/env" || echo unset)"
      for key in SYNTHETIC_API_KEY EXA_API_KEY; do
        if grep -q "^$key=" "$PI_STUB_LOG/env"; then
          fail "$agent passed $key to Pi"
        fi
      done
      grep -qxF -- '--mode' "$PI_STUB_LOG/argv" || fail "$agent did not start Pi in RPC mode"
      if grep -qE -- '^(--tools|-t)$' "$PI_STUB_LOG/argv"; then
        fail "$agent passed a --tools allowlist"
      fi
      if [ "$agent" = pi-readonly ]; then
        [ "$(head -n 2 "$PI_STUB_LOG/argv" | paste -sd ' ')" = "--exclude-tools bash,edit,write" ] ||
          fail "pi-readonly did not exclude bash, edit, and write: $(paste -sd ' ' "$PI_STUB_LOG/argv")"
      elif grep -qxF -- '--exclude-tools' "$PI_STUB_LOG/argv"; then
        fail "pi excluded tools: $(paste -sd ' ' "$PI_STUB_LOG/argv")"
      fi
    done
    ;;

  real | mutant)
    pi=$3
    # The Synthetic provider as models.json declares it, with a base URL that
    # is never reached: opening a session lists models and sends no request.
    cat > "$HOME/.pi/agent/models.json" <<EOF
{"providers": {"synthetic": {
  "name": "Synthetic",
  "baseUrl": "http://127.0.0.1:9/v1",
  "api": "openai-completions",
  "apiKey": "!$pi/bin/pi-synthetic-key",
  "models": [{"id": "hf:test/model", "name": "Test", "reasoning": false, "input": ["text"], "contextWindow": 1000, "maxTokens": 100}]
}}}
EOF
    # A project extension that leaves a mark when Pi loads it.
    mkdir -p "$repo/.pi/extensions"
    cat > "$repo/.pi/extensions/marker.js" <<EOF
require("fs").writeFileSync("$work/extension-loaded", "loaded");
module.exports = function () {};
EOF
    # A project config that would rebind both agents to a command that leaves
    # a mark.
    cat > "$repo/.acpxrc.json" <<EOF
{"agents": {
  "pi": {"argv": ["$BASH", "-c", "touch $work/acpxrc-ran"]},
  "pi-readonly": {"argv": ["$BASH", "-c", "touch $work/acpxrc-ran"]}
}}
EOF
    pi_settings never

    if [ "$mode" = mutant ]; then
      if out=$(new_session pi 2>&1) && [ -n "$(session_id "$out")" ]; then
        fail "a Pi that exits at once still yielded a session: $out"
      fi
      exit 0
    fi

    for agent in pi pi-readonly; do
      out=$(new_session "$agent" 2>&1) || {
        [ ! -e "$work/acpxrc-ran" ] || fail "acpx ran an agent from the checkout's .acpxrc.json"
        fail "$agent sessions new failed: $out"
      }
      [ -n "$(session_id "$out")" ] || fail "$agent returned no session ID: $out"
      argv=$(agent_argv "$out")
      case $agent:$argv in
        pi:/nix/store/*/bin/pi-acp | pi-readonly:/nix/store/*/bin/pi-acp-readonly) ;;
        *) fail "$agent ran $argv instead of the packaged adapter" ;;
      esac
    done
    [ ! -e "$work/npx-ran" ] || fail "acpx ran npx"
    [ ! -e "$work/acpxrc-ran" ] || fail "acpx ran an agent from the checkout's .acpxrc.json"
    [ ! -e "$work/extension-loaded" ] || fail "Pi loaded the checkout's .pi/extensions/marker.js"

    # The same checkout, trusted, loads the marker: the probe above can see a
    # project extension load.
    pi_settings always
    out=$(new_session pi 2>&1) || fail "pi sessions new with trusted projects failed: $out"
    [ -e "$work/extension-loaded" ] || fail "marker.js never loaded even in a trusted checkout, so its absence proves nothing"
    ;;

  *)
    fail "unknown mode $mode"
    ;;
esac
