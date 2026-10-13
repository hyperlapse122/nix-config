---
title: The agy CLI ignores GEMINI_HOME, so it cannot verify what T3 Code's Antigravity homes load
date: "2026-10-14"
category: integration-issues
module: T3 Code Antigravity instance homes (scripts/t3code-antigravity-link)
problem_type: integration_issue
component: tooling
severity: medium
symptoms:
  - "GEMINI_HOME=<T3 instance home> agy plugin list prints \"No plugins installed.\" although config/plugins in that home links to an installed plugin"
  - "An agy -p session started with GEMINI_HOME set reads AGENTS.md and plugins from $HOME/.gemini, not from GEMINI_HOME"
  - "A headless ACP session/new against agy_acp_server.par with oauth-personal hangs instead of answering"
root_cause: wrong_api
resolution_type: tooling_addition
related_components:
  - testing_framework
tags: ["t3code", "antigravity", "agy", "gemini-home", "acp", "verification", "instance-home"]
retire_when: "agy honors GEMINI_HOME (check: GEMINI_HOME=<dir holding config/plugins/<name>> agy plugin list with an empty HOME lists the plugin), or T3 Code stops setting GEMINI_HOME per Antigravity instance"
---

# The agy CLI ignores GEMINI_HOME, so it cannot verify what T3 Code's Antigravity homes load

## Problem

T3 Code runs each Antigravity instance's ACP runtime (`agy_acp_server.par`) with `GEMINI_HOME` set to a private home. To give those instances the same plugins and global instructions as the `agy` CLI, `scripts/t3code-antigravity-link` links `config/plugins` and `config/AGENTS.md` in every instance home back to `~/.gemini/config`. The obvious way to check that delivery is to point the CLI at the instance home with `GEMINI_HOME`. That check is meaningless: the CLI ignores the variable.

## Symptoms

- `GEMINI_HOME=<instance home> agy plugin list` prints `No plugins installed.` both for a home that holds the two links and for a bare home, when `HOME` holds no plugins.
- An `agy -p` session given a marker in `<instance home>/config/AGENTS.md` does not see it. With the same marker in `$HOME/.gemini/config/AGENTS.md`, it does.
- Probing the ACP runtime directly fails differently: `session/new` with the `oauth-personal` auth method hangs, because the runtime needs the instance's `antigravity-acp/acp_token.json`, which the app's sign-in flow writes.

## What Didn't Work

- **Asserting the instance home through the CLI in a Nix check.** A code reviewer proposed extending `tests/antigravity-plugin-install.nix` with `GEMINI_HOME=$PWD/instance agy plugin list`. Probing showed the CLI's answer does not depend on `GEMINI_HOME`, so the assertion would only ever test `HOME`.
- **Finding a different variable in the binary.** `strings` on the pinned `agy` binary shows no `GEMINI_HOME` string. The only near match is `SMARTDISPLAY_GEMINIHOME`, which is unrelated.
- **Driving the ACP runtime headless.** The runtime does honor `GEMINI_HOME`, since T3 Code relies on that, but it refuses to start a session without OAuth. A fake token would not authenticate, and a real one may not be used in checks.

## Solution

Split verification by what each layer can observe:

1. **Layout, from the pinned T3 Code bundle.** The `t3code-antigravity-layout` check in `flake.nix` greps the pinned `t3` binary for the fragments that define the home: `crypto.digest("SHA-256", new TextEncoder().encode(instanceId))`, `profile: path.join(stateDir, "providers", "antigravity", key),` and `const geminiHome = path.resolve(input.profileDirectory);`. A T3 Code bump that moves the homes fails the check instead of leaving links where nothing reads them.
2. **Links, from the helper's own tests.** `tests/test_t3code_antigravity_link.py` drives the linker against fake T3 homes.
3. **The plugin payload, through the CLI's own home.** `tests/antigravity-plugin-install.nix` runs the real `agy` with `HOME` pointed at a throwaway directory. That is the one place where the CLI's view is the same as what the links expose.
4. **Loading, in the app.** Whether the ACP runtime loads `config/plugins` and `config/AGENTS.md` from a `GEMINI_HOME` that holds only links is checked by hand in T3 Code. The manual items are in `docs/verification.md` and the follow-up issue.

## Why This Works

The CLI and the ACP runtime are different programs that share a name. The CLI resolves its state from `$HOME/.gemini` only. The ACP runtime resolves it from `GEMINI_HOME`, which T3 Code sets (`resolveAntigravityInstanceDirectories` and `prepareAntigravityProfile` in the pinned bundle). A test that runs the CLI with `GEMINI_HOME` therefore tests `HOME`, whatever it appears to assert. Each check above runs against a layer that does read the path it asserts.

T3 Code also limits what can be delivered into a home. While preparing an instance's profile it links only `config/skills` and `antigravity-cli/skills` (`linkAntigravityUserSkills`), and on every prepare it rewrites `antigravity-acp/settings.json` with only the auth method, plus a `gcp` block when one is configured. Links in other paths survive. A setting written into that file, such as the CLI's `disableAutoGenerateMemories`, does not.

## Prevention

- Before you assert anything about a T3 Code Antigravity instance through `agy`, remember that the CLI reads `HOME`, not `GEMINI_HOME`. To use the CLI against a prepared tree, set `HOME` so that `$HOME/.gemini` is that tree.
- When a reviewer proposes an instance-home check through the CLI, probe it first with an empty `HOME` and a populated `GEMINI_HOME`. If the result does not change, the check is decorative.
- Keep `t3code-antigravity-layout` current when T3 Code renames the minified code around those fragments: update the fragments from the new bundle rather than deleting the check.
- Do not try to declare Antigravity settings for T3 instances through `antigravity-acp/settings.json`. T3 Code overwrites that file.

## Related

- [T3 Code accepts a preinstalled Antigravity runtime only in its managed layout](t3code-antigravity-runtime-preinstall-managed-layout.md)
- [T3 Code's Antigravity ACP server finds no CA bundle on NixOS](t3code-antigravity-acp-openssl-missing-ca-bundle-hangs-sessions.md)
- [A check that reads an option value instead of the materialized output](../best-practices/nix-check-reads-option-value-not-materialized-output.md)
