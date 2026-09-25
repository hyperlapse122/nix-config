---
title: git-trim Merged Branch Cleanup - Plan
type: feat
date: 2026-09-25
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# git-trim Merged Branch Cleanup - Plan

## Goal Capsule

- **Objective:** On every host, user `h82` can run `git trim` in a repository to delete local tracking branches whose upstream work is merged, without the command touching any branch on the remote.
- **Means:** install `pkgs.git-trim` through Home Manager and pin its delete range to local branches in the declarative Git config (KTD1, KTD2).
- **Authority:** issue #70, then this plan's R-IDs, then KTDs. `AGENTS.md` repository rules bind all of them.
- **Stop conditions:** stop if `pkgs.git-trim` is missing from the pinned nixpkgs, or if `merged-local` is not an accepted `trim.delete` value in the packaged version.
- **Execution profile:** one small change in `home/h82/dev/git.nix`, one new Nix check, and registration in `flake.nix`.
- **Finish and ship:** `ce-work` implements and verifies locally; the calling LFG pipeline reviews, commits, and opens the PR.

---

## Product Contract

### Summary

Add `git-trim` 0.4.4 from nixpkgs to the `h82` Home Manager profile so `git trim` works on all four hosts. Configure `trim.delete = merged-local` in `programs.git.settings` so the command only deletes local branches. A new flake check drives the packaged binary against a fixture repository using the Git config the hosts render.

### Problem Frame

The legacy dotfiles installed `git-trim` through mise (`cargo:git-trim`) and also carried a custom `git-prune-local-branches` script. This flake manages neither, so after migration there is no branch-cleanup command. The legacy script guaranteed "never remote mutation". Upstream `git-trim` defaults to `merged:origin`, which expands to `merged-local,merged-remote:origin` and deletes merged branches on `origin`. Installing the package unconfigured would drop that guarantee.

### Requirements

**Availability**

- R1. `git trim` resolves to the packaged `git-trim` for user `h82` on `ThinkPad-X1-Carbon-Gen-11`, `ThinkPad-X1-Carbon-Gen-11-bootstrap`, `MS-7D91`, and `MS-7D91-bootstrap`.

**Deletion scope**

- R2. With no command-line `--delete` flag, `git trim` deletes merged local tracking branches and never deletes, pushes, or rewrites a branch on any remote.
- R3. `git trim` keeps its upstream interactive confirmation before deleting; the declarative config does not set `trim.confirm = false`.

**Verification**

- R4. A flake check fails if the package leaves the user profile, if the rendered Git config stops restricting deletion to local branches, or if running the packaged binary under that config deletes a remote branch.

### Scope Boundaries

- The legacy `git-prune-local-branches` script is not ported. Its GitHub-proof deletion model is replaced by `git-trim`'s own merge detection, as issue #70 asks.
- No shell alias or wrapper is added; `git-trim` on `PATH` already provides the `git trim` subcommand.
- `trim.bases` and `trim.protected` stay at upstream defaults. The default base follows `refs/remotes/*/HEAD`, which matches the legacy script's default-branch behavior.

### Sources

- Issue: [hyperlapse122/nix-config#70](https://github.com/hyperlapse122/nix-config/issues/70)
- Legacy script: `hyperlapse122/dotfiles` `home/dot_local/share/chezmoi-command-sources/executable_git-prune-local-branches` (header: "Never `-D`, `update-ref`, remote mutation, worktree mutation, or stash change").
- `git-trim --help` for 0.4.4: `--delete` default `merged:origin`; `merged` implies `merged-local,merged-remote`; config key `trim.delete`.

---

## Planning Contract

### Key Technical Decisions

- KTD1. Install the package in `home/h82/dev/git.nix` with a module-local `home.packages = [ pkgs.git-trim ];`. The module already owns Git behavior, and Home Manager merges list definitions with the top-level `home.packages` in `home/h82/default.nix`. Governs R1.
- KTD2. Set `programs.git.settings.trim.delete = "merged-local";`. This keeps the legacy local-only guarantee while leaving the per-invocation `--delete` flag available when remote cleanup is wanted deliberately. Chosen over the upstream default `merged:origin`, which deletes merged branches on `origin`. Governs R2.
- KTD3. The check runs the packaged binary against a fixture instead of only matching config text. It installs the host's rendered `git/config` at `$HOME/.config/git/config` inside a sandbox `HOME`, exports `XDG_CONFIG_HOME=$HOME/.config`, and runs the `git-trim` found in that host's `home.path`, per `.compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md`. `GIT_CONFIG_GLOBAL` is not an option: git-trim reads `trim.*` through a vendored libgit2 (1.5.1) that only finds global config at `~/.gitconfig` and `$XDG_CONFIG_HOME/git/config`, so it would silently fall back to `merged:origin`. The check never passes `--delete` on the command line, since that would bypass the config under test. Governs R4.

### Assumptions

- `git-trim` 0.4.4 detects both merge-commit and squash-merged branches; the fixture uses a merge commit because that path is unambiguous.
- The fixture's bare origin needs an explicit `HEAD` and default branch, per `.compound-engineering/artifacts/solutions/best-practices/unset-defaultbranch-leaves-bare-repo-head-dangling-for-second-clone.md`. The rendered config sets `init.defaultBranch = main`, which covers the clone once the rendered file is installed under the sandbox `XDG_CONFIG_HOME` before `git init --bare`.
- The rendered config enables `commit.gpgSign` via `signByDefault`. Fixture commits disable signing with `-c commit.gpgsign=false` so the sandbox needs no key.

---

## Implementation Units

### U1. Install git-trim and restrict its delete range

- **Goal:** make `git trim` available to `h82` with local-only deletion.
- **Requirements:** R1, R2, R3; KTD1, KTD2.
- **Files:** `home/h82/dev/git.nix`.
- **Approach:** take `pkgs` (already in the argument set), add `home.packages = [ pkgs.git-trim ];`, and add `trim.delete = "merged-local";` inside `programs.git.settings`. Do not set `trim.confirm`.
- **Test scenarios:** covered by U2.
- **Verification:** `nix fmt -- --ci` passes, and the rendered `git/config` contains a `[trim]` section with `delete = "merged-local"`.

### U2. Add the git-trim flake check

- **Goal:** guard R1, R2, and R4 on the materialized profile and config.
- **Requirements:** R4; KTD3.
- **Files:** `tests/git-trim.nix` (new), `flake.nix` (register `git-trim = import ./tests/git-trim.nix { inherit pkgs self; };` beside the other `import ./tests/*.nix` checks).
- **Approach:** follow the `tests/gemini.nix` shape: a header comment stating the check interface and what it asserts, an `assertHost` function per host, `or` fallbacks on every attribute lookup so a removed declaration reaches the builder as a failing shell assertion instead of an evaluation error, and a builder that collects failures before exiting. Run it for `ThinkPad-X1-Carbon-Gen-11` and `MS-7D91` production hosts; both share `home/h82`, so bootstrap variants add no coverage. Per host, locate `bin/git-trim` in `home-manager.users.h82.home.path` and the rendered config at `home-manager.users.h82.xdg.configFile."git/config".source`, and install that config as KTD3 describes.
- **Test scenarios:**
  - Happy path: in a sandbox `HOME`, create a bare `origin` and a clone. Push `main`, then push branch `feature` and merge it into `main` with a merge commit, pushed to `origin`. Run `git trim --no-confirm` with the rendered config installed per KTD3. Expect local `feature` deleted and `refs/heads/feature` still present in the bare origin.
  - Local-only guard: the same run must leave the origin's branch list unchanged; this is the assertion that fails if `trim.delete` is removed, because the upstream default then deletes `feature` on origin.
  - Unmerged branch: a local tracking branch `wip` with an unmerged commit pushed to origin survives the run both locally and on origin.
  - Package presence: the check fails with a named message when `home.path` has no `bin/git-trim`.
- **Execution note:** mutation-test the check before trusting it, per `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`. Remove `trim.delete`, then remove the package, and confirm each mutation turns the check red with a specific message. Revert both mutations.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.git-trim` passes on the real config and fails under each mutation.

---

## Verification Contract

- `nix fmt -- --ci`
- `nix build --no-link .#checks.x86_64-linux.git-trim`
- `nix flake check`
- `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel`
- `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel`
- `nix build --no-link .#nixosConfigurations.MS-7D91.config.system.build.toplevel`
- `nix build --no-link .#nixosConfigurations.MS-7D91-bootstrap.config.system.build.toplevel`
- Report that no hardware verification was run; activation on a real host is outside this change's evidence.

## Definition of Done

- U1 and U2 are implemented, and every command in the Verification Contract passes.
- Both mutations in U2's execution note were observed failing the check, then reverted.
- The diff contains no mutation leftovers, scratch fixtures, or unused code.
