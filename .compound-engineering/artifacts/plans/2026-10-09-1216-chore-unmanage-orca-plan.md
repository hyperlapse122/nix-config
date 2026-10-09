---
title: Stop Managing Orca - Plan
type: chore
date: 2026-10-09
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Stop Managing Orca - Plan

## Goal Capsule

- **Objective:** No host this flake builds installs, configures, or mentions Orca, and the repository's checks and docs describe T3 Code as the only agent environment.
- **Means:** Delete the Orca package, its install points, its checks, the one-shot Orca retirement shims, and the Orca session paths in Tokscale, then reword every remaining comment, fixture, and doc that names Orca (KTD1-KTD5).
- **Authority:** This plan, then `AGENTS.md`. The user's directive (KD1) outranks both.
- **Stop conditions:** Stop if removing a retirement shim would leave a check that cannot be rebuilt green, or if a host output fails to evaluate after Orca is removed.
- **Execution profile:** Mostly deletion plus comment and doc edits; prove it with `nix fmt -- --ci`, `nix flake check`, and a repository-wide search for Orca.
- **Finishes and ships:** `ce-work` implements; the `lfg` pipeline reviews, commits, and opens the PR.

---

## Product Contract

### Summary

Remove Orca from the flake. The Orca AppImage package, its Linux desktop install, its macOS cask, the `orca-desktop` check, the retirement shims for Orca skills, the `orca-orchestration` plugin, and the Antigravity hook entry all go. Tokscale stops scanning Orca's Codex account directories. Comments, test fixtures, and docs that cite Orca are reworded or removed.

### Problem Frame

The user has moved entirely to T3 Code. Orca is still installed on every NixOS GUI host and every macOS host, still guarded by a check, and still referenced across the code and docs. Keeping it costs build time and review attention, and the docs describe a setup the user no longer runs.

### Key Decisions

- KD1. **Remove Orca management entirely.** (session-settled: user-directed — chosen over keeping Orca installed and configured beside T3 Code: the user has completely moved to T3 Code.) Governs R1-R6.

### Requirements

**Package and install**

- R1. No `nixosConfigurations`, `homeConfigurations`, or `darwinConfigurations` output installs `orca-ide`, and `packages/orca.nix` no longer exists.
- R2. No check asserts that Orca is installed.

**Retired state**

- R3. The one-shot shims that cleaned up earlier Orca state are deleted: `home.activation.retireOrcaSkills`, the `orca-orchestration` plugin retirement, and the Antigravity `orca-orchestration` hook removal.

**Usage reporting**

- R4. The Tokscale wrapper no longer adds `~/.config/orca/codex-accounts/*/home/sessions`. It still adds the Antigravity ACP directories.

**Text**

- R5. Outside `.compound-engineering/artifacts/`, no file mentions Orca except where `AGENTS.md` links a solution document by its file name.
- R6. Docs and `README.md` describe T3 Code as the agent environment, with no Orca setup or verification steps.

### Scope Boundaries

- Historical plans and solutions under `.compound-engineering/artifacts/` stay as they are. They record past work.
- Orca's runtime state on the user's machines (`~/.config/orca`, the Orca app on macOS, any `orca-status` hook entry Orca wrote) is not deleted by the flake. The macOS cask cleanup is `"none"`, so the installed app stays until the user removes it.
- Considered and not built: a check that fails when any output installs Orca. Removing the package file makes reintroduction a visible, deliberate edit, so a guard adds nothing. A future request to reinstall Orca would change that.
- Considered and not built: an activation step that deletes `~/.config/orca`. That directory holds user data Orca owns, and the user can remove it by hand.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Delete the retirement shims instead of keeping them.** The plugin and hook shims shipped on 2026-09-29 (`d58e2df`) and say to delete them once every host has rebuilt past them. The skills shim shipped on 2026-10-04 (`cfd6dab`) and is "kept while any home may still hold the old copies". The macOS host was added on 2026-10-08 and holds no `.orca-skills` manifest. Keeping them would leave Orca code in the tree with no remaining purpose. Governs R3.
- KTD2. **Keep the agent-plugin retirement mechanism with an empty list.** `retired` in `home/h82/agents/agent-plugins.nix` and `retiredKeys` in `home/h82/agents/gemini.nix` are general mechanisms. Only the Orca entries go. The Antigravity hooks merger, whose declaration exists only to remove `orca-orchestration`, is deleted outright, with the `antigravityHooks` activation and its test block.
- KTD3. **Keep Codex's update-suppression wrapper flags.** They stop Codex from updating itself under any `CODEX_HOME`, including the per-provider homes T3 Code creates. Only the comments that justify them through Orca change.
- KTD4. **Keep the Android SDK contents unchanged.** The SDK still serves Android development. Only comments that justify `emulator/emulator` through Orca are reworded, and the Orca emulator verification step in `docs/verification.md` is removed.
- KTD5. **Rename Orca-named fixtures in the generic merge tests.** The `agent-settings` tests in `flake.nix` and `tests/test_agent_settings.py` prove that an entry the declaration does not own survives byte for byte. That behavior stays. The `orca-status` / `orca-hook` fixture names become a neutral foreign entry name.

### Assumptions

- The MS-7D91 NixOS host, the only Linux host, has produced a new Home Manager generation since 2026-10-04, so all three shims have already run there (KTD1). If it has not, its leftover Orca skill copies are the directories each `.orca-skills` manifest lists, and they are removed by hand.
- The AGENTS.md link to the Podman pause-process solution stays because the T3 Code wrapper uses the same `CONTAINER_HOST` isolation. The link to the hardlinked-skill-file solution stays because its lesson applies to any tool that inspects files on disk. Both keep their Orca-named file targets and get link text and trigger wording without Orca, as R5 requires.

### Sequencing

U1 first, because U2 through U4 edit files whose Orca references depend on the package existing. U2, U3, and U4 are independent of one another; U5 follows U2 and U3.

---

## Implementation Units

### U1. Remove the Orca package and its install points

- **Goal:** Orca is no longer built or installed on any host.
- **Requirements:** R1, R2 (KD1)
- **Dependencies:** none
- **Files:**
  - Delete `packages/orca.nix`
  - Delete `orca.yaml` (Orca's workspace setup config; `t3.json` already runs the same setup commands)
  - Modify `home/h82/default.nix` (drop the `gui` entry importing it)
  - Modify `modules/shared/darwin-apps.nix` (drop `orca-ide.cask`)
  - Modify `tests/non-nixos-outputs.nix` (drop `"orca-ide"` from the GUI package list)
  - Modify `flake.nix` (delete the `orca-desktop` check; reword the t3code check comment that says "as the orca-desktop check does")
  - Modify `packages/t3code.nix` (reword the comment citing `packages/orca.nix`)
- **Approach:** Check whether `orca-desktop` appears in `hostClosureChecks` or any shard list in `flake.nix` and remove it there too. The `darwin-config` check fails on any NixOS GUI package without a macOS decision, so removing the package and the cask together keeps it consistent.
- **Patterns to follow:** Earlier removals in `.compound-engineering/artifacts/plans/2026-09-22-1630-chore-remove-omp-and-orca-config-plan.md`.
- **Test scenarios:**
  - `non-nixos-outputs` still passes with `orca-ide` gone from its list of packages a non-NixOS host must not carry.
  - `darwin-config` still evaluates with no `orca-ide` entry in `darwin-apps.nix`.
  - `check-shards-guard` still passes after the `orca-desktop` check is deleted.
- **Verification:** `nix flake check` evaluates, and no host's user packages contain `orca-ide`.

### U2. Delete the Orca retirement shims

- **Goal:** No activation or check exists only to clean up Orca leftovers.
- **Requirements:** R3 (KTD1, KTD2)
- **Dependencies:** U1
- **Files:**
  - Delete `home/h82/agents/retire-orca-skills.nix` and `tests/retire-orca-skills.nix`
  - Modify `home/h82/agents/default.nix` (drop the import)
  - Modify `flake.nix` (drop the `retire-orca-skills` check registration)
  - Modify `home/h82/agents/agent-plugins.nix` (empty `retired`)
  - Modify `tests/agent-plugins.nix` (remove the `orca-orchestration` retirement assertions)
  - Modify `home/h82/agents/gemini.nix` (delete `declaredHooks` and the `antigravityHooks` activation)
  - Modify `tests/gemini.nix` (remove the hooks assertions and their doc comment)
- **Approach:** The retirement code path in `agent-plugins.nix` stays and runs over an empty list. If `tests/agent-plugins.nix` has helpers used only by the Orca block, remove them too so nothing is left unused.
- **Test scenarios:**
  - `agent-plugins` passes with an empty `retired` list.
  - `gemini` passes and no longer expects an `antigravityHooks` activation.
- **Verification:** The `retire-orca-skills` check is gone from `checks`, and `agent-plugins` and `gemini` build.

### U3. Drop Orca's Codex sessions from Tokscale

- **Goal:** Tokscale stops scanning Orca's Codex account directories.
- **Requirements:** R4
- **Dependencies:** U1
- **Files:**
  - Modify `scripts/tokscale` (drop the `codex` `add_dirs` line and the Orca wording in the header and comment)
  - Modify `tests/tokscale.sh` (remove the Codex session directory section and the ordering assertion between Codex sessions and Antigravity conversations)
- **Approach:** The Antigravity section of the test already covers the `add_dirs` helper, the comma skip, and appending after a caller-supplied `TOKSCALE_EXTRA_DIRS`. Move any of those assertions that exist only in the Codex section into the Antigravity section, so coverage does not drop.
- **Test scenarios:**
  - A caller-supplied `TOKSCALE_EXTRA_DIRS` is kept and Antigravity directories are appended after it.
  - With no Antigravity directories, `TOKSCALE_EXTRA_DIRS` stays unset.
- **Verification:** The `tokscale` check passes.

### U4. Reword Orca comments and rename fixtures

- **Goal:** Code comments and test fixtures no longer cite Orca.
- **Requirements:** R5 (KTD3, KTD4, KTD5)
- **Dependencies:** U1
- **Files:**
  - Modify `home/h82/agents/codex.nix`, `packages/codex.nix`, and the `codex` check comment in `flake.nix` (justify the wrapper flags by any `CODEX_HOME`, such as T3 Code's per-provider homes)
  - Modify `home/h82/agents/instructions/default.nix` (drop the Orca `CODEX_HOME` remark)
  - Modify `home/h82/security/ssh.nix` (drop Orca from the wrapper comment)
  - Modify `packages/android-sdk.nix` and `tests/android-sdk.nix` (justify `emulator/emulator` without Orca)
  - Modify `flake.nix` (rename the `orca-status` fixture in the packaged `agent-settings` test)
  - Modify `tests/test_agent_settings.py` (rename the `orca-status` fixture and its comment)
  - Modify `tests/agent-instructions.nix` (remove the "mentions Orca" assertion and its doc line)
- **Test scenarios:**
  - The renamed foreign entry survives an owned-key merge byte for byte, in both `flake.nix` and `tests/test_agent_settings.py`.
  - `agent-instructions` still fails when a harness file names the other harness's tools.
- **Verification:** The agent settings, `agent-instructions`, `android-sdk`, and `codex` checks pass.

### U5. Update docs and AGENTS.md

- **Goal:** The docs describe T3 Code as the agent environment and contain no Orca steps.
- **Requirements:** R5, R6
- **Dependencies:** U1, U2, U3
- **Files:**
  - Modify `README.md` (drop Orca from the Tokscale description and the macOS cask list)
  - Modify `docs/macos.md` (drop Orca from the cask list)
  - Modify `docs/provisioning.md` (drop the Orca `CODEX_HOME` paragraph, the "mentions Orca" clause, the Orca comparison in the T3 Code wrapper paragraph, and the `codex-accounts` Tokscale entry)
  - Modify `docs/verification.md` (drop the Orca Tokscale, Codex, and emulator items; reword the Podman pause-process item to name T3 Code's sandbox)
  - Modify `AGENTS.md` (reword the link text and trigger of the Podman pause-process and hardlinked-skill-file links without Orca, keeping their file targets, per Assumptions)
- **Approach:** Delete the Codex-through-Orca verification items. Keep the plain Codex verification items, reworded without "outside Orca".
- **Test expectation:** none -- documentation only; the pre-commit Markdown lint covers it.
- **Verification:** `markdownlint-cli2` passes on the changed files and the repository-wide search in the Verification Contract is clean.

---

## Verification Contract

| Gate | Command | Applies to |
| --- | --- | --- |
| Formatting | `nix fmt -- --ci` | all units |
| Evaluation and checks | `nix flake check` (on this macOS builder, the Linux checks evaluate; CI's `check-shards` jobs build them) | U1-U4 |
| macOS output | `nix build --no-link .#darwinConfigurations.<host>.system` for each host | U1 |
| Markdown | `mise run lint-staged-markdown` via the pre-commit hook | U5 |
| Orca content search | `git grep -niI orca -- ':!.compound-engineering'` returns only the two AGENTS.md solution-link targets (tracked files only, so the gitignored `.agents/` plugin copies do not count) | all units |
| Orca file names | `git ls-files \| grep -i orca \| grep -v '^.compound-engineering/'` returns nothing | U1, U2 |

---

## Definition of Done

- R1-R6 hold.
- Every gate in the Verification Contract passes, or a gate that needs a Linux builder is left to CI and reported that way.
- No helper, variable, or test fixture is left unused after the Orca code paths are removed.
