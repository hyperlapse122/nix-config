---
title: Remove Orca Orchestration Hooks - Plan
type: refactor
date: 2026-09-29
topic: remove-orca-orchestration-hooks
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# Remove Orca Orchestration Hooks - Plan

## Goal Capsule

- **Objective:** Agents running inside Orca delegate through their harness's own subagent tools like any other session, and they no longer receive injected orchestration rules that they treat as prompt injection.
- **Means:** remove the session-start guide injection and the subagent guard from Claude Code and Antigravity, and retire what earlier rebuilds left on deployed machines (KTD1–KTD3).
- **Product authority:** the repository owner (h82), confirmed in the brainstorm dialogue of 2026-09-29. The Product Contract wins on behavior; KTDs win on mechanism.
- **Execution profile:** Standard. Deletions across scripts, packaging, Nix wiring, and checks, plus one new retirement path in `agent-plugin-sync`.
- **Stop conditions:** stop and report if the Claude Code CLI offers no non-interactive way to uninstall a user-scope plugin and remove its marketplace, since R4 then cannot be met by activation.
- **Who finishes:** `ce-work` implements and verifies in the pipeline; merge stays with the user. No `nixos-rebuild switch` as validation (AGENTS.md).
- **Open blockers:** none.

---

## Product Contract

Product Contract preservation: unchanged in meaning. The two Deferred-to-Planning questions were resolved in place into KTD1 and KTD2.

### Summary

Inside Orca, Claude Code and Antigravity sessions start without an injected orchestration guide, and their harness subagent tools are no longer denied.
Orca orchestration stays available as an opt-in skill that loads only when the user asks for it.
A rebuild on a machine that ran the old configuration leaves no trace of the removed hooks.

### Problem Frame

The `orca-orchestration` plugin injects Orca's orchestration guide at every Claude Code session start and adds a standing rule that the session refuses harness subagents.
A PreToolUse guard then denies `Agent`/`Task` in Claude Code and `invoke_subagent` in Antigravity, and its deny reason tells the agent to re-dispatch through Orca workers.
Agents increasingly judge this injected text to be prompt injection, because it arrives without a user request and contradicts skill instructions.
The result is an agent that neither delegates nor follows the Orca route reliably.
Enforcing one delegation path through hooks has proven harder to keep working than letting the harness's native path stand.

### Key Decisions

- **Neither forbid nor force a delegation path.** Harness-native subagents are allowed inside Orca, and nothing injects a rule pushing agents toward Orca workers. Governs R1, R2, R3. (session-settled: user-directed — chosen over keeping the guard with a softer deny reason: injected rules keep reading as prompt injection, and enforcement is hard to keep working)
- **Keep the upstream `orchestration` skill installed.** It loads only on explicit request, so it carries no enforcement. Governs R5. (session-settled: user-directed — chosen over excluding the skill from the Orca skill install: the Orca worker route should stay available when the user asks to supervise)
- **Deployed machines are cleaned, not just future ones.** Removing declarations alone would leave the Claude Code plugin registered and the Antigravity hook entry in place, so the removed behavior would keep running. Governs R4.
- **The worker-takeover cleanup note goes with the guide.** It only existed inside the injected guide, and it has no home once the injection is gone. Governs R1.
- **Retire the learnings that only describe the guard.** The deny-reason learning and the Antigravity PreToolUse contract learning both name the guard as their subject, and their retire conditions are met by this change. Governs R6. (session-settled: user-approved — chosen over keeping the Antigravity PreToolUse contract learning for future hooks: its retire_when condition is met)

### Requirements

**Hook removal**

- R1. A Claude Code or Antigravity session started inside Orca receives no Orca orchestration guide, delegation rule, or worker-cleanup note from this repository's configuration.
- R2. Claude Code's `Agent`/`Task` and Antigravity's `invoke_subagent` run inside Orca with no hook from this repository denying them.
- R3. The packaged context and guard scripts, their plugin, and their repository checks are removed rather than left in the tree disabled.

**Deployed-state cleanup**

- R4. After one rebuild on a machine that ran the previous configuration, Claude Code no longer has the `orca-orchestration` plugin or marketplace registered, and `~/.gemini/config/hooks.json` no longer has an `orca-orchestration` entry, while Orca's own `orca-status` entry is left intact.

**What stays**

- R5. The upstream Orca skills, `orchestration` included, keep installing to the same three skill roots.

**Documentation**

- R6. `AGENTS.md` no longer points at learnings about the guard or the deny reason, the two guard-specific learnings are removed, and no repository doc describes the removed hooks as current behavior.

### Acceptance Examples

- AE1. **Covers R4.** **Given** a machine whose `~/.gemini/config/hooks.json` holds both `orca-status` and `orca-orchestration`, **when** home activation runs the new configuration, **then** only `orca-status` remains and its value is byte-identical.
- AE2. **Covers R4.** **Given** Claude Code with the `orca-orchestration` plugin installed from an earlier generation, **when** home activation runs, **then** `claude plugin list` no longer shows it and the plugin's hooks stop firing at session start.
- AE3. **Covers R1, R2.** **Given** a fresh Claude Code session in an Orca terminal, **when** it starts and calls `Agent`, **then** no orchestration guide appears in its context and the call runs.

### Scope Boundaries

- Orca itself and the `orca-status` hook that Orca writes at runtime stay untouched.
- Subagent limits such as `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` and `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` stay as they are.
- The generic `own` merge in `agent-settings` stays; only its fixtures' use of the `orca-orchestration` name changes (U5).
- Previously written plans that describe the guard stay as historical records.

### Deferred to Follow-Up Work

- Drop the `orca-orchestration` retirement entries (KTD1, KTD2) once every host has rebuilt past this change.

### Sources / Research

- `packages/orca-orchestration-plugin.nix`: the Claude Code plugin carrying the SessionStart and PreToolUse hooks.
- `home/h82/agents/agent-plugins.nix`: the `orca-orchestration` source and membership rows, and the local-source `segment` branch that exists only for it.
- `home/h82/agents/gemini.nix`: the owned `orca-orchestration` hook entry and the `retiredKeys` convention.
- `scripts/orca-orchestration-context`, `scripts/orca-subagent-guard`, `packages/agent-tools.nix`: the scripts and their packaging.
- `scripts/agent-plugin-sync` and `tests/test_agent_plugin_sync.py`: the sync helper and its fake-CLI test harness.
- `flake.nix` checks `orca-orchestration-context`, `orca-orchestration-plugin`, `orca-subagent-guard`, and the `agent-settings` owned-key fixture; `tests/gemini.nix` asserts the owned hook entry; `tests/agent-plugins.nix` asserts the local plugin; `tests/test_agent_settings.py` uses `orca-orchestration` as its owned-key fixture name.
- `.compound-engineering/artifacts/solutions/integration-issues/orca-subagent-deny-reason-loses-to-skill-inline-fallback.md` and `.compound-engineering/artifacts/solutions/integration-issues/antigravity-pretooluse-hook-contract-and-probing.md`: the learnings R6 retires.
- `.compound-engineering/artifacts/plans/2026-09-28-0033-feat-orca-orchestration-session-injection-plan.md` and `.compound-engineering/artifacts/plans/2026-09-28-1704-feat-orca-harness-subagent-deny-plan.md`: the plans that added the injection and the guard.
- `claude plugin uninstall --help` and `claude plugin marketplace remove --help` (Claude Code 2.1.284): both exist, uninstall defaults to user scope, and `plugin list --json` / `plugin marketplace list --json` report `id` and `name` fields to test presence against.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Retire the Claude Code plugin through a `retired` list in `home/h82/agents/agent-plugins.nix` and a retirement mode in `agent-plugin-sync`.** The list names plugin, marketplace, and base directory, and activation runs the helper once per entry. The helper consults `plugin list --json` and `plugin marketplace list --json`, uninstalls the plugin only when listed, removes the marketplace only when listed, then deletes the version-keyed base directory. Presence checks instead of parsing error text keep a converged rerun quiet and make every other CLI failure stop activation. Rationale: it mirrors the `retiredKeys` convention in `gemini.nix` and keeps all Claude plugin CLI driving in the one helper that already has a fake-CLI test harness. Governs R4.
- KTD2. **Retire the Antigravity hook entry through `remove = [ "orca-orchestration" ]` in the declared hooks file.** `agent-settings` already drops a top-level key listed in `remove` and leaves every other key untouched, so `orca-status` survives byte for byte. The `antigravityHooks` activation stays, now carrying only the retirement. Governs R4.
- KTD3. **Delete the local-source branch of the agent plugin registry.** `segmentOf`'s `spec.segment` fallback and the local-source comment exist only for `orca-orchestration`; with it gone the registry has only pinned upstream sources, so `segmentOf` derives from the tag alone. A dead branch would otherwise be kept alive with no check exercising it. Governs R3.
- KTD4. **Rename the owned-key fixtures instead of deleting them.** `tests/test_agent_settings.py` and the `agent-settings` packaged-merge check in `flake.nix` use `orca-orchestration` only as a sample owned key; they test the generic merger, which stays. A neutral fixture name keeps that coverage without describing the removed hook as current. Governs R6.

### Assumptions

- Uninstalling the plugin before removing its marketplace is valid in either state: if marketplace removal already uninstalls its plugins in this CLI version, the presence check in KTD1 simply finds nothing left to remove.
- The version-keyed base directory `~/.local/share/agent-plugins/orca-orchestration` holds only symlinks this helper created, so deleting it whole is safe.

### Sequencing

U2 and U3 remove every consumer of the plugin package and the two `agentTools` attributes, so U1 depends on U2 and U3 and lands with or after them; the flake does not evaluate with U1 alone. U4, U5, and U6 are independent of the rest.

---

## Implementation Units

### U1. Remove the scripts, packaging, and plugin

- **Goal:** Nothing in the tree builds or ships the context script, the guard, or the `orca-orchestration` plugin.
- **Requirements:** R1, R2, R3.
- **Dependencies:** U2, U3.
- **Files:**
  - Delete `scripts/orca-orchestration-context`, `scripts/orca-subagent-guard`, `packages/orca-orchestration-plugin.nix`.
  - Delete `tests/orca-orchestration-context.sh`, `tests/orca-subagent-guard.sh`, `tests/orca-orchestration-plugin.nix`.
  - Modify `packages/agent-tools.nix` (drop `orcaOrchestrationContext`, `orcaSubagentGuard`, and their entries in the exported list).
  - Modify `flake.nix` (drop the `orca-orchestration-context`, `orca-orchestration-plugin`, and `orca-subagent-guard` checks).
- **Approach:** Pure deletion. Check that `flake.nix`'s package exports do not reference the removed attributes after the edit.
- **Test scenarios:** Test expectation: none -- deletion of shipped scripts; `nix flake check` evaluating without the removed attributes is the proof.
- **Verification:** `rg --hidden --glob '!.git' --glob '!.compound-engineering/artifacts/plans/**' 'orca-orchestration-context|orca-subagent-guard|orcaOrchestrationContext|orcaSubagentGuard'` finds nothing.

### U2. Retire the Antigravity hook entry

- **Goal:** Activation removes the `orca-orchestration` entry from `~/.gemini/config/hooks.json` and declares no new hooks.
- **Requirements:** R2, R4; KTD2.
- **Dependencies:** none.
- **Files:** `home/h82/agents/gemini.nix`, `tests/gemini.nix`.
- **Approach:**
  1. Replace the declared hooks file's `own.orca-orchestration` block with `remove = [ "orca-orchestration" ]`, and drop the `agentTools` script bindings.
  2. Rewrite the comment above it to say the entry is retired and when to delete the retirement (after every host has rebuilt), following the `retiredKeys` comment.
  3. Update `tests/gemini.nix`'s `hooksExpected` to the new declared file and its failure message and header comment to match.
- **Patterns to follow:** `retiredKeys` in the same file.
- **Test scenarios:**
  - Covers AE1. `tests/gemini.nix` diffs the rendered declared hooks file against `{ remove = [ "orca-orchestration" ]; }` on every configuration, and fails if the file regains an `own` block.
  - The existing check that `antigravityHooks` runs after `installPackages` and does not swallow the merger exit status still passes.
- **Verification:** `nix build .#checks.x86_64-linux.gemini` passes; mutating the declared file back to `own` turns it red.

### U3. Add plugin retirement to `agent-plugin-sync`

- **Goal:** The helper can retire a plugin idempotently, and activation retires `orca-orchestration`.
- **Requirements:** R4; KTD1, KTD3.
- **Dependencies:** none.
- **Files:** `scripts/agent-plugin-sync`, `tests/test_agent_plugin_sync.py`, `home/h82/agents/agent-plugins.nix`, `tests/agent-plugins.nix`.
- **Approach:**
  1. Add a retirement mode to `agent-plugin-sync` taking the CLI path, plugin, marketplace, and base directory, with the same root refusal and `--dry-run` handling as the sync mode.
  2. In that mode, read `plugin list --json`; if `<plugin>@<marketplace>` is listed, run `plugin uninstall <id> --scope user`. Then read `plugin marketplace list --json`; if the marketplace is listed, run `plugin marketplace remove <name>`. Then delete the base directory if it exists. Any non-zero CLI exit stops the run.
  3. In `agent-plugins.nix`, remove the `orca-orchestration` source and membership rows and the plugin import, delete the local-source branch of `segmentOf` and its comments (KTD3), and add a `retired` list whose entries render one retirement invocation each into the same `agentPlugins` activation, after the sync invocations.
  4. In `tests/agent-plugins.nix`, replace the local-plugin block with an assertion that the activation script runs the retirement for `orca-orchestration` with the expected base directory and that no sync invocation names it.
- **Patterns to follow:** the existing `main` in `scripts/agent-plugin-sync` (argument validation, `Failure`, `require`), and the fake CLI in `tests/test_agent_plugin_sync.py`, which needs `plugin list` and `plugin uninstall` handling added.
- **Test scenarios:**
  - Covers AE2. With the plugin installed and its marketplace registered, retirement runs uninstall then marketplace remove, and the fake registry ends with neither.
  - With neither present, retirement issues only the two list calls and exits 0 (converged rerun is quiet).
  - With the marketplace registered but the plugin already uninstalled, only marketplace remove runs.
  - An uninstall failure stops the run with a non-zero exit before marketplace remove.
  - The base directory and its symlinks are deleted; a sibling plugin's base directory is left alone.
  - `--dry-run` prints the would-run commands and touches neither registry nor filesystem.
  - Running as root is refused, as in sync mode.
  - `tests/agent-plugins.nix`: removing the `retired` entry, or re-adding `orca-orchestration` to membership, turns the check red.
- **Verification:** `nix build .#checks.x86_64-linux.agent-plugin-sync` and `.#checks.x86_64-linux.agent-plugins` pass.

### U4. Keep the Orca skills install unchanged

- **Goal:** Confirm R5 holds: the `orchestration` skill still installs to all three roots.
- **Requirements:** R5.
- **Dependencies:** none.
- **Files:** none changed; `tests/orca-skills.nix` is the existing proof.
- **Approach:** No edit. `home/h82/agents/orca-skills.nix` reads skill names from the pinned upstream tree and does not depend on the removed plugin.
- **Test scenarios:** Test expectation: none -- behavior unchanged; the existing `orca-skills` check covers it.
- **Verification:** `nix build .#checks.x86_64-linux.orca-skills` passes.

### U5. Neutralize the owned-key fixtures

- **Goal:** The generic `own` merge tests no longer use `orca-orchestration` as their sample key.
- **Requirements:** R6; KTD4.
- **Dependencies:** none.
- **Files:** `tests/test_agent_settings.py`, `flake.nix` (the `agent-settings` packaged owned-key block), `scripts/agent-settings` (the module docstring's `own` paragraph).
- **Approach:** Rename the fixture key to a neutral name such as `repo-owned`, and reword the comment that describes it as the repository's Antigravity hook. Keep `orca-status` as the foreign sibling, since Orca still writes it. Reword the docstring's `own` paragraph to describe a top-level key nobody else writes, without naming Antigravity's hooks.json entry as a current user.
- **Test scenarios:** Test expectation: none -- fixture rename; the existing assertions run unchanged against the new key.
- **Verification:** `nix build .#checks.x86_64-linux.agent-settings` passes.

### U6. Retire the guard learnings and their links

- **Goal:** Repository instructions stop routing agents to learnings about hooks that no longer exist.
- **Requirements:** R6.
- **Dependencies:** none.
- **Files:**
  - Delete `.compound-engineering/artifacts/solutions/integration-issues/orca-subagent-deny-reason-loses-to-skill-inline-fallback.md` and `.compound-engineering/artifacts/solutions/integration-issues/antigravity-pretooluse-hook-contract-and-probing.md`.
  - Modify `AGENTS.md` (drop the two sentences that link them).
- **Approach:** Check that no other learning links either file before deleting.
- **Test scenarios:** Test expectation: none -- documentation only.
- **Verification:** `rg --hidden --glob '!.git' --glob '!.compound-engineering/artifacts/plans/**' 'orca-subagent-deny-reason|antigravity-pretooluse-hook-contract'` finds nothing.

---

## Verification Contract

| Gate | Command | Proves |
|---|---|---|
| Format | `nix fmt -- --ci` | Nix layout unchanged by the edits |
| Checks | `nix flake check` | U1–U5 checks evaluate and pass |
| Host builds | Build every `nixosConfigurations` output, production and bootstrap, per `AGENTS.md` | No module still references removed attributes |
| Residue | `rg --hidden --glob '!.git' --glob '!.compound-engineering/artifacts/plans/**' 'orca-orchestration-context\|orca-subagent-guard\|orcaOrchestration\|orcaSubagent'` | R3 |

AE2 and AE3 on a real machine need a rebuild and an Orca session; report them as hardware verification separately, per `docs/verification.md`, and do not run `nixos-rebuild switch` as validation.

---

## Definition of Done

- Every unit's Verification holds, and the Verification Contract gates pass.
- No file outside `.compound-engineering/artifacts/plans/` names the removed scripts or learnings, and `orca-orchestration` appears only in the retirement entries (KTD1, KTD2) and the checks that cover them.
- The activation retires `orca-orchestration` from Claude Code and from `~/.gemini/config/hooks.json`, and the retirement is covered by a check that goes red when removed.
