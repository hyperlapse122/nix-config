---
title: OpenCode Compound Engineering Plugin and Working Review Peer - Plan
type: feat
date: 2026-10-18
topic: opencode-ce-plugin-and-peer
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# OpenCode Compound Engineering Plugin and Working Review Peer - Plan

## Goal Capsule

- **Objective:** OpenCode runs with the same Compound Engineering skills as Claude Code. Compound Engineering reviews in every repository pick OpenCode as their cross-model peer by default, and that peer returns findings within the default time limit.
- **Means:** register OpenCode as a third harness of the pinned plugin registry (KTD1, KTD2), move its default model to GLM-5.3-Flash (KTD4), and restore the peer rule in the shared instructions (KTD6).
- **Product authority:** this plan covers the Compound Engineering plugin in OpenCode and GitHub issues #239, #240, and #241. The three issues close together on one branch.
- **Stop conditions:** stop and report if OpenCode does not load the plugin from the pinned path, or installs or fetches anything for it (U6 probe). A Flash-model miss of R10 does not stop the run; it follows KTD5.
- **Execution profile:** autonomous `lfg` run; implementation, checks, a live Synthetic measurement, and a pull request. Deploying the generation (`nr switch`) stays with the user.
- **Open blockers:** none.

---

## Product Contract

Product Contract preservation: changed — Dependencies / Assumptions: the layer-merge assumption is now verified; Outstanding Questions: answered in place by KTD1–KTD5. Requirements, decisions, and scope unchanged.

### Summary

OpenCode's global configuration loads the Compound Engineering plugin from the same pinned source Claude Code uses. Terminal sessions, T3 Code threads, and review peer runs therefore all get its skills. OpenCode's default model moves to `synthetic/hf:zai-org/GLM-5.3-Flash`. Reasoning is bounded only if measurement shows the new model still runs past the review time limit. The shared agent instructions again name `opencode` as the cross-model peer.

### Problem Frame

This flake installs OpenCode and configures it for one main job: serving as the cross-model peer for `ce-code-review` and `ce-doc-review`. It currently fails at that job in three ways.

First, Claude Code receives the Compound Engineering plugin through `agent-plugin-sync`, but OpenCode does not. `docs/provisioning.md` says so: `agent-plugin-sync` drives each agent's marketplace CLI, and OpenCode has none. An OpenCode session therefore cannot run `/ce-plan`, `/ce-code-review`, or any other CE skill.

Second, #238 slimmed the shared instructions and dropped the peer rule (#239). Compound Engineering now uses its default order, `codex → claude → grok → antigravity`, which never reaches `opencode`. The only way to get the peer back is to set `cross_model_peer` in each repository.

Third, when a repository does name the peer, it times out (#240). During #238's review, `synthetic/syn:large:text` reasoned longer on every turn, each turn grew to 2–4 minutes, and the run reached the 1200 s cap without producing an answer. A pass that times out yields no findings, so the review spent 20 minutes and got nothing back.

### Key Decisions

- **The plugin is declared in OpenCode's global configuration, so terminal sessions, T3 Code threads, and review peer runs all get it.** (session-settled: user-directed — chosen over loading it only in standalone runs through the wrapper's store config: T3 Code's OpenCode threads should have CE too, and the wrapper cannot tell a T3 Code thread from a peer run.) Governs R1, R3.
- **"The same plugins as Claude Code" means Compound Engineering only.** Claude Code's other enabled plugin, `cc-plugin-you-should-know@builtin`, is a Claude Code built-in and has no OpenCode counterpart. Governs R1.
- **OpenCode's plugin follows Claude Code's pin.** One source registry entry and one tag feed every harness, so a bump moves all agents together. Governs R2.
- **Switch the model first, and bound reasoning only if measurement says it is needed.** #241's Flash model is the smallest change that could resolve #240. Reasoning limits go in only if the Flash model still misses the time limit. Governs R7, R10.
- **The peer rule applies unconditionally.** Compound Engineering classifies an OpenCode host's model family as `unknown` and skips the automatic cross-model pass under an unknown family, so an OpenCode session never picks itself as the peer. Governs R9.

### Requirements

**Plugin parity**

- R1. Every OpenCode session started through the `opencode` wrapper loads the Compound Engineering skills and their slash commands on every host kind (NixOS, non-NixOS Linux, macOS). That covers terminal runs, T3 Code threads, and review peer runs.
- R2. OpenCode loads the plugin from the same pinned Compound Engineering source that Claude Code and the Antigravity CLI use, and no network fetch happens at session start.
- R3. Activation leaves alone any other plugin the user added to OpenCode's configuration, for example with `opencode plugin add`.
- R4. Retiring the plugin removes it from OpenCode's configuration on hosts that ran an earlier generation, as the registry's existing retirement path does for the other harnesses.
- R5. A repository check fails when OpenCode's materialized configuration does not reference the pinned plugin source, or when activation drops a plugin the user added.

**Model and peer timeout (#240, #241)**

- R6. OpenCode's default model is `synthetic/hf:zai-org/GLM-5.3-Flash`, and `opencode debug config` reports it.
- R7. If R10 fails on the Flash model, reasoning for the peer model is bounded, and the bound is verified by a drop in reasoning tokens per turn.
- R8. Any reasoning bound added under R7 applies only to review peer runs, unless the user agrees to bound interactive sessions too.

**Peer rule (#239)**

- R9. The shared instructions name `opencode` as the preferred Compound Engineering cross-model peer in one or two sentences. When the peer fails, the pass is skipped with a one-line reason and is neither retried nor replaced by another peer.

### Success Criteria

- R10. On a diff about the size of #238's (around 2,300 lines), a `ce-code-review` cross-model pass with the `opencode` peer, run with the plugin loaded, returns schema-shaped findings within the default 1200 s. Per-turn reasoning tokens before and after the change come from `~/.local/share/opencode/opencode.db` and are recorded in the pull request.
- R11. In a Claude Code session with no `cross_model_peer` set, `ce-code-review` resolves the peer target `opencode`.
- R12. `nix flake check` passes, along with every build the repository guidelines require, including the `opencode-settings` and `agent-instructions` checks updated for the new model id, the plugin, and the peer sentence.
- R13. `docs/provisioning.md` describes the plugin in OpenCode, the new model, and the peer rule. It no longer says that Compound Engineering's plugins do not reach OpenCode or that the shared instructions name no peer.

### Acceptance Examples

- AE1. **Covers R3.** Given the user ran `opencode plugin add some-plugin` before a rebuild, when activation runs, then `some-plugin` and Compound Engineering are both in OpenCode's plugin list.
- AE2. **Covers R7, R10.** Given the Flash model returns findings within 1200 s on a #238-sized diff, then no reasoning bound is added and R7 is satisfied without a change.
- AE3. **Covers R9.** Given a standalone OpenCode session runs `ce-code-review`, when Compound Engineering resolves the peer, then the automatic cross-model pass is skipped because the host family is unknown, and OpenCode is not launched as its own peer.

### Scope Boundaries

- `cc-plugin-you-should-know@builtin` and any other Claude Code built-in plugin.
- Plugins that have no OpenCode packaging.
- Removing the stale `provider.synthetic.models."syn:large:text"` entry from deployed `opencode.json` files. It is harmless once `model` points elsewhere, and removing it needs a nested-key removal the merger does not support.
- Raising `CROSS_MODEL_HARD_SECS` as a fix. Every review would get slower.
- Changing which harnesses outside OpenCode receive the plugin.
- Considered and not built: a guard against the peer loading a CE skill mid-review. The peer launch already denies `task`, edits, and web access; a skill load costs tokens but cannot change the reviewed checkout. R10's measurement with the plugin loaded would show the cost. Evidence that the peer loads skills during reviews would change this call.

### Dependencies / Assumptions

- OpenCode 2.0.32 loads the global `opencode.json` under every caller: `OPENCODE_CONFIG` and `OPENCODE_CONFIG_CONTENT` add layers after it and do not replace it, and `plugins` arrays concatenate across layers. A plugin listed in two layers loads twice. Observed with read-only probes of the pinned binary.
- OpenCode loads a local plugin path only when the directory has a root `index.js`, and skips one without it silently. Compound Engineering v3.31.0 has a root `index.js` that re-exports `.opencode/plugins/compound-engineering.js`. `opencode plugin add` accepts only npm or Git specifiers, so a user-added entry never takes the form of a path under `~/.local/share/agent-plugins/`.
- `hf:zai-org/GLM-5.3-Flash` is in OpenCode's built-in Synthetic catalog, with reasoning-effort variants `low`, `high`, and `max` and no `none`. It most likely reasons by default; R10 measures how much.
- Live verification of R10 and R11 spends Synthetic credits from a plan with a weekly limit.

### Sources / Research

- `home/h82/agents/agent-plugins.nix`: source registry, harness membership, and retirement path.
- `home/h82/agents/opencode.nix`, `home/h82/agents/opencode-model.nix`, `scripts/opencode`: OpenCode settings merge, model id, and wrapper environment.
- `home/h82/agents/claude.nix`: `enabledPlugins."cc-plugin-you-should-know@builtin"`.
- `home/h82/agents/instructions/instructions.md`, `tests/agent-instructions.nix` (`removedTerms` bans `Flash`, `glm-`, `Codex`, and `"# Cross-model review"`), `tests/opencode.nix`.
- `docs/provisioning.md`, sections "Shared agent instructions" and "OpenCode".
- Compound Engineering v3.31.0 source: `.opencode/INSTALL.md`, root `index.js`; `skills/ce-code-review/scripts/cross-model-adversarial-review.sh` (peer launch with `OPENCODE_DISABLE_PROJECT_CONFIG=1` and a permissions-only `OPENCODE_CONFIG_CONTENT`); `skills/ce-code-review/references/cross-model-review.md` (OpenCode host family `unknown`; the default peer order).
- GitHub issues #239, #240 (per-turn reasoning token table), #241.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **OpenCode becomes a third harness of `agent-plugins.nix`, driven by a new `opencode` adapter in `scripts/agent-plugin-sync`.** The membership row keeps "which agents get CE" in one registry. The adapter reuses `link_version`, so OpenCode reads the same version-keyed link Claude Code records (R2). Like the Antigravity adapter it prunes nothing, and its membership row runs before the Claude row. A failed OpenCode merge then stops activation before Claude's readback-gated prune, so `opencode.json` never names a deleted link. OpenCode has no plugin CLI that accepts a path, so the adapter's "CLI" is the `agent-settings` merger and the agent's file is `~/.config/opencode/opencode.json`. Governs R1, R2, R4. Rejected: declaring the path in `opencode.nix`'s own merge, which splits membership across two modules and leaves retirement unwired.
- KTD2. **A new merger field replaces string entries by prefix inside a list.** `scripts/agent-settings` gains one field (working name `prefixEntries`): at a path, drop every string entry that starts with a declared prefix, then append the declared value once, or append nothing when retiring. The prefix is the plugin's base directory, so a version bump replaces the old link path, a rerun appends no duplicate (a plugin listed twice loads twice), and entries that are not strings or not under the prefix stay (R3). It refuses a non-list at the path and a declaration that collides with `set`, `remove`, `own`, `setPaths`, or `upsertPaths`, in the merger's existing fail-closed style. Governs R3, R4. Rejected: `own` (drops user plugins) and `upsertPaths` (object entries only).
- KTD3. **The key is `plugins`, and only the merger writes the CE entry.** OpenCode v2 reads `plugins` and still merges the 1.x `plugin` key into it, so the adapter never touches `plugin`. Nothing else in this repository lists the CE path in another layer, so the plugin loads once. Governs R1, R3.
- KTD4. **`opencode-model.nix` names `synthetic/hf:zai-org/GLM-5.3-Flash`, and the `syn:` alias declaration goes.** The id is in OpenCode's built-in catalog, so `opencode.nix` stops declaring `provider.synthetic.models.<alias>.name`. The comment says a future `syn:` id needs that leaf back. Governs R6.
- KTD5. **A reasoning bound is a conditional unit with a stop.** If R10 fails on the Flash model, the only bound OpenCode offers is a model setting (`reasoningEffort`) in the global config, and that would also cover interactive sessions and T3 Code threads, which R8 forbids without the user's agreement. The run then records the measurement and the proposed `reasoningEffort = "low"` as a residual in the pull request instead of applying it, and R7 and R10 stay open until the user makes the R8 decision. Governs R7, R8.
- KTD6. **The peer rule is two sentences under `# Review findings`.** Directional wording: "Compound Engineering skills use `opencode` as the cross-model peer." and "When the peer fails, skip the pass and say why in one line; do not retry it or run another peer in its place." Neither sentence uses a banned term, and no `# Cross-model review` heading returns, so `removedTerms` stays as it is. Governs R9.
- KTD7. **Live verification runs against an `OPENCODE_CONFIG` overlay, not a deployed generation.** The repository forbids `nr switch` as validation. OpenCode loads a caller's `OPENCODE_CONFIG` file after the global file, and the wrapper leaves it alone, so a scratch file holding the new model and the plugin path reproduces the new generation for one peer run. R11 depends on the deployed `~/.claude/CLAUDE.md`, so it is reported as post-deploy verification. Governs R10, R11.

### High-Level Technical Design

The activation entries and the files they write after this change:

```mermaid
flowchart TB
  REG[agent-plugins.nix registry and membership] --> SYNC[agentPlugins activation]
  SYNC -->|harness claude| CC[claude plugin CLI]
  SYNC -->|harness antigravity| AGY[agy plugin CLI]
  SYNC -->|harness opencode| MERGE[agent-settings prefixEntries]
  SYNC --> LINK[~/.local/share/agent-plugins/compound-engineering/v3.31.0]
  MERGE --> OCJ[~/.config/opencode/opencode.json plugins]
  OCN[opencode.nix opencodeSettings] -->|model, update, share| OCJ
  OCJ --> WRAP[opencode wrapper: terminal, T3 Code, CE peer]
  LINK -. root index.js .-> WRAP
```

The two activation entries write disjoint keys of one file. Each merge is a compare-and-swap, so their order does not matter for correctness.

### Assumptions

- The `lfg` run proceeds without a scoping confirmation; the bets below stand unless review overturns them.
- `prefixEntries` is a working name; the implementer may pick another that matches the merger's field naming.
- The wrapper comments and `docs/provisioning.md` stop saying a peer "runs on its brief alone"; the peer still gets no shared instructions, but it does get the CE skills.

---

## Implementation Units

### U1. Merger: prefix-replaced string entries in a list

**Goal:** `scripts/agent-settings` can add one string entry to a list it shares with another writer, replace that entry's older forms, and retire it.

**Requirements:** R3, R4; KTD2.

**Dependencies:** none.

**Files:** `scripts/agent-settings`, `tests/test_agent_settings.py`.

**Approach:**

1. Add the field to `FIELDS`, the docstring table, and `declaration()`, with the same collision checks `upsertPaths` has against `set`, `remove`, `own`, and other paths.
2. In `apply()`, create a missing list at the path, refuse a non-list, filter out string entries starting with the prefix, then append the value when it is not null.
3. Refuse a value that does not itself start with the prefix, so a declaration cannot leave its own entry behind on the next run.

**Patterns to follow:** `upsert_entries` and its use in `apply()`; the existing refusal messages.

**Test scenarios:**

- A file with `plugins: ["some-plugin@git+https://example/x.git", "<base>/v3.30.0"]` and value `<base>/v3.31.0` ends with `["some-plugin@git+https://example/x.git", "<base>/v3.31.0"]`, user entry first.
- Running the same declaration twice leaves one `<base>/v3.31.0` entry.
- A missing `plugins` key is created with only the value.
- A null value removes every entry under the prefix and keeps the rest.
- A non-string entry (an object) in the list stays untouched.
- `plugins` holding an object or a string is refused and the file is unchanged.
- A value outside the prefix is refused.
- A declaration whose path starts at a key `set` or `own` also declares is refused.

**Verification:** `tests/test_agent_settings.py` passes; the `agent-settings` check in `flake.nix` passes.

### U2. Sync helper: `opencode` adapter

**Goal:** `agent-plugin-sync --harness opencode` links the pinned version, writes it into OpenCode's `plugins` through the merger, and retires it.

**Requirements:** R1, R2, R4; KTD1, KTD3.

**Dependencies:** U1.

**Files:** `scripts/agent-plugin-sync`, `tests/test_agent_plugin_sync.py`, `flake.nix` (the `agent-plugin-sync` check also copies `scripts/agent-settings`, so the tests drive the real merger).

**Approach:**

1. Add an `OpenCode` adapter to `HARNESSES` that overrides `sync` and `retire`, as `Antigravity` does. `--cli` names the merger; the settings path comes from a new argument or from `$HOME`, whichever reads cleaner beside the existing arguments.
2. On sync: check that the source has a root `index.js` (OpenCode skips a directory without one silently), call `link_version`, invoke the merger with a declaration whose prefix is the base directory plus `/` and whose value is the linked path, and read the file back, failing when the entry is missing. It prunes nothing (KTD1).
3. On retire: invoke the merger with a null value, then delete the base directory.
4. Update the module docstring, which names only `claude` and `antigravity`.

**Patterns to follow:** the `Antigravity` adapter's sync and retire shape, and `prune` after observed registration.

**Test scenarios:**

- Sync into a home with no `opencode.json` creates it with `plugins: ["<base>/<segment>"]` and the link points at the source.
- Sync after an earlier segment replaces the old entry, keeps a user entry, and leaves the old link for the Claude row to prune.
- A source without root `index.js` fails before linking or writing.
- A merger failure (a `plugins` value that is an object) fails the sync and leaves the old entry and the old link in place.
- These scenarios run the real `scripts/agent-settings`, not a fake, so the declaration the adapter builds is the one the merger accepts.
- Retire removes the entry and the base directory and keeps the user entry.
- `--dry-run` writes nothing.

**Verification:** `tests/test_agent_plugin_sync.py` passes; the `agent-plugin-sync` check passes.

### U3. Registry: OpenCode membership row

**Goal:** every configuration's `agentPlugins` activation drives the `opencode` adapter for Compound Engineering.

**Requirements:** R1, R2, R5; KTD1.

**Dependencies:** U2.

**Files:** `home/h82/agents/agent-plugins.nix`, `tests/agent-plugins.nix`.

**Approach:**

1. Add `opencode` to `harnesses` with the merger as its `cli` and an empty `env`, and add `exclude.opencode = [ ]` to the source.
2. Add the membership row before the `claude` row (KTD1); keep the shared-link divergence check working with three harnesses.
3. Extend `tests/agent-plugins.nix` to assert, from the rendered activation script, that each configuration invokes the sync helper with `--harness opencode`, the pinned source, the merger, and the same base and segment as the Claude row, ahead of the Claude invocation.
4. In the same check, run that rendered OpenCode invocation with `HOME` pointed at a scratch directory seeded with a user `plugins` entry, and assert the materialized `opencode.json` lists the pinned link path beside the user entry (R5). The OpenCode invocation needs no agent CLI, so it can run in the sandbox.

**Patterns to follow:** the existing `claude` and `antigravity` rows; the check's `or` fallbacks and collected failures.

**Test scenarios:**

- Every configuration's activation script carries an `opencode` invocation with the pinned source and the lock's segment.
- The materialized `opencode.json` holds the pinned link path and the seeded user entry.
- Mutation: dropping the membership row turns the check red on every configuration.
- Mutation: an adapter that writes nothing turns the materialized-file assertion red.
- Mutation: pointing the OpenCode row at a different base than the Claude row turns it red.

**Verification:** `nix build --no-link .#checks.x86_64-linux.agent-plugins` passes and each mutation above fails it.

### U4. OpenCode model and settings check

**Goal:** OpenCode defaults to GLM-5.3-Flash, and the settings check pins it and the plugin entry's survival beside a user plugin.

**Requirements:** R5, R6; KTD4.

**Dependencies:** U1.

**Files:** `home/h82/agents/opencode-model.nix`, `home/h82/agents/opencode.nix`, `tests/opencode.nix`.

**Approach:**

1. Change the model id and its comment; drop the `alias` binding and the `setPaths` leaf in `opencode.nix`, noting when a `syn:` id would need it again.
2. Update `declaredExpected`, `mergedExpected`, and `createdExpected` to the new id and the removed leaf.
3. Seed the divergent fixture with a user `plugins` entry and the stale `syn:large:text` model entry, and assert both survive the merge.

**Patterns to follow:** the check's JSON-literal expectations and its real-merger run against a seeded file.

**Test scenarios:**

- The declared document equals the literal with `synthetic/hf:zai-org/GLM-5.3-Flash` and no `setPaths`.
- A seeded file keeps a user `plugins` entry, the 1.x `plugin` key, and the stale `syn:large:text` model entry after the merge.
- A missing file is created with only the declared keys.

**Verification:** `nix build --no-link .#checks.x86_64-linux.opencode-settings` passes.

### U5. Peer rule in the shared instructions

**Goal:** the shared instructions name `opencode` as the cross-model peer.

**Requirements:** R9; KTD6.

**Dependencies:** none.

**Files:** `home/h82/agents/instructions/instructions.md`, `tests/agent-instructions.nix`.

**Approach:** add the two sentences of KTD6 as one bullet or two short lines under `# Review findings`, and add both to `pinnedSentences`.

**Test scenarios:**

- The check passes with each sentence present once, where a sentence starts.
- Mutation: prefixing the first sentence with "Never " turns the check red.
- Mutation: deleting the second sentence turns it red.

**Verification:** `nix build --no-link .#checks.x86_64-linux.agent-instructions` passes, and each mutation fails it.

### U6. Docs, wrapper comments, and live verification

**Goal:** documentation matches the new behavior, and the peer is shown to finish within the limit.

**Requirements:** R1, R7, R8, R10, R11, R13; KTD5, KTD7.

**Dependencies:** U1–U5.

**Files:** `docs/provisioning.md`, `scripts/opencode`, `tests/opencode.sh` (only if it asserts comment text), `.compound-engineering/artifacts/solutions/` (only through the pre-push refresh rule).

**Approach:**

1. `docs/provisioning.md`: the Antigravity and OpenCode sections and the instructions table describe the plugin reaching every OpenCode session through `plugins`, the new model and its catalog listing, the removed alias leaf, and the restored peer rule. Drop "Compound Engineering's plugins do not reach OpenCode" and "the shared instructions name no peer". Say that a changed declaration lands on the next rebuild that produces a new generation on NixOS, and on every apply on non-NixOS Linux and macOS.
2. `scripts/opencode`: the comment that a peer "runs on its brief alone" now says it gets no instructions but does get the global plugins.
3. Probe the plugin load with the pinned binary and a scratch `OPENCODE_CONFIG` overlay (KTD7): `opencode debug config` lists the path in `plugins`, the debug log shows the plugin's `index.js` loading, and the log shows no dependency install or fetch for it. The plugin's `package.json` declares runtime dependencies, so an install attempt would break R2.
4. Run a `ce-code-review` cross-model pass with the `opencode` peer on a #238-sized diff under the overlay. Record per-turn reasoning tokens before (from #240's table) and after, from `opencode.db`, for the pull request.
5. If the pass misses 1200 s, follow KTD5: record the residual and the proposed bound, and apply nothing.

**Test expectation:** none for the docs. The live run is measurement, not a check.

**Verification:** the probe shows the plugin loading; the pass returns schema-shaped findings within 1200 s, or the residual is recorded per KTD5.

---

## Verification Contract

| Gate | Command or evidence | Covers |
| --- | --- | --- |
| Formatting | `nix fmt -- --ci` | all units |
| Merger and sync unit tests | the `agent-settings` and `agent-plugin-sync` checks | U1, U2 |
| Flake checks | `nix flake check` | R5, R12 |
| Host outputs | build every `nixosConfigurations`, `homeConfigurations`, `systemConfigs`, and `darwinConfigurations` output named in `AGENTS.md`; darwin and aarch64 outputs go to CI | R1, R12 |
| VM checks | `nix build --no-link .#vmChecks.all` where `/dev/kvm` exists, otherwise CI | R12 |
| Mutation rounds | the mutations listed in U3 and U5, each turning its check red | R5, R9 |
| Plugin load probe | `opencode debug config` and the debug log under the overlay | R1, R2 |
| Peer timing | `ce-code-review` cross-model pass under the overlay, reasoning tokens from `opencode.db` | R10 |
| Post-deploy | after the user applies the generation, `ce-code-review` in Claude Code with no `cross_model_peer` resolves `opencode` | R11 |

On macOS, Linux-only checks are verified through their derivation inputs per `.compound-engineering/artifacts/solutions/best-practices/verify-linux-only-nix-check-inputs-on-macos-through-derivation-show.md`, and CI builds them.

---

## Definition of Done

- U1–U5 are implemented, their tests pass, and each listed mutation fails its check.
- U6's docs and comments match the code, and the probe shows the plugin loading from the pinned path.
- The peer timing result, with before and after reasoning tokens, is in the pull request, or the KTD5 residual is.
- R11 is listed in the pull request as post-deploy verification.
- No experimental code or scratch overlay is left in the diff.
