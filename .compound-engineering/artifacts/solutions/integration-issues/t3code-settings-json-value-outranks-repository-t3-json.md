---
title: A T3 Code setting declared in settings.json outranks every repository's t3.json
date: "2026-10-16"
category: integration-issues
module: T3 Code settings (Home Manager activation)
problem_type: integration_issue
component: activation
severity: medium
symptoms:
  - "A repository's t3.json sets defaultThreadEnvMode (or worktreeSubmodules), but new threads in that project ignore it"
  - "Every project starts threads in a worktree although only some repositories ask for one"
  - "The t3code-traits check passes, because it compares the rendered declaration, not what T3 Code resolves per project"
root_cause: config_error
resolution_type: config_change
tags: ["t3code", "t3-json", "settings-json", "defaultThreadEnvMode", "worktreeSubmodules", "projectSettingsOverrides", "defaultProjectScripts", "agent-settings", "retired-keys", "home-manager", "activation"]
retire_when: "T3 Code changes its project-file-backed tier order so t3.json outranks the environment value in settings.json; check the pinned client bundle's t3ProjectFile-*.js for the function that returns source `environment` before `t3.json`"
---

# A T3 Code setting declared in settings.json outranks every repository's t3.json

## Problem

`home/h82/t3code.nix` declared `defaultThreadEnvMode = "worktree"` in the T3 Code settings it merges into `~/.t3/userdata/settings.json`. A value there is machine-wide, and T3 Code reads it before a repository's `t3.json`, so every project started its threads in a worktree whatever its `t3.json` said (issue #224).

## Symptoms

- A repository whose `t3.json` asks for local threads still starts each new thread in a worktree.
- The project-defaults settings page says a project's `t3.json` can override the value, which is false while `settings.json` holds one.
- `checks.x86_64-linux.t3code-traits` passes. It compares the rendered declaration byte-for-byte with its own expectation, which proves what activation writes, not which tier T3 Code picks.

## What Didn't Work

- **Reading `t3.json` as the authority because it lives in the repository.** The repository file sits below the machine-wide value, not above it.
- **Dropping the key from the declared `settings` alone.** `scripts/agent-settings` only assigns the keys a declaration lists and leaves every other key as the app wrote it, so the last written `"worktree"` would stay in `settings.json` on every machine.

## Solution

Stop declaring the key and retire the stored value through the agent-settings `remove` list, the same `retiredKeys` convention `home/h82/agents/{claude,codex,gemini}.nix` use:

```nix
# home/h82/t3code.nix
retiredKeys = [ "defaultThreadEnvMode" ];
# render passes it through as the declaration's remove field
declared = render "t3code-declared-settings.json" settings modelSelections retiredKeys;
```

`render` adds `inherit remove;` to the JSON, so activation deletes the key from `settings.json`. Removing a key that is already absent is a no-op. `tests/t3code-traits.nix` expects `remove = [ "defaultThreadEnvMode" ]` in the settings declaration and `remove = [ ]` in the client-settings one. Putting the key back in `settings`, emptying `retiredKeys`, or dropping `inherit remove` each fails the check (mutations run in this session).

The removal runs only when activation runs, which needs a new Home Manager generation; see [activation does not re-run when the generation is unchanged](../best-practices/home-manager-activation-does-not-run-on-every-rebuild.md).

## Why This Works

T3 Code `0.0.46-nightly.20261015.3158` resolves each project-file-backed setting (`defaultThreadEnvMode`, `worktreeSubmodules`) in four tiers, per its client bundle `t3ProjectFile-*.js`:

1. `projectSettingsOverrides[projectId]`, the per-project override T3 Code stores in its own state (plus, until `projectSettingsFolded` is true, the project record's own `defaultThreadEnvMode`).
2. The environment value in `settings.json`. When it is set, the resolver returns it with source `environment` and never looks further.
3. The repository's `t3.json`, returned with source `t3.json`.
4. The built-in default (`local` for `defaultThreadEnvMode`, `recursive` for `worktreeSubmodules`).

With no value at tier 2, a project without an override falls through to its own `t3.json`, which is what issue #224 asked for.

Scripts follow a different rule. Stored `projectSettingsOverrides[*].defaultProjectScripts` win over `t3.json` scripts: once `projectSettingsFolded` is true, T3 Code falls back from the per-project override to the environment's `defaultProjectScripts`, and `t3.json` scripts are only offered for import. On this machine two projects store their own scripts, one still carrying an old "Setup Worktree" command. The module deliberately does not manage these overrides, because they are app state the user edits in the UI.

## Prevention

- Before declaring a T3 Code key machine-wide, check whether it is project-file-backed. If a repository's `t3.json` can set it, a declared value overrides every repository; leave the key to `t3.json` unless every project should share it.
- To stop declaring any agent setting, move the key to `retiredKeys` instead of deleting the line, and drop the entry once every host has rebuilt past it.
- When a project ignores its `t3.json`, look at `settings.json` and that project's entry in `projectSettingsOverrides` before suspecting the repository file.
- A passing `t3code-traits` check says nothing about precedence. Confirm the effect with T3 Code running: open a thread in a project whose `t3.json` sets the mode.

## Related

- [Claude Code ignores global-config keys declared in settings.json](claude-code-global-config-keys-ignored-in-settings-json.md): the same agent-settings merger and `retiredKeys` pattern, for a key written to a file the app never reads.
- [Checks that read an option value instead of the materialized output](../best-practices/nix-check-reads-option-value-not-materialized-output.md): why a check on the rendered declaration cannot show what the app resolves.
- [T3 Code accepts a preinstalled Antigravity runtime only in its managed layout](t3code-antigravity-runtime-preinstall-managed-layout.md): other T3 Code state this flake manages under `~/.t3`.
