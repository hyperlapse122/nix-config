---
title: Claude Code ignores global-config keys declared in settings.json
date: "2026-09-30"
category: integration-issues
module: Claude Code settings (Home Manager activation)
problem_type: integration_issue
component: activation
severity: medium
symptoms:
  - "A `/config` toggle declared in `settingsTier` of `home/h82/agents/claude.nix` has no effect in Claude Code"
  - "The `claude` check passes, because it compares the rendered declared JSON with its own mirror, not what Claude Code reads"
root_cause: wrong_api
resolution_type: code_fix
tags: ["claude-code", "settings-json", "claude-json", "global-config", "home-manager", "activation", "agent-settings"]
retire_when: "Claude Code reads the key from settings.json; check a newer binary's strings for the key in the settings schema (`<key>:()=>`) or in the list that starts `var iCe=[`"
---

# Claude Code ignores global-config keys declared in settings.json

## Problem

Claude Code keeps its settings in two files. `~/.claude/settings.json` holds settings. `~/.claude.json` holds global config, which is also the tool's runtime state. Some `/config` toggles persist only to the global config file. This repository declares Claude Code settings by merging keys into `settings.json` at activation. A global-config key declared there is written and then never read.

## Symptoms

- The first plan for turning off "← opens agents" put `leftArrowOpensAgents = false` in `settingsTier`. That would have written the key into `settings.json`, and the left arrow would still have opened the agents view.
- Nothing fails. The `claude` check diffs the declared file the module renders against the values the check expects. Both sides hold the key, so the check passes whether or not Claude Code reads it.

## What Didn't Work

- **Inferring the file from a key list.** In the 2.1.285 binary, the key appears in a list (`var a6n=[...]`) next to `preferredNotifChannel`, `inputNeededNotifEnabled`, and `agentPushNotifEnabled`. This repository already declares those three in `settings.json`, and they work. That list is the full set of global-config keys, though, and it does not say which file each key is read from. The plan used it as evidence and was wrong. Doc review of the plan (the feasibility and adversarial reviewers) caught it before implementation.

## Solution

Find the code that reads the key. Do not rely on where the key is listed. In Claude Code 2.1.285:

- The gesture, the footer hint, and the tip all read `ce().leftArrowOpensAgents !== false`. `ce()` is the global-config reader, which reads `~/.claude.json`.
- The `/config` toggle writes the key through the global-config setter.
- The settings schema has no `leftArrowOpensAgents` entry.
- A second list, `var iCe=[...]`, names the global-config keys that are read from the user settings file first and fall back to global config. The three notification keys above are in it, which is why they work from `settings.json`. `leftArrowOpensAgents` is not in it.

The fix declares such keys in their own tier. A second activation entry runs the same `agent-settings` merger against `~/.claude.json`. See `globalConfigTier` and `home.activation.claudeGlobalConfig` in `home/h82/agents/claude.nix`. `tests/claude.nix` runs the same assertions (activation present, target file, declared JSON) for both merges.

`advisorModel`, declared in the same change, works from `settings.json`. The settings schema has an entry for it: `advisorModel:()=>...describe("Advisor model for the server-side advisor tool.")`.

To check a key, extract strings from the unwrapped binary (`bin/.claude-wrapped` in the `claude-code` store path) and search them with Python `re`. In this environment `grep` is `ugrep`, which rejects the long-line patterns this needs.

```sh
strings -n 6 "$(dirname "$(readlink -f "$(command -v claude)")")/.claude-wrapped" > strings.txt
python3 - <<'EOF'
import re
s = open('strings.txt', encoding='latin1').read()
key = 'leftArrowOpensAgents'
for pat in [rf'ce\(\)\.{key}', rf'{key}:\(\)=>', r'var iCe=\[[^\]]*\]']:
    for m in list(re.finditer(pat, s))[:2]:
        print(pat, '->', s[max(0, m.start()-80):m.end()+120].replace('\n', ' '))
EOF
```

If a key has a `ce().<key>` reader and is in neither the settings schema nor `iCe`, it belongs in `~/.claude.json`.

## Why This Works

Each file has its own reader, and a key takes effect only where its reader looks. For the keys listed in `iCe`, the reader checks settings first and then falls back to global config. That is how older global-config keys became settable from `settings.json`. Keys added outside that list, such as the agent-view toggles, have only the global-config reader.

## Prevention

- Before adding a key to `settingsTier`, confirm the binary reads it from settings: it is in the settings schema, or it is in `iCe`. Otherwise add it to `globalConfigTier`.
- Treat a passing `claude` check as proof of what activation writes, not of what Claude Code reads. [Checks that read an option value instead of the materialized output](../best-practices/nix-check-reads-option-value-not-materialized-output.md) covers the same kind of gap.
- Merging into `~/.claude.json` carries risks that the `settings.json` merge does not:
  - When the file is absent, the merger creates it holding only the declared keys. Claude Code then does not print its hint about restoring a backup of a missing global config.
  - The merger does not take Claude Code's config lock. A running session can write its cached copy over the merged key, and the key stays missing until the next rebuild that produces a new generation.
  - The merger sets the file's parent directory to `0700`. That parent is `$HOME`, which is already `0700` here.
