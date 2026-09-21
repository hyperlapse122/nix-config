---
title: Claude Code Managed Defaults - Plan
type: feat
date: 2026-09-21
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
topic: claude-managed-defaults
origin: https://github.com/hyperlapse122/nix-config/issues/19
---

# Claude Code Managed Defaults - Plan

## Goal Capsule

- **Objective:** When h82 starts `claude` on a reinstalled machine or a new generation, the session already runs with the intended model and effort level, with no manual setup.
- **Means:** Declare the Claude Code settings in the managed settings tier and consolidate them into a module named `claude` (KTD1, KTD2).
- **Authority:** This plan outranks the body of issue #19. KTD1 replaces the `~/.claude/settings.json` path the issue proposed.
- **Execution profile:** Standard implementation. Verify with `nix flake check` and both host builds. Do not activate the host (`nixos-rebuild switch`).
- **Stop conditions:** Stop and report if evidence shows the managed settings tier ignores the `model` or `effortLevel` key. Stop if hardware installation or partitioning becomes necessary.
- **Finishes and ships:** `ce-work` implements it; the calling pipeline ships it as a pull request.

---

## Product Contract

### Summary

Declare Claude Code's default model and effort level through NixOS managed settings. The existing `agent-memory` module now carries Claude Code settings in general, so rename it to `claude` and move the Gemini and Antigravity settings it also held into their own module. Update the regression checks and the documentation to match the new names and settings.

### Problem Frame

`claude-code` is installed as a package only, and the model and effort level are set by hand in every fresh environment. Reinstalling the machine or losing the home directory loses those settings. This repository exists to reproduce the environment declaratively, so both values belong in the declaration. Separately, the name `agent-memory` dates from when the module held only the memory switch; once model defaults move in, the name no longer describes the module.

### Requirements

**Claude Code defaults**

- R1. `/etc/claude-code/managed-settings.json` declares `model` as `opus[1m]`.
- R2. The same file declares the top-level `effortLevel` as `medium`.
- R3. The same file keeps the existing `autoMemoryEnabled = false`.

**Module structure**

- R4. The NixOS module lives at `modules/nixos/claude.nix`, and the host configuration imports that path.
- R5. The Claude Code Home Manager setting (`CLAUDE_CODE_DISABLE_AUTO_MEMORY`) lives in `home/h82/claude.nix`.
- R6. The Gemini and Antigravity settings live in `home/h82/gemini.nix`, and `home/h82/default.nix` imports both modules.
- R7. No module, test, or check named `agent-memory` remains in the repository.

**Checks and documentation**

- R8. `flake.nix` registers a `claude` check and a `gemini` check, each inspecting the generated configuration of its own module.
- R9. The `claude` check asserts R1, R2 (as the top-level `effortLevel`), R3, and R5 individually, asserts that the managed settings entry is enabled so activation writes it, and keeps asserting that no Home Manager file targets `~/.claude/settings.json`. Both checks cover the production and the bootstrap host configuration.
- R10. The `README.md` sentence "Coding-agent logins, settings, and plugins are not migrated" narrows to reflect the managed defaults.
- R11. `docs/provisioning.md` and `docs/verification.md` reflect the new module names, check names, and settings.

### Key Decisions

- Declare the settings in the managed settings tier (session-settled: user-directed — chosen over having Home Manager write `~/.claude/settings.json`: Claude Code rewrites that file at runtime, so a read-only store symlink cannot live there). Governs R1, R2, R3.
- Rename the module to `claude` (session-settled: user-directed — chosen over keeping the `agent-memory` name: the module now carries Claude Code settings beyond the memory switch). Governs R4, R5, R7.

### Scope Boundaries

**In scope**

- User `h82` and the `ThinkPad-X1-Carbon-Gen-11` host, in both its production and bootstrap configurations.

**Deferred to Follow-Up Work**

- Generalizing the module to other users or hosts. There is one user and one host today.
- Declarative management of Claude Code's other settings (hooks, status line, plugins).

**Outside this product's identity**

- Migrating coding-agent logins and authentication credentials.

### Success Criteria

- `nix flake check` and both host builds pass.
- Mutation testing kills every assertion in the new checks.

### Sources

- `modules/nixos/agent-memory.nix`: the current managed settings declaration.
- `home/h82/agent-memory.nix`: the current state, where the Claude environment variable and the Gemini settings share one module.
- `tests/agent-memory.nix`: the mutation-safe assertion pattern (null guard, explicit `if ... exit 1`).
- `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`
- `.compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md`
- Settings schema strings in the installed claude-code 2.1.278 binary: the top-level `effortLevel` is described as "Persisted effort level for supported models." and the per-model `modelSettings.<model>.effortLevel` as "Persisted effort level for this model." The top-level key is not bound to a model generation.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Add `model` and `effortLevel` to the managed settings**: extend the attribute set of `environment.etc."claude-code/managed-settings.json"` with both keys (session-settled: user-directed — chosen over having Home Manager write `~/.claude/settings.json`: Claude Code owns and rewrites that file). Governs R1, R2, R3.
- KTD2. **Split the modules into `claude` and `gemini`**: move `modules/nixos/agent-memory.nix` to `modules/nixos/claude.nix`, and split `home/h82/agent-memory.nix` into `home/h82/claude.nix` (Claude Code only) and `home/h82/gemini.nix` (the Gemini and Antigravity files) (session-settled: user-directed — chosen over keeping both agents in one module: the new name conflicts with the one-concern-per-module rule in AGENTS.md). Governs R4, R5, R6, R7.
- KTD3. **Declare effort through the top-level `effortLevel`**: claude-code 2.1.278 carries both a top-level `effortLevel` ("Persisted effort level for supported models.") and a per-model `modelSettings.<canonical>.effortLevel` ("Persisted effort level for this model."). The top-level key keeps the declaration valid even when the `opus` alias moves to a later generation. The per-model key silently stops applying the moment the alias and the canonical name diverge, and the check cannot see that divergence. `model` keeps the `opus[1m]` alias. Governs R1, R2.
- KTD4. **Split the checks along with the modules**: add `tests/claude.nix` and `tests/gemini.nix`, and register them in `flake.nix` as `claude` and `gemini`. Keep the established mutation-safe pattern that routes a missing value into a shell branch through `lib.optionalString`. Governs R8, R9.
- KTD5. **Rename with `git mv`**: record the renames as moves rather than as a new file plus a deletion, so review shows the actual change. Governs R4, R7.

### Assumptions

- Managed settings outrank user settings, so declaring `model` here means a model picked at runtime through `/model` does not persist. That is the accepted cost of the issue's "no manual setup" requirement; removing the key from the module hands the choice back. Record this behavior in `docs/provisioning.md`.
- `/etc/claude-code/managed-settings.json` does not exist on the host yet, because the previous commit's move to managed settings has not been activated. This plan performs no activation.

### Sequencing

U1 -> U2 -> U3 -> U4. U3 comes after U1 and U2 because its checks read the structure they create.

---

## Implementation Units

### U1. Rename the NixOS module and extend the managed settings

- **Goal:** `modules/nixos/claude.nix` declares the model, the effort level, and the memory switch through managed settings.
- **Requirements:** R1, R2, R3, R4, R7 (KTD1, KTD3, KTD5)
- **Files:** `modules/nixos/agent-memory.nix` -> `modules/nixos/claude.nix` (move), `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix` (import path)
- **Approach:** Move the file with `git mv`, then add `model = "opus[1m]"` and `effortLevel = "medium"` to the attribute set. Keep the existing comment explaining why the managed settings tier was chosen, and add one line for the non-obvious constraint that these values outrank the user's own.
- **Test Scenarios:** covered by the `claude` check in U3.
- **Verification:** `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel`

### U2. Split the Home Manager modules

- **Goal:** The Claude Code settings and the Gemini settings live in separate modules.
- **Requirements:** R5, R6, R7 (KTD2, KTD5)
- **Files:** `home/h82/agent-memory.nix` -> `home/h82/claude.nix` (move, then reduce), `home/h82/gemini.nix` (new), `home/h82/default.nix` (imports)
- **Approach:** Keep only `CLAUDE_CODE_DISABLE_AUTO_MEMORY` in the moved `claude.nix`, and move the `.gemini/*` file declarations into `gemini.nix`. Keep the `default.nix` import list in alphabetical order. Update each module's comment where it points at the other module by its old file name.
- **Test Scenarios:** covered by the `claude` and `gemini` checks in U3.
- **Verification:** both host builds succeed.

### U3. Split the checks and add the new assertions

- **Goal:** The `claude` check protects the new defaults and the `gemini` check protects the Gemini settings.
- **Requirements:** R7, R8, R9 (KTD4, KTD5)
- **Files:** `tests/agent-memory.nix` -> `tests/claude.nix` (move, then reduce and extend), `tests/gemini.nix` (new), `flake.nix`
- **Approach:** Add `model` and top-level `effortLevel` assertions to the existing managed settings assertions in the `claude` check, and move the Gemini assertions into the new `gemini` check. In both checks, read every value with an `or` fallback and wrap it in the `pkgs.lib.optionalString` absent/present branches, so a removed declaration fails in the builder rather than during evaluation. That extends the `managedAbsent`/`managedPresent` pattern, previously used only for the managed settings, to `.gemini/settings.json` and `.gemini/antigravity-cli/settings.json`. Replace the `agent-memory` registration in `flake.nix` with `claude` and `gemini`.
- **Test Scenarios:**
  - The check passes when `model` is `opus[1m]`.
  - Changing `model` to `sonnet` fails the check.
  - Removing the `model` key fails the check.
  - Changing `effortLevel` to `high` fails the check.
  - Removing the `effortLevel` key fails the check.
  - Changing `autoMemoryEnabled` to `true` fails the check.
  - Removing the `autoMemoryEnabled` key fails the check.
  - Removing the managed settings entry itself fails the check with an explicit message rather than an evaluation error.
  - Removing `CLAUDE_CODE_DISABLE_AUTO_MEMORY` fails the `claude` check.
  - Letting Home Manager manage `~/.claude/settings.json` fails the `claude` check.
  - Inverting each Gemini assertion fails the `gemini` check.
  - Removing either the `.gemini/settings.json` or the `.gemini/antigravity-cli/settings.json` declaration fails the `gemini` check with an explicit message rather than an evaluation error.
  - Setting `enable = false` on the managed settings entry fails the `claude` check, because a disabled entry keeps its `text` but is never written to `/etc`.
  - Declaring a Home Manager file whose `target` is `.claude/settings.json` under a different attribute name fails the `claude` check.
  - Both checks assert the production and the bootstrap host configuration, naming the host in every failure message.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.claude`, `nix build --no-link .#checks.x86_64-linux.gemini`, then apply each mutation above one at a time, confirm the failure, and revert it.

### U4. Update the documentation

- **Goal:** The documentation describes the new names, checks, and defaults.
- **Requirements:** R10, R11
- **Files:** `README.md`, `docs/provisioning.md`, `docs/verification.md`
- **Approach:** Narrow the migration-exclusion sentence in `README.md` so it says Claude Code's model and effort defaults are managed. In `docs/provisioning.md`, record (1) the new module paths, (2) a correction of the stale claim in the Claude Code entry — the memory switch lives in `/etc/claude-code/managed-settings.json`, not `~/.claude/settings.json`, and the `autoDreamEnabled` mention goes away, (3) that managed settings outrank user settings and how to hand the choice back, and (4) that an `opus[1m]` default starts every session on the 1M-context variant and falls back to the standard context where 1M is unavailable, with the `[1m]` suffix removed to default to the standard context. In `docs/verification.md`, split the `agent-memory` check description into `claude` and `gemini` entries; do not carry the unasserted `autoDreamEnabled` into the `claude` entry, and state the `model` and `effortLevel` assertions instead. Add a one-time manual check to the same document for after the user activates the configuration: start `claude` and confirm the reported model and effort match the declaration, reporting any mismatch under the Stop conditions.
- **Test expectation:** none — documentation-only unit.
- **Verification:** no `agent-memory` string remains outside the plan archive (`rg 'agent-memory' --glob '!.compound-engineering/**'`).

---

## Verification Contract

| Gate | Command | Units |
|---|---|---|
| Format | `nix fmt -- --ci` | U1-U3 |
| All checks | `nix flake check` | all |
| Production build | `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel` | U1, U2 |
| Bootstrap build | `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel` | U1, U2 |
| Mutation testing | Apply each U3 mutation, confirm the check fails, and revert it | U3 |
| Leftover name | `rg 'agent-memory'` matches only the plan archive | U4 |

These gates verify the declared values only. They cannot show that Claude Code applies those values from the managed settings tier; the one-time manual check U4 adds to `docs/verification.md` covers runtime behavior after activation.

`nixos-rebuild switch` is not a verification step. Apply the configuration to hardware only on the user's explicit instruction.

---

## Definition of Done

- R1 through R11 are satisfied.
- `nix flake check` and both host builds pass.
- Mutation testing kills every assertion in the `claude` and `gemini` checks.
- No module, test, or check named `agent-memory` remains in the repository.
- No abandoned code or commentary from discarded attempts remains in the diff.
