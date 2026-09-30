---
title: pkill and lsof Process Tools - Plan
type: feat
date: 2026-09-30
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# pkill and lsof Process Tools - Plan

## Goal Capsule

- **Objective:** On every host, user `h82` and the scripts and agents running as `h82` can find and stop processes and see which process holds a file or port, with `pkill`, `pgrep`, and `lsof` on PATH regardless of what NixOS ships by default.
- **Means:** add `lsof` and `procps` to the shell-utilities package list (KTD1), and prove them in the existing check (KTD2).
- **Authority:** this plan, then `AGENTS.md`, then existing patterns in `home/h82/shell/utilities.nix` and `tests/shell-utilities.nix`. Issue of record: [#134](https://github.com/hyperlapse122/nix-config/issues/134).
- **Stop conditions:** stop if adding `procps` or `lsof` causes a `home.path` collision that breaks any `nixosConfigurations` build, or if `pkgs.procps` no longer ships `bin/pkill`.
- **Execution profile:** one list edit plus assertions in an existing check; `ce-work` finishes it and the LFG pipeline ships it.

## Product Contract

### Summary

Add `lsof` and `procps` to `home/h82/shell/utilities.nix` so `lsof`, `pkill`, and `pgrep` are declared on `h82`'s PATH, and extend `tests/shell-utilities.nix` so removing either package fails the check.

### Problem Frame

`lsof` is not installed, so scripts and agents cannot see which process holds a port or file. `pkill` works today only because NixOS puts `procps` in its default system packages; this repository never declares it, so a change to those defaults would remove it silently.

### Requirements

- R1. `lsof`, `pkill`, and `pgrep` are on user `h82`'s PATH on every configuration, bootstrap outputs included.
- R2. Removing `lsof` or `procps` from the Home Manager profile fails `nix flake check`.

### Scope Boundaries

- No system-wide package change; the NixOS default `procps` stays as it is.
- No shell aliases or wrappers around these tools.

## Planning Contract

### Key Technical Decisions

- KTD1. **List both packages in `home/h82/shell/utilities.nix`.** The issue names that module, it already holds plain commands with no shell integration, and its check already runs every configuration, bootstrap included.
- KTD2. **Assert by running each tool against state the check creates.** The check's header states that an existence test passes for a binary that does not work, so each new assertion runs the tool from `home.path` and compares its output: `pgrep` finds and `pkill` stops a background process the check started, and `lsof` reports a file the check holds open.

### Assumptions

- Bootstrap outputs getting both packages is acceptable, because the shell-utilities check already requires every utility there.
- The home-level `procps` shadowing the system copy on PATH is harmless, since both come from the same nixpkgs.

### Risks

- `procps` also installs `kill`, `ps`, `top`, `uptime`, `watch`, and `free`. If another `home.packages` entry ships one of those names, `home.path` may fail with a collision. Every `nixosConfigurations` build surfaces it; resolve by priority only if it happens.

## Implementation Units

### U1. Add lsof and procps with check assertions

- **Goal:** R1 and R2 via KTD1 and KTD2.
- **Requirements:** R1, R2.
- **Dependencies:** none.
- **Files:** `home/h82/shell/utilities.nix`, `tests/shell-utilities.nix`.
- **Approach:**
  1. Add `lsof` and `procps` to the `home.packages` list in alphabetical order.
  2. In `tests/shell-utilities.nix`, start a uniquely identifiable background process and record its PID from `$!`, then add `expect` lines for `pgrep` (prints that PID) and `pkill` (exits 0 on it). Afterwards `wait` on the PID and fail unless its status is 143 (terminated by SIGTERM); do not probe with `kill -0` or `pgrep`, because the unreaped child stays visible as a zombie. When `pkill` is missing, kill and wait on the PID directly so the process never outlives the subshell.
  3. Add an `expect` line for `lsof` that lists an open descriptor the check holds on `haystack` and expects the file path.
  4. Keep the header comment accurate if its description of the tool set no longer holds.
- **Execution note:** mostly packaging; prove it with the check and a mutation, not new test infrastructure.
- **Patterns to follow:** the `sponge` assertion plus its follow-up file check, and the per-tool `expect` helper in `tests/shell-utilities.nix`.
- **Test scenarios:**
  - `pgrep` run from `$homePath/bin` against the check's background process prints that process's PID.
  - `pkill` run from `$homePath/bin` against the same process exits 0, and `wait` on that PID then returns 143.
  - `lsof` run from `$homePath/bin` against a descriptor the check holds on `haystack` reports `haystack`'s path.
  - Mutation: with `procps` removed from `home/h82/shell/utilities.nix`, the check fails naming `pgrep` and `pkill` on every configuration.
  - Mutation: with `lsof` removed, the check fails naming `lsof` on every configuration.
- **Verification:** the `shell-utilities` check passes and fails under each mutation (run in a scratch copy per `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`).

### Deferred to implementation

- The exact `pgrep`/`pkill` match flags and `lsof` output-field flags that stay stable inside the Nix build sandbox; pick them after seeing the tools run there.

## Verification Contract

| Gate | Command |
| --- | --- |
| Formatting | `nix fmt -- --ci` |
| Changed check | `nix build .#checks.x86_64-linux.shell-utilities` |
| All checks | `nix flake check` |
| Every output | build each `nixosConfigurations.<name>.config.system.build.toplevel` per `AGENTS.md` |

## Definition of Done

- U1 is on one branch and every gate above passes.
- The check was seen to fail with `procps` removed and with `lsof` removed.
- No abandoned experiment code remains in the diff.
