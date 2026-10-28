---
title: Claude Code Dangerous-rm Waiver and Orca Retirement - Plan
type: feat
date: 2026-10-28
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Claude Code Dangerous-rm Waiver and Orca Retirement - Plan

## Goal Capsule

- **Objective:** A Claude Code session started in full access (bypass permissions) mode, from T3 Code or a terminal, on any host, runs commands that trip the dangerous-rm check without stopping for approval, and no Orca hook, status line, app, or data remains on any host.
- **Means:** declare `CLAUDE_CODE_EVEN_MORE_DANGEROUSLY_SKIP_PERMISSIONS=1` in Claude Code's environment tier (KTD1, KTD2) and retire every Orca leftover from Home Manager activation and the macOS retired-cask step (KTD3-KTD6).
- **Authority:** the Product Contract's Key Decisions and Requirements, then the KTDs, then unit text.
- **Stop conditions:** stop and report when the waiver turns out to need a change outside this repository, or when Orca cleanup would have to delete anything outside the paths R4-R8 name.
- **Execution profile:** Nix and Python configuration with repository checks; no hardware or live-host apply in this change.
- **Finish and ship:** `ce-work` implements; the LFG pipeline reviews, opens the pull request, and watches CI.

---

## Product Contract

### Summary

Declare Claude Code's dangerous-rm waiver variable for every host and retire Orca's leftovers: its hooks and status line in the agent settings files, its state directories, and on macOS its cask and tap.

### Problem Frame

T3 Code's full access mode still stops Claude Code sessions with "Dangerous rm operation not ruled out" approval prompts. Claude Code 2.1.312 (`packages/claude-code-manifest.json`) marks that check, `dangerousRemoval`, as bypass-immune but waivable: the environment variable `CLAUDE_CODE_EVEN_MORE_DANGEROUSLY_SKIP_PERMISSIONS` lifts it in bypass permissions mode, but only when no `PermissionRequest` hook and no Bash or PowerShell deny or ask rule exists. Orca, retired in PR #189, left hooks on every Claude Code event in `~/.claude/settings.json`, including `PermissionRequest`, so the variable alone would do nothing. Orca also left hooks for Codex and Antigravity, a Claude status line, state directories, and on macOS a cask the configuration no longer installs.

### Key Decisions

- **Waive the dangerous-rm check for every main bypass-mode session.** (session-settled: user-approved — chosen over leaving the prompt in place: the user wants full-access sessions not to stop for this approval, and accepted that the non-waivable checks and subagent sessions keep prompting and that terminal sessions get it too.) Governs R1, R2, R3.
- **Remove Orca completely.** (session-settled: user-directed — chosen over removing only the PermissionRequest hook or keeping Orca's state: Orca is no longer used and its hooks block the waiver; the user accepted irreversible deletion of its data.) Governs R4, R5, R6, R7, R8.

### Requirements

**Dangerous-rm waiver**

- R1. Every Home Manager user environment declares `CLAUDE_CODE_EVEN_MORE_DANGEROUSLY_SKIP_PERMISSIONS=1` for Claude Code.
- R2. On a macOS host, an app launched from Finder or the Dock, T3 Code included, inherits the same variable.
- R3. The repository declares no Claude Code `PermissionRequest` hook and no Bash or PowerShell deny or ask permission rule, since either silently voids R1.

**Orca retirement**

- R4. Activation removes every Orca hook entry from `~/.claude/settings.json` and `~/.codex/hooks.json`, and Orca's `orca-status` entry from `~/.gemini/config/hooks.json`, leaving entries Orca did not write in place.
- R5. Activation removes Orca's Claude Code `statusLine` from `~/.claude/settings.json` and leaves any other status line in place.
- R6. Activation deletes `~/.orca/` and `~/.config/orca/` on every host, and Orca's Electron data under `~/Library/Application Support/` on macOS.
- R7. On macOS, the retired-cask step uninstalls the `stablyai/orca/orca` cask and then untaps `stablyai/orca`, never failing the apply.
- R8. Cleanup is idempotent: an apply on a host with no Orca leftovers changes nothing and reports no error.

### Scope Boundaries

- GNOME's Orca screen reader (nixpkgs `orca`, on the NixOS system path) is a different program and stays untouched.
- Historical Orca plans and learnings under `.compound-engineering/artifacts/` stay as records.
- The four non-waivable bypass-immune checks (`unfinishedCheck`, `outsideReadsBlocked`, `restrictedMode`, `isolatePeerMachines`) and subagent sessions keep prompting; no repository change can lift them.
- Considered and not built: a check that the live `~/.claude/settings.json` has no `PermissionRequest` hook. Repository checks cannot read live user state, and a void waiver surfaces at once as the approval prompt returning. Claude Code's "has no effect in this session" startup warning does not explain it in T3 Code, which discards the subprocess's stderr and its notification frames, so the hardware check in the Verification Contract names where to look instead. Evidence that the prompt can return unnoticed would change the call.

### Deferred to Follow-Up Work

- Delete the Orca retirement step (U2) and the cask entry (U3) once every host has applied them, following the precedent of commit `f2018ba3`.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Environment tier for the waiver variable.** Add it to `environmentTier` in `home/h82/agents/claude.nix`, where Claude Code's persistent environment settings already live and which this T3 Code session demonstrably inherits on Linux: the running `claude` process carries `DISABLE_AUTOUPDATER=1` from that tier. The managed settings tier is ruled out because the waiver requires managed settings to load empty.
- KTD2. **A launchd agent carries the variable to macOS GUI apps.** Mirror `launchd.agents.claude-stream-timeout` and `t3code-disable-auto-update`: `launchctl setenv` at load on every macOS host, since Finder and Dock launches do not read shell session variables. Unlike the stream timeout, this one has no trait gate.
- KTD3. **One idempotent Orca retirement step in Home Manager activation.** Run a packaged Python helper from a new `home/h82/agents/retire-orca.nix`, modeled on the deleted `retire-orca-skills.nix` from commit `f2018ba3`: it runs on every activation, is a no-op once the leftovers are gone, and is removed in follow-up work. Order it after `claudeSettings`, `claudeGlobalConfig`, and the Codex and Antigravity settings merges, so the merges and the retirement never write the same file concurrently and the retirement sees the merged file.
- KTD4. **Identify Orca entries by their command text.** A hook or status line counts as Orca's when its command references `ORCA_AGENT_HOOK` or `/.orca/agent-hooks/`; every live entry today matches. Remove matching hooks from each group's `hooks` array and keep the group's other hooks and its `matcher`, then drop groups left with no hooks, then events left empty, then the `hooks` key when it is empty. In `~/.gemini/config/hooks.json` the entry is the `orca-status` key. Delete `~/.codex/hooks.json` only when nothing but Orca entries remains, together with the `[hooks.state."<that file>:…"]` trust entries in `~/.codex/config.toml`, which the existing TOML merger can drop.
- KTD5. **Delete the state directories with exact paths.** Remove only `~/.orca`, `~/.config/orca`, and on macOS the Orca directory under `~/Library/Application Support/`, each with a guard against an empty `HOME`. Refuse to follow a symlink at any of those paths: remove the link itself, never its target.
- KTD6. **Reuse the retired-cask step for the app.** Add `stablyai/orca/orca` to `retired` in `modules/darwin/retired-casks.nix`, and add an untap of `stablyai/orca` after it in the same best-effort, never-failing style. The tap was declared through `tapOf` in `modules/shared/darwin-apps.nix` and taps stay mutable, so nothing else removes it.

### Assumptions

- The user confirmed this scope in the brainstorm that preceded this plan, so the scoping confirmation was skipped.
- T3 Code launches the main `claude` process without `CLAUDE_CODE_CHILD_SESSION`; verified on the Linux desktop for this session's parent process. Only subagents and tool children carry it.
- T3 Code's full access mode runs Claude Code in `bypassPermissions` mode.
- The macOS Orca app's Electron data lives at `~/Library/Application Support/orca` or `~/Library/Application Support/Orca`; the implementer confirms the name from the cask definition and handles both when unsure.

### Sources

- Claude Code 2.1.312 bundle: the `mUe` safety-check table (`dangerousRemoval` is the only entry with `waivableInBypass: true`), the waiver functions that read `CLAUDE_CODE_EVEN_MORE_DANGEROUSLY_SKIP_PERMISSIONS`, and the rule check that voids it for `PermissionRequest` hooks and Bash or PowerShell deny or ask rules.
- `home/h82/agents/claude.nix` (`environmentTier`, `retiredKeys`, `launchd.agents.claude-stream-timeout`), `home/h82/t3code.nix` (`t3code-disable-auto-update`), `modules/darwin/retired-casks.nix`, `packages/agent-tools.nix`, and `scripts/agent-settings`.
- Commits `3de9298a` (stop installing Orca, removed cask `stablyai/orca/orca`) and `f2018ba3` (the earlier Orca retirement shims and their removal).
- Learnings: `.compound-engineering/artifacts/solutions/best-practices/home-manager-activation-does-not-run-on-every-rebuild.md`, `activation-step-grep-check-passes-an-echo-only-step.md`, `nix-darwin-preactivation-reads-previous-generation-etc.md`, and `mutation-testing-reveals-decorative-nix-check-assertions.md`.

---

## Implementation Units

### U1. Declare the waiver variable

- **Goal:** Claude Code receives `CLAUDE_CODE_EVEN_MORE_DANGEROUSLY_SKIP_PERMISSIONS=1` from every launch path.
- **Requirements:** R1, R2, R3; KTD1, KTD2.
- **Dependencies:** none.
- **Files:** `home/h82/agents/claude.nix`, `tests/claude.nix`, `tests/darwin-outputs.nix` or `tests/darwin-config.nix` (whichever already checks the stream-timeout launchd agent's materialized plist).
- **Approach:**
  1. Add the variable to `environmentTier` with a comment naming the waiver and its two voiding conditions (R3).
  2. Add a `launchd.agents` entry on macOS that runs `launchctl setenv` for it at load, and an activation step that sets it immediately, mirroring `claudeStreamTimeout` without the trait condition.
- **Patterns to follow:** `launchd.agents.claude-stream-timeout` and `home.activation.claudeStreamTimeout` in `home/h82/agents/claude.nix`.
- **Test scenarios:**
  - Every user environment's session variables carry the variable with value `1` (extend `environmentTier` in `tests/claude.nix`).
  - The macOS fixture's materialized launch agent plist runs `/bin/launchctl setenv CLAUDE_CODE_EVEN_MORE_DANGEROUSLY_SKIP_PERMISSIONS 1` at load.
  - The declared Claude settings JSON has no `hooks.PermissionRequest` key and no `permissions.deny` or `permissions.ask` entry naming Bash or PowerShell (R3), read from the rendered declared file.
- **Verification:** the checks above pass and each turns red under a mutation that drops the variable, the launch agent, or adds a `PermissionRequest` hook to the declared settings.

### U2. Retire Orca's agent hooks, status line, and state

- **Goal:** one activation step leaves no Orca hook, status line, or state directory in the user's home.
- **Requirements:** R4, R5, R6, R8; KTD3, KTD4, KTD5.
- **Dependencies:** none.
- **Files:** `scripts/retire-orca` (new), `packages/agent-tools.nix`, `home/h82/agents/retire-orca.nix` (new), `home/h82/agents/default.nix`, `home/h82/agents/codex.nix` (only if the trust-state removal goes through its existing TOML merge), `tests/retire-orca.py` (new) or a new check beside `tests/agent-retirement.py`, `flake.nix`, `tests/check-shards.nix`.
- **Approach:**
  1. Package the helper through `helperWith`/`pythonHelper` in `packages/agent-tools.nix` (with `tomlkit` when it edits `config.toml`).
  2. The helper rewrites each JSON file atomically only when it changed something, keeps the file's mode, and leaves an unreadable or malformed file alone with one warning line instead of failing the apply.
  3. The activation entry runs after the settings merges named in KTD3, honors `DRY_RUN`, and never fails the rebuild.
  4. Register the new check in `flake.nix` and a shard in `tests/check-shards.nix`.
- **Execution note:** Load the `test-audit` skill before writing the check. Execute the activation block in a scratch `HOME` rather than grepping its text.
- **Patterns to follow:** the deleted `home/h82/agents/retire-orca-skills.nix` (commit `f2018ba3`), `tests/agent-retirement.py`, and `tests/lib/agent-activation.nix`.
- **Test scenarios:**
  - A scratch home seeded with the live shapes (Orca groups on every Claude and Codex event, an Orca `statusLine`, Gemini `orca-status`, `~/.orca/agent-hooks/claude-hook.sh`, `~/.config/orca/ai-vault/`) ends with no Orca entry, no `statusLine`, no Codex `hooks.json` or its trust entries, and neither directory.
  - A non-Orca hook group on `PreToolUse` and a non-Orca `statusLine` survive while the Orca group on the same event is removed.
  - A group holding one Orca hook and one non-Orca hook keeps the non-Orca hook and its `matcher`.
  - A second run on the cleaned home changes no file's content or mtime and exits 0 (R8).
  - A malformed `~/.claude/settings.json` is left byte-identical, one warning is printed, and the step exits 0.
  - A `~/.orca` symlink pointing at another directory is removed as a link and its target survives.
  - Unrelated keys in each file (`model`, `enabledPlugins`, Codex `[projects]`) are preserved byte-for-byte in value.
- **Verification:** the check passes against the materialized activation of every user environment, and mutating the Orca matcher, the empty-event pruning, or the symlink guard turns it red.

### U3. Retire the Orca cask and tap on macOS

- **Goal:** a macOS apply uninstalls the Orca app bundle and its tap without failing.
- **Requirements:** R7, R8; KTD6.
- **Dependencies:** none.
- **Files:** `modules/darwin/retired-casks.nix`, `tests/darwin-outputs.nix`.
- **Approach:**
  1. Add `stablyai/orca/orca` to `retired`, confirming that the not-installed message `brew list --cask` prints for a tap-qualified token matches the comparison the step makes.
  2. After the cask loop, untap `stablyai/orca` only when `brew tap` lists it, with one line on success or failure and no exit.
- **Patterns to follow:** the existing `grok-bot` handling and its assertions in `tests/darwin-outputs.nix`.
- **Test scenarios:**
  - The postActivation script lists, uninstalls, and reports `stablyai/orca/orca` with the same guards as `grok-bot`.
  - The untap runs after the cask uninstall, is guarded by a tap listing, and every failure branch prints one line without exiting.
- **Verification:** `checks.aarch64-darwin` and `darwinConfigurations.<host>.system` build in CI's `build-darwin` job.

### U4. Update documentation

- **Goal:** the repository's descriptions match the new behavior.
- **Requirements:** R1, R6, R7.
- **Dependencies:** U1, U2, U3.
- **Files:** `AGENTS.md` (the `retired-casks.nix` description lists the casks it removes, and the `home/h82/` description), `docs/` pages that describe Claude Code's environment tier, if any.
- **Approach:** name `stablyai/orca/orca` beside `grok-bot` in the `retired-casks.nix` description, and mention the Orca retirement step and the waiver variable where the agents domain is described.
- **Test scenarios:** Test expectation: none -- documentation only; `agent-instructions` still has to pass because it reads `AGENTS.md`.
- **Verification:** Markdown lint passes and `agent-instructions` builds.

---

## Verification Contract

| Gate | Command or evidence | Applies to |
| --- | --- | --- |
| Formatting | `nix fmt -- --ci` | all units |
| Flake evaluation | `nix flake check --no-build` | all units |
| Touched checks | `nix build --no-link .#checks.x86_64-linux.<claude, retire-orca, darwin-config, agent-instructions>` and the matching `.#checkShards.<name>` | U1, U2, U4 |
| macOS outputs | CI `build-darwin` job (no local macOS builder) | U1, U3 |
| Host outputs | every `nixosConfigurations.<host>.config.system.build.toplevel`, `homeConfigurations`, and `systemConfigs` output, per `AGENTS.md` | U1, U2 |
| Mutation rounds | each new assertion turns red for its own reason under a targeted break | U1, U2, U3 |
| Markdown | `git diff --check` and the staged Markdown lint | U4, this plan |

No hardware check is part of this change: nothing here runs `nr switch`. The live effect (no dangerous-rm prompt in T3 Code full access, Orca gone) is a hardware check the user performs after applying. When the prompt still appears in a main T3 Code session, inspect the live `~/.claude/settings.json` and enabled plugins for a surviving `PermissionRequest` hook and for a Bash or PowerShell ask or deny rule, since T3 Code does not show Claude Code's startup warning.

---

## Definition of Done

- U1-U4 are implemented, and every check in the Verification Contract passes or is recorded as deferred to CI.
- Each new or changed assertion has a recorded mutation round that turned it red for its own reason.
- No code from abandoned approaches remains in the diff.
- The pull request body names the follow-up removal of U2 and the cask entry, and reports the hardware check as pending on the user.
