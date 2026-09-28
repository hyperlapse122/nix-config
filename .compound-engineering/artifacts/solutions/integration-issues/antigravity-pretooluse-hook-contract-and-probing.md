---
title: Antigravity PreToolUse hook contract and how to probe it safely
date: "2026-09-28"
category: integration-issues
module: Orca subagent guard (Antigravity hooks)
problem_type: best_practice
component: tooling
severity: medium
tags: ["antigravity", "agy", "hooks", "pretooluse", "orca", "claude-code", "subagent"]
retire_when: "Antigravity documents its PreToolUse payload and decision contract, or scripts/orca-subagent-guard no longer targets Antigravity"
---

# Antigravity PreToolUse hook contract and how to probe it safely

## Context

`scripts/orca-subagent-guard` refuses Antigravity's `invoke_subagent` inside Orca through a `PreToolUse` entry in `~/.gemini/config/hooks.json`. Antigravity 1.2.9 publishes no hook payload schema. The binary only names a `decision` enum (`allow`, `deny`, `ask`, `force_ask`, `deny_unless_prior_grant`) and a `reason` that is required when the decision is not `allow`. The guard was built on the behavior probed live on 2026-09-28. The probes are the only record of it.

## Guidance

What Antigravity 1.2.9 does with a `PreToolUse` hook under matcher `*`:

- **Payload.** The hook reads JSON on stdin. The tool name is `.toolCall.name` (for example `invoke_subagent`, `run_command`), and the arguments are under `.toolCall.args`. Neither is `tool_name`, the name Claude Code uses.
- **Deny.** `{"decision":"deny","reason":"..."}` blocks the call. It still blocks when Orca's own `orca-status` hook answers `{"decision":"ask"}` for the same call. The model sees `tool call denied by pre-tool hook: <reason>` verbatim.
- **Silence is neutral.** A hook that prints nothing leaves the call alone, and the tool runs. That is why the guard prints nothing for every other tool and never prints `allow`, which could override Orca's `ask`.

How to probe it without breaking the user's setup:

- A workspace-local `<workspace>/.agents/hooks.json` in an untrusted scratch directory was **not** loaded by `agy -p`: no payload was captured. Probe through the global `~/.gemini/config/hooks.json` instead.
- Copy the global file first, add a single extra top-level key, run the probe, then copy the original back and confirm it with `cmp`. Never judge the restore with `jq` output. When `jq` was missing from `PATH`, a `jq`-based diff compared two empty outputs and reported "identical".
- `agy -p --dangerously-skip-permissions "..."` takes the flag as the prompt and exits. Put `-p "<prompt>"` last.

For Claude Code, the matching facts were checked with `claude -p --plugin-dir <built plugin tree>`. That loads a plugin for one session without installing it. A PreToolUse `permissionDecision: "deny"` is honored even under `--dangerously-skip-permissions`, and the reason reaches the model.

One Orca limit showed up during the same work. Orca 1.4.206's `orca terminal switch` does not put a worker terminal into `user_takeover`, and `worker-release` still closed it afterwards. The `retained` / `user_takeover` branch of the injected takeover note cannot be reproduced programmatically. It needs a person to interact with the worker's tab.

## When this applies

Use this before changing `scripts/orca-subagent-guard`, adding another Antigravity hook event, or probing any agent CLI whose hook contract is undocumented. Re-probe after an Antigravity upgrade before trusting the field names above. The plan is `.compound-engineering/artifacts/plans/2026-09-28-1704-feat-orca-harness-subagent-deny-plan.md`.
