---
title: OpenCode plugin loading is verifiable only by a live run, never by debug config or a sandboxed check
date: "2026-10-19"
last_updated: "2026-10-19"
category: integration-issues
module: OpenCode Compound Engineering plugin (scripts/agent-plugin-sync, home/h82/agents/opencode.nix)
problem_type: integration_issue
component: tooling
severity: medium
symptoms:
  - "opencode debug config lists the plugins path from every config layer but never shows whether the plugin loaded"
  - "A plugin directory without a root index.js is skipped with no message, so a missing entrypoint looks like a working configuration"
  - "opencode debug config in a scratch HOME with no network prints nothing and runs until killed (timeout 120)"
root_cause: wrong_api
resolution_type: workflow_improvement
related_components:
  - testing_framework
tags: ["opencode", "plugin", "compound-engineering", "verification", "opencode-config", "overlay", "cross-model-peer", "sandbox", "opencode-db"]
retire_when: "OpenCode reports loaded plugins without a model call (check: opencode debug --help lists a plugin subcommand), or opencode debug config finishes offline (check: env -i HOME=<scratch> opencode debug config under timeout 30 exits 0)"
---

# OpenCode plugin loading is verifiable only by a live run, never by debug config or a sandboxed check

## Problem

The repository writes the Compound Engineering plugin's pinned link into the `plugins` list of `~/.config/opencode/opencode.json` (`agent-plugin-sync --harness opencode`). Neither of the obvious checks shows that OpenCode loads it. `opencode debug config` reads config only, and a Nix check cannot run OpenCode at all. On OpenCode 2.0.32 the only evidence is a real run's debug log.

## Symptoms

- `opencode debug config` prints each layer it read (the global file, then `OPENCODE_CONFIG`, then `OPENCODE_CONFIG_CONTENT`) with the `plugins` array it found. It shows the same output whether or not the directory loads.
- OpenCode skips a plugin directory without a root `index.js` and prints nothing. The sync adapter therefore refuses such a source itself (`scripts/agent-plugin-sync:345-349`).
- Run the way a build sandbox would run it (`env -i HOME=<scratch>`, proxies pointed at `127.0.0.1:9`), `opencode debug config` printed nothing and was still running when `timeout 120` killed it.

## What Didn't Work

- **`opencode debug config` and `opencode debug agents` as the load probe.** Both exited 0 under the overlay. The debug log had no plugin lines, and `debug agents` returned `[]`. They prove the layering, not the load.
- **A repository check that runs OpenCode against the materialized `opencode.json`.** The review's testing-gap finding asked for one. The offline probe above showed it would hang in a sandbox, so the gap stays recorded in `docs/provisioning.md` rather than becoming a check that never finishes.

## Solution

Verify from the Mac, before deploying, with a scratch `OPENCODE_CONFIG` overlay. OpenCode loads it after the global file, and the wrapper never sets `OPENCODE_CONFIG`, so a caller's value passes through (`tests/opencode.sh` checks both):

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

OpenCode resolves and imports plugins only when it starts a session server, which `opencode run` does and `debug config` does not. The overlay reproduces the generation's config for one process without `nr switch`, which the repository forbids as validation. A sandbox check fails for a different reason: `debug config` does not finish without network access, so it cannot be the runner even for layering.

## Prevention

- After a change to the plugin path, the pin, or OpenCode itself, rerun the live probe above and the post-activation step in `docs/verification.md`. Every repository check stays green when OpenCode stops loading the plugin.
- Keep the sync adapter's `index.js` refusal. It is the only guard against the silent skip.
- When measuring a peer, confirm `model.id` in `session_message` before trusting the numbers. A missing overlay runs the deployed model instead.

## Related Issues

- #239, #240, #241 (open until this branch merges): the peer rule, the timing bound, and the model switch this verification served.
- [agy CLI ignores GEMINI_HOME](agy-cli-ignores-gemini-home-cannot-verify-t3-instance-homes.md): the same shape for Antigravity, where a CLI cannot show what a session loads and a live probe answers instead.
- [OpenCode v2's shared background server keeps the first client's environment](opencode-v2-shared-background-server-keeps-first-client-env.md): why a probe's environment reaches its own server.
