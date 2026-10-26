---
title: Integrate Antigravity Models into OMP and Retire Standalone Antigravity Assets
date: 2026-10-26
type: feat
execution: code
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
---

## Goal Capsule

- **Objective:** T3 Code and system-wide coding workflows call Google Gemini models through the unified OMP ACP instance, while all standalone Antigravity CLI and ACP runtime assets, packages, and tests are cleanly retired from the repository.
- **Means:** Add `google-antigravity/**` to the OMP `--models` argument in `home/h82/t3code.nix`, retire the native `providerInstances.antigravity` instance in T3 Code, and delete legacy Antigravity CLI packages, activation hooks, Compound Engineering harness references, maintenance workflows, and associated test suites.
- **Product authority:** Covers T3 Code provider configuration, Home Manager agent modules, and repository Nix packages; does not alter third-party upstream OMP behavior or affect other active harnesses (Codex, Claude Code).
- **Open blockers:** None.

---

## Product Contract

### Summary

Expose Google Gemini models in T3 Code by configuring the local OMP instance with the `google-antigravity/**` model selector pattern. Retire the standalone Antigravity provider in T3 Code and remove legacy Antigravity packages, activation scripts, CE harness links, and tests across the repository.

### Problem Frame

T3 Code currently supports Gemini models through a standalone, dedicated Antigravity ACP runtime (`agy_acp_server.par`) and companion CLI (`agy`). Maintaining this dedicated stack imposes substantial carrying cost: custom archive pinning, binary wrappers, instance home linking, token seeding, maintenance update workflows, and specialized test harnesses. Because OMP already embeds the `google-antigravity` provider natively, routing Gemini requests through OMP consolidates provider lifecycle management, simplifies T3 Code configuration, and eliminates redundant agent packaging.

### Key Decisions

- **Expose Antigravity models in T3 Code via OMP** (session-settled: user-directed — chosen over keeping standalone ACP provider: unifies model dispatch and session management under OMP). Governs R1, R2.
- **Retire T3 Code native Antigravity provider** (session-settled: user-directed — chosen over parallel dual providers: avoids duplicate UI entries and eliminates maintenance of custom ACP wrappers). Governs R3, R4.
- **Cleanly retire standalone Antigravity CLI assets and packages** (session-settled: user-directed — chosen over retaining CLI packages: removes unneeded binary distributions and activation logic since OMP is the sole Gemini interface). Governs R5, R6, R7, R8.
- **Retire Antigravity harness in Compound Engineering and shared instructions** (session-settled: user-directed — chosen over keeping dead plugin sync targets: aligns CE plugin distribution with active harnesses). Governs R9, R10.

### Requirements

#### T3 Code OMP Integration

- R1. The OMP instance in `home/h82/t3code.nix` includes `google-antigravity/**` in its `--models` command-line argument.
- R2. T3 Code UI displays available `google-antigravity` models when selecting models under the OMP provider instance.

#### T3 Code Provider Cleanup and Retirement

- R3. The `antigravity` entry under `settings.providerInstances` in `home/h82/t3code.nix` is marked retired or disabled via `agent-settings` migration to ensure existing host state removes or disables it cleanly.
- R4. T3 Code runtime installation and linking helpers (`t3codeAntigravityInstall`, `t3codeAntigravityLink`) are removed from activation flows and package manifests.

#### Repository Packaging and Activation Retirement

- R5. The standalone packages `antigravity-cli.nix`, `antigravity-acp.nix`, `antigravity-acp-path.nix`, and their release pin files (`antigravity-cli-release.json`, `antigravity-acp-release.json`) are removed from `packages/`.
- R6. Maintenance update scripts `scripts/antigravity-cli-release`, `scripts/antigravity-acp-release`, and their steps in `.github/workflows/update-dependencies.yml` are removed.
- R7. Home Manager activation `antigravitySettings` in `home/h82/agents/gemini.nix` is removed or migrated so settings are no longer enforced for the absent CLI.
- R8. Antigravity-specific skill links under `.gemini/antigravity-cli/skills` in `home/h82/agents/skills.nix` and `tests/korean-skills.nix` are removed.

#### Compound Engineering and Instruction Alignment

- R9. The `antigravity` entry in `home/h82/agents/agent-plugins.nix` is retired so plugin sync no longer attempts to target `agy`.
- R10. Shared instruction delivery to `.gemini/config/AGENTS.md` in `home/h82/agents/instructions/default.nix` is retired or kept strictly for general Gemini CLI if still applicable, removing Antigravity-specific references.

#### Test Suite and Verification Hygiene

- R11. Antigravity-specific tests (`tests/antigravity-acp-path.nix`, `tests/antigravity-acp-path-profiles.nix`, `tests/antigravity-plugin-install.nix`, `tests/test_antigravity_*.py`, `tests/test_t3code_antigravity_*.py`, `tests/t3code-antigravity-pin.py`) are removed from the test runner and flake checks.
- R12. Existing guards and checks in `tests/t3code-traits.nix`, `tests/agent-plugins.nix`, and `tests/darwin-outputs.nix` are updated to remove assertions on Antigravity paths while keeping OMP assertions passing.

### Scope Boundaries

- **Out of scope:** Modifying OMP upstream binary or packaging beyond declaring `--models` patterns in T3 Code.
- **Out of scope:** Altering OpenAI Codex or Claude Code configurations in T3 Code or Home Manager.
- **Out of scope:** Changing authentication mechanisms; OMP uses its own existing credential discovery or environment configuration for Google Antigravity.

### Acceptance Examples

- AE1. OMP ACP model list in T3 Code
  - **Given:** A running T3 Code session with the updated OMP configuration.
  - **When:** The user opens the model selector under OMP.
  - **Then:** Models matching `google-antigravity/**` (e.g., `gemini-3.8-flash`, `gemini-2.5-pro`) appear in the model list.
  - **Covers:** R1, R2

- AE2. Clean activation and absence of legacy Antigravity CLI
  - **Given:** A system rebuilt with the updated flake.
  - **When:** Home Manager activation runs.
  - **Then:** No error occurs, `agy` is no longer in user PATH, and `providerInstances.antigravity` is no longer active in T3 Code settings.
  - **Covers:** R3, R4, R5, R7

- AE3. Flake check verification
  - **Given:** The updated repository state.
  - **When:** `nix flake check --no-build` and relevant test shards are executed.
  - **Then:** All checks pass with no failures referencing retired Antigravity paths or scripts.
  - **Covers:** R11, R12

---

## Planning Contract

### Key Technical Decisions

- **KTD1: Expand OMP CLI model patterns in T3 Code.** In `home/h82/t3code.nix`, add `"google-antigravity/**"` to `ompPatterns`. This instructs the OMP ACP server wrapper to expose the 11 built-in Gemini/Antigravity models to T3 Code. (Governs R1, R2)
- **KTD2: Migrate T3 Code provider instances via agent-settings.** Instead of simply deleting the Nix definition (which would leave old JSON on disk), add `"antigravity"` to `retiredPaths` or set `enabled = false` under `settings.providerInstances.antigravity`, and remove `antigravity` from active `instanceMigration` / `providerInstances`. (Governs R3)
- **KTD3: Delete standalone package files and pins cleanly.** Remove `packages/antigravity-cli.nix`, `packages/antigravity-acp.nix`, `packages/antigravity-acp-path.nix`, `packages/antigravity-cli-release.json`, and `packages/antigravity-acp-release.json`. Clean up references in `packages/agent-tools.nix`, `flake.nix`, and `.github/workflows/update-dependencies.yml`. (Governs R4, R5, R6)
- **KTD4: Prune Home Manager agent declarations.** In `home/h82/agents/gemini.nix`, drop `antigravitySettings` activation and declared settings. In `home/h82/agents/skills.nix`, remove `.gemini/antigravity-cli/skills`. In `home/h82/agents/agent-plugins.nix`, remove the `antigravity` harness block. (Governs R7, R8, R9, R10)
- **KTD5: Prune test assertions and update flake check shards.** Remove obsolete Antigravity test files and flake check declarations. Update `tests/t3code-traits.nix`, `tests/darwin-outputs.nix`, `tests/agent-plugins.nix`, and `tests/korean-skills.nix` to ensure assertions only check surviving harnesses and providers. (Governs R11, R12)

---

## Implementation Units

### U1. Update T3 Code OMP Models and Provider Configuration

- **Goal:** Expose `google-antigravity/**` through OMP and retire `providerInstances.antigravity` in T3 Code.
- **Requirements:** R1, R2, R3, R4
- **Dependencies:** None
- **Files:** `home/h82/t3code.nix`
- **Approach:**
  1. Add `"google-antigravity/**"` to `ompPatterns` in `home/h82/t3code.nix`.
  2. Add `{ path = [ "providerInstances" ]; key = "antigravity"; }` to `retiredPaths`.
  3. Remove `providerInstances.antigravity` and remove `antigravityInstances = [ "antigravity" ];` and its installer/linker calls.
- **Test Scenarios:**
  - `home/h82/t3code.nix` evaluates without syntax or type errors.
  - The rendered OMP command args in `config.providerInstances.omp.config.commandArgs` contain `--models ... google-antigravity/**`.
- **Verification:** `nix eval .#homeConfigurations.ms-7d91-bootstrap.config.programs.t3code` evaluates successfully.

### U2. Clean Up Home Manager Agent Configuration

- **Goal:** Remove Antigravity CLI activation, skills links, and CE harness definitions from Home Manager.
- **Requirements:** R7, R8, R9, R10
- **Dependencies:** U1
- **Files:**
  - `home/h82/agents/gemini.nix`
  - `home/h82/agents/skills.nix`
  - `home/h82/agents/agent-plugins.nix`
  - `home/h82/agents/instructions/default.nix`
- **Approach:**
  1. In `gemini.nix`: Remove `antigravityTier`, `declared`, and `home.activation.antigravitySettings`. Keep `.gemini/settings.json` for base Gemini CLI.
  2. In `skills.nix`: Remove `".gemini/antigravity-cli/skills"` from the skill directories.
  3. In `agent-plugins.nix`: Remove `antigravity` harness entry from `harnesses` and `sources`.
  4. In `instructions/default.nix`: Remove `agent-instructions-antigravity` (`.gemini/config/AGENTS.md`) if obsolete or retain only if general gemini needs it.
- **Test Scenarios:**
  - Home activation evaluates without references to `antigravity-cli`.
  - Skill symlink definitions no longer create `.gemini/antigravity-cli/skills`.
- **Verification:** `nix eval .#homeConfigurations.ms-7d91-bootstrap.config.home.activation` evaluates cleanly.

### U3. Delete Legacy Packages, Update Scripts, and CI Workflow

- **Goal:** Remove standalone Antigravity package files, update scripts, and CI references.
- **Requirements:** R5, R6
- **Dependencies:** U2
- **Files:**
  - `packages/antigravity-cli.nix` (delete)
  - `packages/antigravity-acp.nix` (delete)
  - `packages/antigravity-acp-path.nix` (delete)
  - `packages/antigravity-cli-release.json` (delete)
  - `packages/antigravity-acp-release.json` (delete)
  - `packages/agent-tools.nix`
  - `scripts/antigravity-cli-release` (delete)
  - `scripts/antigravity-acp-release` (delete)
  - `scripts/t3code-antigravity-install` (delete)
  - `scripts/t3code-antigravity-link` (delete)
  - `scripts/t3code-release`
  - `.github/workflows/update-dependencies.yml`
- **Approach:**
  1. Remove the standalone package derivations, pins, and python update scripts.
  2. In `packages/agent-tools.nix`, remove `antigravityCliRelease`, `antigravityAcpRelease`, `t3codeAntigravityInstall`, and `t3codeAntigravityLink`.
  3. In `scripts/t3code-release`, remove the `antigravity` field preservation logic.
  4. In `.github/workflows/update-dependencies.yml`, remove steps that update `antigravity-cli-release` and `antigravity-acp-release`.
- **Test Scenarios:**
  - `nix build` of remaining `agentTools` succeeds.
  - `packages/t3code-release.json` no longer requires `antigravity` pins or can drop them cleanly.
- **Verification:** Package evaluation passes without missing attribute errors.

### U4. Update Tests and Flake Checks

- **Goal:** Remove obsolete Antigravity tests and update surviving tests to remove assertions on Antigravity.
- **Requirements:** R11, R12
- **Dependencies:** U1, U2, U3
- **Files:**
  - `flake.nix`
  - `tests/antigravity-acp-path.nix` (delete)
  - `tests/antigravity-acp-path-profiles.nix` (delete)
  - `tests/antigravity-plugin-install.nix` (delete)
  - `tests/test_antigravity_acp_probe.py` (delete)
  - `tests/test_antigravity_acp_release.py` (delete)
  - `tests/test_antigravity_cli_release.py` (delete)
  - `tests/test_t3code_antigravity_install.py` (delete)
  - `tests/test_t3code_antigravity_link.py` (delete)
  - `tests/t3code-antigravity-pin.py` (delete)
  - `tests/gemini.nix`
  - `tests/korean-skills.nix`
  - `tests/t3code-traits.nix`
  - `tests/darwin-outputs.nix`
  - `tests/agent-plugins.nix`
  - `tests/darwin-config.nix`
- **Approach:**
  1. Remove Antigravity check definitions from `flake.nix`.
  2. Delete dedicated Antigravity test files.
  3. In `tests/gemini.nix`, remove checks asserting `home.activation.antigravitySettings`.
  4. In `tests/korean-skills.nix` and `tests/darwin-config.nix`, remove `.gemini/antigravity-cli/skills` from expected paths.
  5. In `tests/t3code-traits.nix`, remove checks asserting `antigravity` providerInstance, runtime linking, and installer.
  6. In `tests/darwin-outputs.nix`, remove checks asserting `agy_acp_server.par`.
  7. In `tests/agent-plugins.nix`, remove `antigravity` case from harness test fixtures.
- **Test Scenarios:**
  - `nix flake check --no-build` succeeds.
  - `nix build .#checkShards.light-1` (and other shards) succeed.
- **Verification:** `nix flake check --no-build` exits 0.

---

## Verification Contract

- `nix flake check --no-build`: Proves flake evaluation, type invariants, and syntax across all configurations.
- `nix eval .#homeConfigurations.ms-7d91.config.programs.t3code`: Validates that T3 Code settings and OMP args render with `google-antigravity/**` and without legacy Antigravity instances.
- `nix build --no-link .#checkShards.hosts`: Validates host closure checks.

---

## Definition of Done

- OMP ACP instance in T3 Code is configured with `google-antigravity/**`.
- `providerInstances.antigravity` is retired in T3 Code settings.
- All standalone Antigravity packages, update scripts, and CI steps are deleted.
- All Antigravity-specific Home Manager activations, skill links, and CE plugin references are removed.
- All obsolete Antigravity tests are deleted, surviving tests updated, and `nix flake check --no-build` passes.
