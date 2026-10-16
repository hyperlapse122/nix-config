---
title: OpenCode v2's shared background server keeps the first client's key and switches
date: "2026-10-17"
category: integration-issues
module: OpenCode wrapper and settings (Home Manager activation)
problem_type: integration_issue
component: activation
severity: high
symptoms:
  - "After a key rotation, OpenCode keeps authenticating with the old OPENCODE_API_KEY until the background server is restarted"
  - "A key or OPENCODE_DISABLE_* switch exported for one run has no effect on that run"
  - "After a pin bump, `opencode --version` prints the new version while requests are served by the old binary"
  - "`opencode debug config` leaves a `serve --service` process running after it exits, including inside a Nix build sandbox"
root_cause: wrong_api
resolution_type: config_change
tags: ["opencode", "opencode-v2", "background-server", "service-json", "managed-service", "wrapper", "environment", "OPENCODE_CONFIG_PROJECT_DISABLE", "OPENCODE_DISABLE_PROJECT_CONFIG", "home-manager", "activation", "debug-config"]
retire_when: "OpenCode stops reusing a detached background server across client commands by default, or starts the server per run with each client's own environment; check the pinned source's ServerConnection.resolve for the service.json `disabled` branch"
---

# OpenCode v2's shared background server keeps the first client's key and switches

## Problem

OpenCode 1.x ran each command in its own process, so the wrapper `scripts/opencode` could export the API key and its `OPENCODE_DISABLE_*` switches for every run. OpenCode v2 is a client and a server. The first client command starts a detached `opencode serve --service` background server, and every later command connects to that server. The server keeps the environment of the command that started it, so the wrapper's exports reach only that first run. Every later run silently uses the first run's key, switches, and binary.

## Symptoms

- A rotated key, or a key a caller exports for one run, is ignored until the background server is restarted.
- A pin bump installs a new binary, but the long-lived server keeps serving the old version.
- In the `opencode-wrapper` check, `opencode debug config` started a background server that kept running after the probe exited (observed on darwin with the built 2.0.31 binary).

## What Didn't Work

- **Passing `--standalone` to the probe.** This was the plan's first design: `opencode debug config --standalone` should start a per-command server. But `debug config` resolves its server with no arguments, `ServerConnection.resolve()` at `packages/cli/src/commands/handlers/debug/config.ts:13` in the v2.0.31 source. So the flag never reaches it, and the probe still starts the shared server. The document review's feasibility pass and the Codex reviewer both caught this before implementation.
- **Relying on the wrapper's exports alone.** They are correct for the first run and wrong for every later run that reuses the server.
- **Writing `disabled = true` into `service.json` and stopping there.** OpenCode's own `opencode service set disabled true` also calls `Service.stop` (`packages/cli/src/services/service-config.ts:251`). Writing the file directly, as activation does, leaves a server that is already running alive with its old key and binary. The in-process adversarial review found this from the source.

## Solution

Paths under `packages/` cite the upstream OpenCode repository (anomalyco/opencode) at tag v2.0.31, not this flake.

1. **Disable the shared server declaratively.** `ServerConnection.resolve` uses a per-command standalone server, stopped on exit, when `args.standalone` is set or `service.json` has `disabled: true` (`packages/cli/src/services/server-connection.ts:41`). Activation merges that key into `~/.config/opencode/service.json` and leaves the password, port, and env OpenCode writes there alone (`home/h82/agents/opencode.nix:51`, `declaredService`).
2. **Stop a server that is already running.** A separate activation entry runs after that merge (`home/h82/agents/opencode.nix:81`):

   ```nix
   home.activation.opencodeServiceStop = lib.hm.dag.entryAfter [ "opencodeService" ] ''
     ${wrapper}/bin/opencode service stop \
       || echo "OpenCode: could not stop the background server; run 'opencode service stop'" >&2
   '';
   ```

   `opencode service stop` exits 0 when no server is registered, so it is safe on every apply.
3. **Probe in a private config home with the server disabled.** The `opencode-wrapper` check sets `XDG_CONFIG_HOME`, `XDG_STATE_HOME`, and `XDG_DATA_HOME` under `$TMPDIR`, writes `{"disabled": true}` to that `service.json` (`flake.nix:1576`), runs the probes, and then fails if any process of the pinned binary is still running (`flake.nix:1599`-`1605`). A missing `pgrep` also fails the check, so the leftover-server assertion cannot pass blind.
4. **Set both project-config names.** v2 reads `OPENCODE_CONFIG_PROJECT_DISABLE` before `OPENCODE_DISABLE_PROJECT_CONFIG` (`packages/cli/src/server-process.ts:120`), so a caller that exports the new name as `0` turns project config back on. The wrapper exports both (`scripts/opencode:38`-`39`). The check probes a caller's `OPENCODE_CONFIG_PROJECT_DISABLE=0` and requires that the canary stays out (`flake.nix:1583`, `1592`).

## Why This Works

With `disabled: true`, every client command starts its own server from its own process environment and stops it on exit. The wrapper's exported key and switches therefore apply to every run, and a pin bump takes effect on the next command. `opencode service stop` removes the one server started before the change. Because v2 now reads two names for the project-config switch, a wrapper that sets only the legacy name has a gap that the v1-era tests could not see.

## Prevention

- When OpenCode or another agent CLI moves to a client/server or daemon model, check whether a long-lived process captures the environment of the run that spawned it. A wrapper that exports per-run environment is defeated by any shared process.
- Look up every environment variable a wrapper sets in the new version's source, including any alias read with `??` ahead of the old name. A source search for the old name alone misses a new name that takes precedence.
- Make a probe that starts a process assert that the process is gone afterwards, and make it fail when the tool it uses to look (`pgrep`) is absent.
- A caller that sets `OPENCODE_CONFIG_DIR` reads `service.json` from that directory instead. T3 Code sets no such variable and launches `opencode serve`, which is its own server and never uses the shared one (observed from the running T3 Code process environment in this session). Recheck this if T3 Code starts setting `OPENCODE_CONFIG_DIR`.
- The full migration is recorded in the [OpenCode v2 plan](../../plans/2026-10-17-0302-feat-opencode-v2-plan.md).
- Related: [a pause process started inside an agent sandbox poisons the host Podman service](orca-sandbox-pause-process-poisons-host-rootless-podman.md) is the same shape, a long-lived user service that keeps the context of the invocation that started it. [Claude Code ignores global-config keys declared in settings.json](claude-code-global-config-keys-ignored-in-settings-json.md) is why the declared `service.json` key is backed by the source line that reads it. The merge reasserts `disabled` only on a new generation; see [activation does not re-run when the generation is unchanged](../best-practices/home-manager-activation-does-not-run-on-every-rebuild.md).
