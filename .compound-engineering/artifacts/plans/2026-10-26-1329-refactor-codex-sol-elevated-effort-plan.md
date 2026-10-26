---
title: Codex Sol Elevated Effort Profiles - Plan
type: refactor
date: 2026-10-26
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Codex Sol Elevated Effort Profiles - Plan

## Goal Capsule

- **Objective:** Codex workflows resolving `P5` and `P6` responsibilities from the Codex orchestration policy target `gpt-6.1-sol` at escalated effort (`medium` and `high`) instead of `gpt-6-astra` (`low` and `medium`), while keeping non-Codex harnesses and separate startup-default settings unchanged.
- **Means:** Replace `gpt-6-astra` with `gpt-6.1-sol` at escalated effort in `# Codex role orchestration` of `home/h82/agents/instructions/instructions.md.tmpl` and update its repository check and current documentation (KTD1, KTD2).
- **Authority hierarchy:** Product Contract requirements govern behavior; Key Technical Decisions govern mechanism within those requirements; `AGENTS.md` and `docs/verification.md` govern testing and shipping.
- **Stop conditions:** `agent-instructions` or `claude-effort-absent` fails without an in-scope fix, or a change leaks Codex orchestration rules into non-Codex instruction deliveries.
- **Execution profile:** Lightweight instruction template, repository check, and documentation update (`code`).
- **Completion and shipping owner:** `ce-work` implements and verifies locally; `lfg` runs simplification, code review, commit and PR creation, and CI readiness tracking.

## Product Contract

### Summary

Replace `gpt-6-astra` with `gpt-6.1-sol` at escalated reasoning effort (`medium` for `P5`, `high` for `P6`) in the `# Codex role orchestration` section of `home/h82/agents/instructions/instructions.md.tmpl`, update the section's root-ownership prose to match, and align `tests/agent-instructions.py`, `docs/provisioning.md`, and `docs/verification.md`.

### Problem Frame

The `# Codex role orchestration` section of `home/h82/agents/instructions/instructions.md.tmpl` currently assigns `P5` (`Root orchestration, delegation, progress`) to `gpt-6-astra` at `low` effort and `P6` (`Complex planning, architecture alternatives, high-risk decisions, conflicting evidence`) to `gpt-6-astra` at `medium` effort. `gpt-6.1-sol` with elevated effort (`medium` in place of Astra `low`, and `high` in place of Astra `medium`) performs better than `gpt-6-astra` for those responsibilities.

### Requirements

- R1. In `# Codex role orchestration` of `home/h82/agents/instructions/instructions.md.tmpl`, profile `P5` (`Root orchestration, delegation, progress`) uses model `gpt-6.1-sol` at `medium` effort with `Standard` service, and profile `P6` (`Complex planning, architecture alternatives, high-risk decisions, conflicting evidence`) uses model `gpt-6.1-sol` at `high` effort with `Standard` service.
- R2. Every other profile row (`P1` through `P4` and `P7`), the `CE coverage` workflow table, `Dispatch and compatibility`, `CE transport, artifacts and lifecycle`, and the common personal-policy deliveries for Claude Code and OMP remain unchanged, while the root-ownership sentence in `Profiles and responsibility resolution` names `Sol P5/P6` instead of `Astra P5/P6` so the section holds no stale `gpt-6-astra` or `Astra` assignment.
- R3. `tests/agent-instructions.py` enforces the updated `P5` and `P6` `gpt-6.1-sol` model and effort values and the updated `Codex role orchestration` normative text across materialized instruction deliveries, and current Codex role guidance in `docs/provisioning.md` and `docs/verification.md` matches the updated role profiles.

### Scope Boundaries

- Leave new-session startup selections in `home/h82/agents/codex.nix`, `home/h82/t3code.nix`, and `home/h82/agents/omp.nix` (and their settings checks) untouched because this change targets only the `# Codex role orchestration` section of `home/h82/agents/instructions/instructions.md.tmpl`.
- Leave historical plans under `.compound-engineering/artifacts/plans/` and dated execution records in `docs/verification.md` unchanged as point-in-time records.
- Considered and not built: adding a separate repository check derivation to forbid `gpt-6-astra` in `instructions.md.tmpl`, because `tests/agent-instructions.py` already checks both `PROFILES` and the exact `CODEX_CONTRACT` text against materialized deliveries; revisit only if `CODEX_CONTRACT` stops pinning the full section.

#### Deferred to Follow-Up Work

- Updating new-session startup defaults in `home/h82/agents/codex.nix`, `home/h82/t3code.nix`, and `home/h82/agents/omp.nix` if default root sessions should also launch on `gpt-6.1-sol` `medium` instead of `gpt-6-astra` `low`.

## Planning Contract

### Key Technical Decisions

- KTD1. **Update `P5`, `P6`, and the adjacent root-ownership sentence in place inside `{{ if .codex }}`.** Keeping the edit inside the existing conditional block of `home/h82/agents/instructions/instructions.md.tmpl` updates `~/.codex/AGENTS.md` while keeping `~/.claude/CLAUDE.md` and `~/.omp/agent/AGENTS.md` byte-identical, and changing `Astra P5/P6` to `Sol P5/P6` prevents an internal contradiction between the table and prose under R1 and R2.
- KTD2. **Guard model, effort, and root-ownership mutations in `tests/agent-instructions.py`.** Updating `PROFILES` and `CODEX_CONTRACT` in `tests/agent-instructions.py` aligns the `agent-instructions` check with R1 through R3, pinning the `Sol P5/P6` sentence in `CODEX_SENTENCES` guards against deletion or negation, and adding a per-profile model-column negative control in `self_test` ensures reverting a profile model to `gpt-6-astra` triggers `incorrect Codex profile <P>` directly alongside `CODEX_CONTRACT`.

### Assumptions

- Updating `Astra P5/P6` to `Sol P5/P6` in `Profiles and responsibility resolution`, updating the current prose summary under `### Codex role policy and T3 peer transport` in `docs/provisioning.md` to distinguish the `P5`/`P6` orchestration profiles from the unchanged `gpt-6-astra` `low` new-session startup defaults, and updating the T3 responsibility-dispatch checklist line in `docs/verification.md` keep the Codex orchestration section and repository documentation internally consistent, while `This authorization does not extend to root, Sol or external peers.` remains accurate unchanged.
- Startup model defaults in `home/h82/agents/codex.nix`, `home/h82/t3code.nix`, and `home/h82/agents/omp.nix` remain outside scope unless separately requested, so default terminal and T3 sessions continue starting on their declared startup selection until overridden or separately migrated.

## Implementation Units

### U1. Replace Astra with elevated-effort Sol in Codex role orchestration and align checks and docs

- **Goal:** Switch `P5` and `P6` in `# Codex role orchestration` from `gpt-6-astra` (`low` and `medium`) to `gpt-6.1-sol` (`medium` and `high`), update the section's root-ownership prose, and synchronize `tests/agent-instructions.py`, `docs/provisioning.md`, and `docs/verification.md`.
- **Requirements:** R1, R2, R3
- **Dependencies:** None
- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`, `tests/agent-instructions.py`, `docs/provisioning.md`, `docs/verification.md`
- **Approach:**
  1. Update rows `P5` and `P6` and replace `Astra P5/P6` with `Sol P5/P6` in `home/h82/agents/instructions/instructions.md.tmpl` per KTD1.
  2. Update `PROFILES["P5"]`, `PROFILES["P6"]`, and `CODEX_CONTRACT` in `tests/agent-instructions.py`, add `"Root-owned work stays Sol P5/P6; delegated authoring assignments do not move that work out of the root."` to `CODEX_SENTENCES`, and add a model-column negative control in `self_test` per KTD2.
  3. Update the current role summary under `### Codex role policy and T3 peer transport` in `docs/provisioning.md` to state that the orchestration profile table assigns `Sol medium` (`Standard`) to `P5` root orchestration and `Sol high` (`Standard`) to `P6` difficult planning or conflicting evidence while new-session startup defaults in `codex.nix` and `t3code.nix` stay configured separately, and update the T3 responsibility-dispatch checklist item in `docs/verification.md` to name `Luna low` and `Sol low/medium/high`, leaving startup-default documentation and historical dated records untouched.
- **Execution note:** Load `test-audit` before editing `tests/agent-instructions.py`, and confirm assertion liveness with an isolated scratch-copy mutation round (`rsync -a --exclude .git` plus `git -C <copy> init -q`, keeping cwd in the main checkout per `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`) that reverts `home/h82/agents/instructions/instructions.md.tmpl` to `gpt-6-astra` and verifies `agent-instructions` fails inside `tests/agent-instructions.py`.
- **Patterns to follow:** `PROFILES`, `CODEX_SENTENCES`, `CODEX_CONTRACT`, and `self_test` in `tests/agent-instructions.py`; the Codex role policy prose in `docs/provisioning.md`.
- **Test scenarios:**
  - Materialized `~/.codex/AGENTS.md` across every NixOS, non-NixOS Linux, and fixture user environment carries `P5` as `gpt-6.1-sol` / `medium` / `Standard`, `P6` as `gpt-6.1-sol` / `high` / `Standard`, and `Root-owned work stays Sol P5/P6; delegated authoring assignments do not move that work out of the root.`.
  - Materialized `~/.claude/CLAUDE.md` and `~/.omp/agent/AGENTS.md` remain byte-identical to the common personal-policy rendering without Codex orchestration content, and `claude-effort-absent` passes on all delivered instruction files.
  - Mutating a GPT profile row's model (such as `gpt-6-astra`), effort, or service tier in `self_test` reports `incorrect Codex profile <P>`, removing, negating, or duplicating the `Sol P5/P6` root-ownership sentence reports a Codex policy error, and an isolated scratch-copy mutation reverting `home/h82/agents/instructions/instructions.md.tmpl` to `gpt-6-astra` fails the `agent-instructions` check build.
- **Verification:** The `agent-instructions` and `claude-effort-absent` repository checks pass on `x86_64-linux`, an isolated scratch-copy mutation reverting `instructions.md.tmpl` turns `agent-instructions` red for the profile and contract assertions, and changed Markdown files pass linting.

## Verification Contract

| Check | Command | Unit | Done signal |
| --- | --- | --- | --- |
| Materialized agent instructions | `nix build --no-link .#checks.x86_64-linux.agent-instructions` | U1 | Exits 0; `tests/agent-instructions.py` self-tests and all host/fixture deliveries pass |
| Claude effort boundary | `nix build --no-link .#checks.x86_64-linux.claude-effort-absent` | U1 | Exits 0; no blanket Claude effort instruction appears in any delivered file |
| Check liveness (mutation round) | Isolated scratch-copy build of `path:<copy>#checks.x86_64-linux.agent-instructions` with `P5`/`P6` reverted to `gpt-6-astra` in `home/h82/agents/instructions/instructions.md.tmpl` | U1 | Fails inside `tests/agent-instructions.py` with `incorrect Codex profile P5`, `incorrect Codex profile P6`, and `unapproved Codex normative section` |
| Flake evaluation | `nix flake check --no-build` | U1 | Exits 0 across all declared outputs |
| Formatting, whitespace & Markdown | `git diff --check && nix fmt -- --ci && mise exec -- markdownlint-cli2 <changed-md>` | U1 | Exits 0 with no whitespace, Nix formatting, or Markdown lint errors |

## Definition of Done

- `home/h82/agents/instructions/instructions.md.tmpl` uses `gpt-6.1-sol` at `medium` effort for `P5` and `high` effort for `P6`, names `Sol P5/P6` in the root-ownership bullet, and leaves all other profiles and non-Codex deliveries unchanged.
- `tests/agent-instructions.py` guards the updated `P5` and `P6` model and effort values and the `Sol P5/P6` root-ownership sentence, proven live by `self_test` negative controls and an isolated scratch-copy mutation round.
- `docs/provisioning.md` and `docs/verification.md` reflect the updated Codex role orchestration profiles without altering startup-default or historical execution records.
- Local `nix fmt -- --ci`, `git diff --check`, Markdown lint, `nix flake check --no-build`, `agent-instructions`, and `claude-effort-absent` pass on `x86_64-linux`, with unavailable Darwin and ARM native builds recorded as pending CI evidence per `docs/verification.md`.
- Temporary scratch copies and any experimental dead-end edits are removed before commit.
