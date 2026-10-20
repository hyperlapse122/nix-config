---
title: OpenCode plugin and skill loading is verifiable only by a live session server, never by debug config or a sandboxed check
date: "2026-10-19"
last_updated: "2026-10-20"
category: integration-issues
module: OpenCode Compound Engineering plugin and standalone skills (scripts/agent-plugin-sync, home/h82/agents/opencode.nix, home/h82/agents/korean-skills.nix)
problem_type: integration_issue
component: tooling
severity: medium
symptoms:
  - "opencode debug config lists the plugins path from every config layer but never shows whether the plugin or skills loaded"
  - "A plugin directory without a root index.js is skipped with no message, so a missing entrypoint looks like a working configuration"
  - "opencode debug config in a scratch HOME with no network prints nothing and runs until killed (timeout 120)"
root_cause: wrong_api
resolution_type: workflow_improvement
related_components:
  - testing_framework
tags: ["opencode", "plugin", "skills", "compound-engineering", "verification", "opencode-config", "overlay", "cross-model-peer", "sandbox", "opencode-db"]
retire_when: "opencode debug --help lists a plugin or skill subcommand, or opencode debug config finishes offline (check: env -i HOME=<scratch> opencode debug config under timeout 30 exits 0)"
---

# OpenCode plugin and skill loading is verifiable only by a live session server, never by debug config or a sandboxed check

## Problem

The repository writes the Compound Engineering plugin's pinned link into the `plugins` list of `~/.config/opencode/opencode.json` (`agent-plugin-sync --harness opencode`) and links standalone skills such as `humanizer`, `grammar-checker`, and `style-guide` under `~/.config/opencode/skills/<name>` (`home/h82/agents/korean-skills.nix`). Neither `opencode debug config` nor a Nix build check can verify that OpenCode loads them: `opencode debug config` reads config layers without starting the session server that resolves plugins and skills, and OpenCode hangs inside an offline build sandbox. On OpenCode 2.0.32, verification requires starting a live session server on the host—either headlessly via `opencode serve` and `GET /api/skill` (no model call) or through `opencode run`.

## Symptoms

- `opencode debug config` prints each layer it read (the global file, then `OPENCODE_CONFIG`, then `OPENCODE_CONFIG_CONTENT`) with the `plugins` array it found. It shows the same output whether or not the directory loads.
- OpenCode skips a plugin directory without a root `index.js` and prints nothing. The sync adapter therefore refuses such a source itself (`scripts/agent-plugin-sync:345-349`).
- Run the way a build sandbox would run it (`env -i HOME=<scratch>`, proxies pointed at `127.0.0.1:9`), `opencode debug config` printed nothing and was still running when `timeout 120` killed it.

## What Didn't Work

- **`opencode debug config` and `opencode debug agents` as the load probe.** Both exited 0 under the overlay. The debug log had no plugin lines, and `debug agents` returned `[]`. They prove the layering, not the load.
- **A repository check that runs OpenCode against the materialized `opencode.json`.** The review's testing-gap finding asked for one. The offline probe above showed it would hang in a sandbox, so the gap stays recorded in `docs/provisioning.md` rather than becoming a check that never finishes.

## Solution

### 1. Headless skill and plugin probe without a model call (`opencode serve` + `GET /api/skill`)

To verify that OpenCode loads plugins listed in `~/.config/opencode/opencode.json` or standalone skills under `~/.config/opencode/skills/<name>` without spending model tokens, start `opencode serve` in a scratch `HOME` with `~/.config/opencode/service.json` set to `{"disabled": true}` (so the client does not reuse a background server), `OPENCODE_SERVER_PASSWORD` set, and the wrapper's four disable switches enabled (`scripts/opencode`, tested in `tests/opencode.sh:126-131`):

```sh
scratch=$(mktemp -d)
home=$scratch/home
ws=$scratch/ws
mkdir -p "$home/.config/opencode" "$ws"
printf '{"disabled": true}\n' > "$home/.config/opencode/service.json"
printf '{"$schema": "https://opencode.ai/config.json", "plugins": ["%s"]}\n' \
  "$(readlink -f ~/.local/share/agent-plugins/compound-engineering/v3.31.0)" \
  > "$home/.config/opencode/opencode.json"

env -i HOME="$home" PATH=/run/current-system/sw/bin \
  XDG_CONFIG_HOME="$home/.config" XDG_DATA_HOME="$home/.local/share" \
  XDG_CACHE_HOME="$home/.cache" XDG_STATE_HOME="$home/.local/state" \
  OPENCODE_SERVER_PASSWORD=probe \
  OPENCODE_DISABLE_AUTOUPDATE=true \
  OPENCODE_DISABLE_PROJECT_CONFIG=true \
  OPENCODE_CONFIG_PROJECT_DISABLE=true \
  OPENCODE_DISABLE_CLAUDE_CODE=true \
  opencode serve --port 4097 --hostname 127.0.0.1 >"$scratch/serve.log" 2>&1 &
srv_pid=$!

for _ in $(seq 1 30); do
  out=$(curl -s -u opencode:probe "http://127.0.0.1:4097/api/skill?location%5Bdirectory%5D=$ws" || true)
  printf '%s' "$out" | grep -q '"ce-plan"' && break
  sleep 1
done
kill "$srv_pid"; wait "$srv_pid" 2>/dev/null || true
```

Key details of this probe on OpenCode 2.0.32:

- Without `OPENCODE_SERVER_PASSWORD` and HTTP basic auth (`opencode:<password>`), `GET /api/skill` returns `{"_tag":"UnauthorizedError"}`.
- Skills and plugins load asynchronously after the server prints `server listening`, so poll `GET /api/skill?location[directory]=<dir>` for a few seconds until the expected skill name appears.
- On 2026-10-20, this probe returned all 34 `ce-` skills from the Compound Engineering plugin and, when `~/.config/opencode/skills/{humanizer,grammar-checker,style-guide}` were linked in the scratch `HOME`, returned each standalone skill once without reading `~/.claude/skills` (`OPENCODE_DISABLE_CLAUDE_CODE=true` gates `~/.claude/skills` while leaving `~/.config/opencode/skills` and `~/.agents/skills` active).

### 2. Live run and peer-timing probe (`opencode run` + `OPENCODE_CONFIG` overlay)

When verifying `loading plugin` log lines or measuring a Compound Engineering review peer before deploying, use a scratch `OPENCODE_CONFIG` overlay. OpenCode loads it after the global file, and the wrapper never sets `OPENCODE_CONFIG`, so a caller's value passes through (`tests/opencode.sh:196-207`):

```sh
overlay=$scratch/overlay.json
printf '{"plugins": ["%s"], "model": "synthetic/hf:zai-org/GLM-5.3", "provider": {"synthetic": {"models": {"hf:zai-org/GLM-5.3": {"options": {"reasoningEffort": "max"}}}}}}\n' \
  "$HOME/.local/share/agent-plugins/compound-engineering/v3.31.0" > "$overlay"
cd "$scratch/work"
OPENCODE_CONFIG=$overlay opencode run --print-logs --log-level debug \
  "Without using any tools, list the names of the skills available to you that start with ce-, comma-separated." \
  > run.out 2> run.log
grep 'loading plugin' run.log     # msg="loading plugin" id=<link> entrypoint=file:///nix/store/...-source/index.js
grep -iE 'install|npm|bun add|download' run.log   # empty: nothing fetched for the plugin
```

The overlay carries the deployed default: `hf:zai-org/GLM-5.3` with `reasoningEffort` pinned to `max` per model, because OpenCode 2.0.32 drops a `#variant` written in a config file. On 2026-10-18 this run, then pointed at `hf:zai-org/GLM-5.3-Flash` at default effort, took 9 s and listed all 34 `ce-` skills. Arrays concatenate across layers, so a path the global file already lists loads twice under such an overlay. Name it in only one layer.

The same overlay covers a Compound Engineering review peer. Put `OPENCODE_CONFIG=<overlay>` in the environment of `peer-job-runner.py start`, both before the runner and in its `env` prefix; the peer then runs the undeployed model and plugin. Read the timing afterwards from `~/.local/share/opencode/opencode.db`, taking only structure and numbers, never content:

```python
import json, os, sqlite3
db = sqlite3.connect(os.path.expanduser("~/.local/share/opencode/opencode.db"))
sid = db.execute("select id from session_v2 order by time_created desc limit 1").fetchone()[0]
for seq, data in db.execute(
        "select seq, data from session_message where session_id=? and type='assistant' order by seq", (sid,)):
    d = json.loads(data)
    print(seq, d["model"]["id"], (d["time"]["completed"] - d["time"]["created"]) // 1000,
          d["tokens"]["reasoning"], d["tokens"]["output"], d["finish"])
```

That peer, on a 1,935-line diff and on `hf:zai-org/GLM-5.3-Flash` at default effort, finished in 953 s over 8 turns, with 0 reasoning tokens per turn and a final `stop`. Issue #240 recorded `syn:large:text` at 18 turns and about 72K reasoning tokens, cut off at 1200 s.

## Why This Works

OpenCode resolves and imports plugins and skills only when it starts a session server, which both `opencode serve` and `opencode run` do and `debug config` does not. Querying `GET /api/skill` on an isolated `opencode serve` instance exercises the session server's skill loader without making a model request, while the `OPENCODE_CONFIG` overlay reproduces a generation's config for one process without `nr switch`, which the repository forbids as validation. A sandbox check still fails because OpenCode's startup does not finish without network access in a Nix build sandbox.

## Prevention

- After a change to the plugin path, standalone skill links, the pin, or OpenCode itself, run the `opencode serve` `/api/skill` probe above and the post-activation step in `docs/verification.md`. Every repository check stays green when OpenCode stops loading a plugin or skill.
- Keep the sync adapter's `index.js` refusal (`scripts/agent-plugin-sync:345-349`). It is the only build-time guard against the silent skip.
- When measuring a peer, confirm `model.id` in `session_message` before trusting the numbers. A missing overlay runs the deployed model instead.

## Related Issues

- #239, #240, #241: the peer rule, the timing bound, and the model switch this verification served.
- [OpenCode silently drops a model variant written in its config file](opencode-config-file-model-variant-silently-dropped.md): why the overlay pins `reasoningEffort` per model rather than via a `#variant` suffix.
- [agy CLI ignores GEMINI_HOME](agy-cli-ignores-gemini-home-cannot-verify-t3-instance-homes.md): the same shape for Antigravity, where a CLI cannot show what a session loads and a live daemon probe answers instead.
- [OpenCode v2's shared background server keeps the first client's environment](opencode-v2-shared-background-server-keeps-first-client-env.md): why a probe's environment reaches its own server when `service.json` sets `{"disabled": true}`.
