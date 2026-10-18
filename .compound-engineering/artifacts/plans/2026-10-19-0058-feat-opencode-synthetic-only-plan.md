---
title: OpenCode Synthetic-Only Provider - Plan
type: feat
date: 2026-10-19
topic: opencode-synthetic-only
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# OpenCode Synthetic-Only Provider - Plan

## Goal Capsule

- **Objective:** On every host, OpenCode runs the synthetic provider and nothing else — no other provider loads even when its credentials are present, and no other provider's models appear in the model picker — and the deployed OpenCode config carries no model alias left over from the retired cross-reviewer setup.
- **Means:** Declare a synthetic-only provider allowlist in the repository's declared OpenCode settings, and have activation remove the stale `syn:large:text` alias from deployed state (KTD1, KTD2).
- **Product authority:** The user, in this conversation. Other OpenCode behaviors — model choice, plugin loading, service handling — are not active scope.
- **Stop conditions:** Stop and report if evidence shows a workflow must run OpenCode on a non-synthetic provider, or if the declared removal cannot be enforced without discarding settings the checks prove must survive.
- **Execution profile:** Repository checks and built outputs verify the work. Applying the rebuilt configuration to hosts (activation) is the user's explicit action, never a validation step.
- **Who ships:** `ce-work` implements and opens the PR; the user applies the new generation per host and confirms the live `opencode debug config` result.

## Product Contract

### Summary

OpenCode becomes a synthetic-only harness: the declared settings allowlist the `synthetic` provider, and the deployed `~/.config/opencode/opencode.json` loses the `syn:large:text` alias the 2026-10-18 cross-reviewer work left behind. The default model and plugin behavior are unchanged.

### Problem Frame

OpenCode loads every provider it knows from its model catalog. Any provider whose credentials are visible — environment variables or keys added through `/connect` — can be selected in the model picker, although this repository intends OpenCode to run on Synthetic.

The synthetic-cross-reviewer work (2026-10-18) declared `syn:large:text` as a custom model under the `synthetic` provider. The follow-up plan moved the default model to the built-in catalog id `synthetic/hf:zai-org/GLM-5.3-Flash` and dropped the alias from the declaration, but the activation merge only sets or removes top-level keys, so the alias entry survives in the deployed `~/.config/opencode/opencode.json` and still lists `syn:large:text` as a selectable model. Its removal was explicitly deferred there.

### Requirements

**Provider allowlist**

- R1. OpenCode enables only the `synthetic` provider: no other provider loads even when its credentials are present in the environment or configured through `/connect`, and no other provider's models appear in the model selection list.
- R2. The restriction lives in the repository's declared OpenCode settings (`home/h82/agents/opencode.nix`), so activation enforces it on every host kind.

**Stale alias removal**

- R3. After activation, the deployed `~/.config/opencode/opencode.json` on every host contains no `provider.synthetic.models."syn:large:text"` entry, and `opencode debug config` lists no `syn:large:text` model.
- R4. The removal is enforced declaratively — activation converges the deployed file, so a re-added alias does not survive the next rebuild — rather than by a one-time manual edit.

### Key Decisions

- **Allowlist, not denial-by-enumeration.** One `enabled_providers` key states the whole restriction; OpenCode ignores every provider not listed. Governs R1, R2.
- **Declarative removal enforced by activation.** (session-settled: user-approved — chosen over a one-time manual cleanup: the scoping synthesis showed enforcement-by-activation and the user proceeded with the full pipeline.) Governs R3, R4.

### Acceptance Examples

- AE1. **Covers R1.** Given a host where another provider's API key is visible to OpenCode through the environment or `/connect`, when OpenCode starts, `opencode debug config` resolves only the `synthetic` provider and the model picker lists no other provider's models.
- AE2. **Covers R3.** Given a deployed `~/.config/opencode/opencode.json` that still contains the `syn:large:text` alias, when the activation merge runs, the entry is gone from the file and `opencode debug config` lists no `syn:large:text` model.

### Scope Boundaries

- The default model does not change: `synthetic/hf:zai-org/GLM-5.3-Flash`, with `home/h82/agents/opencode-model.nix` as its single source.
- No new model aliases are declared; the built-in synthetic catalog is the model source.
- Other harnesses are out of scope — Claude Code, Antigravity, and T3 Code's own provider setup; the restriction is OpenCode-scoped.

### Dependencies / Assumptions

- OpenCode's `enabled_providers` is an allowlist: providers not listed do not load even with credentials or `/connect` keys, and their models do not appear in the model list (OpenCode config docs, read 2026-10-19).
- Assumption: no workflow needs OpenCode on a non-synthetic provider; blocking such calls is the intent of the restriction. CE peer runs and T3 Code's OpenCode integration use `synthetic/hf:zai-org/GLM-5.3-Flash`.
- The stale alias is present in the deployed `~/.config/opencode/opencode.json` on the macOS host (read directly); other hosts are assumed to carry the same entry, since activation wrote it there too.
- `agent-settings` supports `set`, `remove`, `setPaths`, `upsertPaths`, `prefixEntries`, `own`, and `migrateInstances`; it has no nested-key removal today (KTD1 adds it).
- The published config schema marks `enabled_providers` — like `provider` and other v1 keys — `deprecated: true` with no replacement key named, while the config docs still document the allowlist as active (schema and docs read 2026-10-19). A future pinned release dropping the key would stop enforcing R1, which the post-apply `opencode debug config` check would surface.

### Sources / Research

- `home/h82/agents/opencode.nix` — declared settings and the activation merge.
- `home/h82/agents/opencode-model.nix` — single source of the model string.
- `scripts/agent-settings` — the merge tool: field validation, disjointness rules, CAS write. `set` refuses non-scalar values; `own` replaces a whole top-level value nothing else writes.
- `tests/test_agent_settings.py` — the merger's unit suite (`MergeTests`, `NestedPathTests`) that U1 extends.
- `tests/opencode.nix` — the `opencode-settings` check: compares the module's declared document to literals asserted here, and drives the exact merger and document through seeded and missing files.
- `flake.nix` — the `agent-settings` check runs the unit suite and integration merges; `opencode-settings` is registered beside it.
- `.compound-engineering/artifacts/plans/2026-10-18-1922-refactor-synthetic-cross-reviewer-plan.md` — origin of the alias and its declaration mechanism.
- `.compound-engineering/artifacts/plans/2026-10-18-2318-feat-opencode-ce-plugin-and-peer-plan.md` — dropped the alias from the declaration (KTD4) and deferred removing it from deployed files.
- <https://opencode.ai/docs/config/> — `enabled_providers` / `disabled_providers` semantics.
- Deployed state: `~/.config/opencode/opencode.json` on each host (outside the repository; the stale alias lives there).
- `README.md`, `docs/provisioning.md` — prose that still describes the alias as present.

Product Contract preservation: unchanged — R1–R4 and AE1–AE2 carried as written; the Deferred to Planning question resolved into KTD1.

## Planning Contract

### Key Technical Decisions

- KTD1. **Extend `agent-settings` with `removePaths`** — a list of `{path: [key, ...], key: name}` entries that remove one named key from the object at `path`, walking without creating parents and doing nothing when the path is absent, a segment is not an object, or the key is missing (the nested analogue of top-level `remove`'s no-op-when-absent). Validation mirrors `setPaths`: well-formed non-empty key paths, no path starting at a `set`/`remove`/`own` key, no ancestor-or-descendant overlap with other path declarations — with `upsertPaths`'s carve-out that two entries on the same path are fine when they name different keys. Chosen over owning `provider` whole, which would discard user data the checks prove must survive (`provider.*.options.timeout`, `models.hf:zai-org/GLM-4.7`), and over writing `null` through `setPaths`, which leaves the key present with a null value. Instantiates the Product Contract's declarative-removal decision for R3, R4. (session-settled: user-approved — chosen over a one-time manual cleanup: the scoping synthesis showed enforcement-by-activation and the user proceeded with the full pipeline.)
- KTD2. **Declare `enabled_providers` through `own`.** `set` refuses non-scalar values and `setPaths` leaves must be scalars, so the array reaches the file only as a wholly owned top-level key; nothing else writes `enabled_providers` into the global file, which is exactly what `own` is for. Governs R1, R2.

### Assumptions

- The packaged wrapper injects only an `instructions` config (`packages/opencode.nix`), so the global file's allowlist reaches every OpenCode invocation, T3 Code threads included.
- No workflow needs OpenCode on a non-synthetic provider; the restriction blocking one is the intent (Goal Capsule stop condition guards this).
- Hosts other than the macOS host carry the same stale alias entry, since the same activation wrote it.

### Compatibility and sequencing

- `removePaths` is additive: existing declared documents carry none and behave identically; the modules that share the merger (Claude Code, Gemini, Tokscale, OpenCode) are untouched.
- U1 lands before U2 — a declared document carrying `removePaths` fails the merger's unknown-field refusal until the tool supports it. U3 is independent and lands before merge.

## Implementation Units

### U1. `agent-settings` gains `removePaths`

- **Goal:** The merge tool can remove one named key at a nested path, declaratively and idempotently, with the same fail-closed validation discipline as its other fields.
- **Requirements:** R3, R4 (mechanism per KTD1).
- **Dependencies:** None.
- **Files:** `scripts/agent-settings`, `tests/test_agent_settings.py`
- **Approach:**
  - Add `removePaths` to `FIELDS` and to the module docstring's field list.
  - Parse and validate alongside the other path fields, reusing `check_path`, `check_top_level`, and `check_disjoint`, with the same-path-different-key carve-out.
  - Apply after the other operations: walk the path read-only (no parent creation), and when every segment exists and is an object, remove the named key.
  - Leave the merger's absent-file handling as it is: a `removePaths`-only declaration against a missing file contributes no keys, so no shared-codepath change is needed.
- **Patterns to follow:** the `remove` and `setPaths` implementations in the same script, and the `NestedPathTests` and validation-refusal tests they already have.
- **Test scenarios:**
  - A declared entry removes the named key from the object at its path; sibling keys and sibling objects survive.
  - An absent key, an absent path segment, or a non-object segment is a no-op and the run exits zero, mirroring top-level `remove`.
  - A missing settings file with a `removePaths`-only declaration creates no declared keys — the merger's pre-existing absent-file handling is unchanged and `removePaths` never materializes a key.
  - A second run on an already-merged file writes nothing.
  - Validation refuses a path starting at a `set`/`remove`/`own` key, a path that is an ancestor of another declared path, two entries on one path naming the same key, and a malformed entry — each without touching the file.
  - A dotted top-level key and a path segment containing a dot are each one key, as `NestedPathTests` already asserts for `setPaths`.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.agent-settings` green.

### U2. Declare synthetic-only OpenCode settings

- **Goal:** The declared settings allowlist `synthetic` and remove the retired alias leaf, so activation converges every host's deployed config to the synthetic-only posture.
- **Requirements:** R1, R2 (per KTD2), R3, R4 (per KTD1); AE1, AE2.
- **Dependencies:** U1.
- **Files:** `home/h82/agents/opencode.nix`, `tests/opencode.nix`
- **Approach:**
  - In `declared`, add `own.enabled_providers = [ "synthetic" ]` and one `removePaths` entry removing `syn:large:text` from `provider.synthetic.models`.
  - Update the module comment: the sentence about a `syn:` alias needing a `setPaths` entry stays, with the retired alias now removed by `removePaths`.
  - Update the check's literals: `declaredExpected` gains the `own` and `removePaths` fields; `mergedExpected` gains `enabled_providers`, keeps the seeded user data (`provider.*.options.timeout`, `models.hf:zai-org/GLM-4.7`), and drops `syn:large:text`; `createdExpected` gains `enabled_providers`.
  - Update the check's header comment, which currently says the stale alias survives the merge.
- **Patterns to follow:** the existing literal-expected documents in `tests/opencode.nix`, written as JSON text so the comparison shares no rendering path with the module.
- **Test scenarios:**
  - Covers AE2. The seeded file (alias, the user's other custom model, provider timeouts, user plugins, an MCP server) merges to the updated expected document: alias gone, everything else intact, `enabled_providers` present, mode 0600.
  - Covers AE2. A missing file is created holding exactly the declared keys, `enabled_providers` among them.
  - Covers AE1, R2. The module's rendered declared document equals the check's literal on every configuration, so the allowlist ships to all hosts.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.opencode-settings` green.

### U3. Align the documentation

- **Goal:** Repository prose describes the synthetic-only posture instead of the retired alias.
- **Requirements:** R3, R4 (the docs state the deployed state this change defines).
- **Dependencies:** None (lands before merge).
- **Files:** `README.md`, `docs/provisioning.md`
- **Approach:**
  - `README.md`: the Included-tools paragraph still says OpenCode runs `syn:large:text` — rewrite to the synthetic-only allowlist and the `synthetic/hf:zai-org/GLM-5.3-Flash` default.
  - `docs/provisioning.md`: the OpenCode section's "the entry stays in the file, unused" sentence becomes false — describe the `enabled_providers` allowlist and the `removePaths` removal instead, keeping the "a `syn:` alias would need `setPaths` again" note accurate.
- **Patterns to follow:** the surrounding English prose and exact-identifier conventions in both files.
- **Test expectation:** none — documentation-only; verified by the Definition of Done's reference scan.

## Verification Contract

- `nix flake check` — evaluates every declared check; CI's `flake-check` job runs the `--no-build` form.
- `nix build --no-link .#checks.x86_64-linux.agent-settings` — the merger's unit suite and integration merges (U1).
- `nix build --no-link .#checks.x86_64-linux.opencode-settings` — the declared-document and merge-behavior assertions (U2). Both checks are registered only under `checks.x86_64-linux` (CI's `check-shards` jobs); on the macOS host the changed module is evaluated by the `darwinConfigurations` builds below, not by these checks.
- `nix build --no-link .#darwinConfigurations.<host>.system` for each macOS host — proves the changed module evaluates and builds on the platform that runs it.
- Post-apply, per host (the user's explicit apply, then): `opencode debug config` resolves only the `synthetic` provider and lists no `syn:large:text` model — the live form of AE1 and AE2.

## Definition of Done

- Global:
  - `nix flake check` green, and the `agent-settings` and `opencode-settings` checks green on `x86_64-linux`.
  - Every macOS `darwinConfigurations` output builds on the macOS host.
  - `grep -rn "syn:large:text"` outside `.compound-engineering/` matches only the removal declaration in `home/h82/agents/opencode.nix` and the two sites in `tests/opencode.nix` that carry the name (the seeded fixture input and the `declaredExpected` literal); no README, docs, or other module text describes the alias as present or surviving.
  - No dead-end code from abandoned approaches remains in the diff.
- Per unit: each unit's Verification line holds; U2's check literals and U3's prose agree with the shipped declared document.
