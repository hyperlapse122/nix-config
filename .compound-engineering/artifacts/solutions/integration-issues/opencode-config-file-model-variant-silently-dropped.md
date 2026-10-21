---
title: OpenCode silently drops a model variant written in its config file
date: "2026-10-19"
category: integration-issues
module: OpenCode default model and effort (home/h82/agents/opencode.nix, home/h82/agents/synthetic-models.nix)
problem_type: integration_issue
component: tooling
severity: medium
symptoms:
  - "The config sets \"model\": \"synthetic/hf:zai-org/GLM-5.3#max\", OpenCode runs GLM 5.3, and the request carries no reasoning effort"
  - "A bogus variant in the config file, such as #bogus, raises no error, while the same value on --model is rejected"
  - "The session database records variant: max for a --model run and nothing for a config-file run"
root_cause: wrong_api
resolution_type: config_change
tags: ["opencode", "opencode-v2", "variant", "reasoning-effort", "reasoningEffort", "model", "synthetic", "glm-5.3", "provider-options", "opencode-config"]
retire_when: "OpenCode applies a config-file model variant to requests (check: with \"model\": \"<id>#high\" in a scratch config, a capture listener sees reasoning_effort high from opencode run --standalone), or rejects an unknown config-file variant"
---

# OpenCode silently drops a model variant written in its config file

## Problem

Issue #247 asked to pin OpenCode's default to GLM 5.3 at its `max` reasoning effort by writing `synthetic/hf:zai-org/GLM-5.3#max` as the config `model`. OpenCode 2.0.32 accepts that string, runs GLM 5.3, and sends no reasoning effort at all. Nothing reports that the variant was ignored.

## Symptoms

- The config sets `"model": "synthetic/hf:zai-org/GLM-5.3#max"`. OpenCode runs GLM 5.3, and the request body has no `reasoning_effort`.
- `#bogus` in the config is accepted without an error. On the command line, `--model 'synthetic/hf:zai-org/GLM-5.3#bogus'` fails with `Variant unavailable for synthetic/hf:zai-org/GLM-5.3: bogus`.
- In `~/.local/share/opencode/opencode.db`, a `--model …#max` run records `variant: "max"`; a run that takes the model from the config records no variant.

## What Didn't Work

All four config forms below were tried on 2026-10-19 with OpenCode 2.0.32, each through an `OPENCODE_CONFIG` overlay on `opencode run --standalone`. The config schema (`https://opencode.ai/config.json`) accepts the string `#variant` form and a model object with a `variant` field, so a schema check passes on every one of them.

| Config form | Variant reaches the run | Bogus value rejected |
| --- | --- | --- |
| `"model": "<id>#max"` | no | no |
| `"model": {"providerID": …, "model": …, "variant": "max"}` | no | no |
| `agent.build.variant: "max"` | no | no |
| `agent.build.model: "<id>#max"` | no | not tried |

The default model resolved correctly in every case; only the variant was lost.

Injecting `--model <id>#max` from the `opencode` wrapper was rejected rather than tried. Compound Engineering 3.31.0 starts OpenCode as `opencode acp` (its `cross-model-adversarial-review.sh` passes `--agent "$(command -v opencode) acp"`), and a forced `--model` would also override a model the user passes explicitly.

## Solution

Pin the effort on the model, not on the session. `home/h82/agents/opencode.nix` declares a `setPaths` leaf per model, such as `provider.synthetic.models."hf:zai-org/GLM-5.3".options.reasoningEffort = "max"`, merged into `~/.config/opencode/opencode.json`, and sets `model` to the plain id, `synthetic/hf:zai-org/GLM-5.3`. Both come from `home/h82/agents/synthetic-models.nix`, the one source of every Synthetic model id and its `opencodeEffort`. The merged result for the default model as the check asserts it:

```json
{
  "model": "synthetic/hf:zai-org/GLM-5.3",
  "provider": {
    "synthetic": {
      "models": {
        "hf:zai-org/GLM-5.3": { "options": { "reasoningEffort": "max" } }
      }
    }
  }
}
```

The option reached the HTTP request body as `reasoning_effort` on every path checked against a local capture listener with a fake key: `opencode run --standalone`, `opencode acp` driven by a JSON-RPC client, `opencode serve` with a prompt posted to `/api/session/<id>/prompt` (the path T3 Code uses), and the real merged file through the wrapper with `OPENCODE_CONFIG_CONTENT='{}'` (how a Compound Engineering peer starts). Removing the leaf removed the field. The same leaf on a different model (Flash) sent nothing, so the pin is per model. A `--model <id>#low` or `#high` still wins over the pin.

`tests/opencode.nix` asserts the declared, merged, and created settings with the efforts written as literals and the model ids read from `synthetic-models.nix`, and turns red when the default model changes away from the source's, when a leaf is removed, or when an effort changes.

The `@<effort>` alias entry that carries the text-generation effort would list its model twice in T3 Code's picker, so `home/h82/t3code.nix` hides it in `~/.t3/userdata/settings.json` through a `prefixEntries` entry for `providerModelPreferences.opencode.hiddenModels`, and `tests/t3code-traits.nix` pins that entry.

## Why This Works

A model variant in OpenCode 2.0.32 is a session-level choice that the CLI and a client's picker set; the config-file default path resolves the model and does not carry the variant into the session (per this session's probes, not a read of OpenCode's source). Provider model options are part of the model's own definition, so OpenCode includes them in every request for that model whichever entry point opened the session.

## Prevention

- Do not rely on a config-file `#variant`, a model object's `variant`, or `agent.*.variant` to set reasoning effort on OpenCode 2.0.32. Use `provider.<provider>.models."<model-id>".options`.
- OpenCode passes the option through without checking it, so a misspelled effort reaches the provider as written. Keep the value pinned by `tests/opencode.nix`, and check that a new model offers the level before moving the pin (GLM 5.3 lists `low`, `high`, and `max` in the models.dev catalog).
- The leaf is keyed by the model id. When an id in `synthetic-models.nix` changes, the effort pin follows the new id, so verify that model accepts the value, and add the previous key to `retiredModels` in `opencode.nix` so its stale entry is removed.
- A check cannot prove the request body; confirm a change with a live capture as `docs/verification.md` lists, and see [OpenCode plugin loading is verifiable only by a live run](opencode-plugin-loading-verifiable-only-by-a-live-run.md) for the overlay recipe, which carries this pin.
- Related: [OpenCode v2's shared background server keeps the first client's key and switches](opencode-v2-shared-background-server-keeps-first-client-env.md). The per-model option is read from config at each run only because that server is disabled.
