---
title: Git LFS Beside Git - Plan
type: feat
date: 2026-09-28
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Git LFS Beside Git - Plan

## Goal Capsule

- **Objective:** On every host, user `h82` can clone, check out, and commit Git LFS repositories and get real file content, not LFS pointer text, with no manual `git lfs install`.
- **Means:** enable Home Manager's `programs.git.lfs` next to the existing `programs.git` configuration (KTD1).
- **Authority:** this plan, then `AGENTS.md`, then existing patterns in `home/h82/dev/git.nix` and `tests/git-trim.nix`.
- **Stop conditions:** stop if Home Manager's `programs.git.lfs` no longer renders `filter.lfs` into `git/config`, or if enabling it breaks any `nixosConfigurations` build.
- **Execution profile:** one small Nix change plus one regression check; `ce-work` finishes it and the LFG pipeline ships it.

---

## Product Contract

### Summary

Add Git LFS to the user's Git setup. `home/h82/dev/git.nix` turns on `programs.git.lfs`, which puts `git-lfs` on the user's PATH and writes the `filter.lfs` clean, smudge, and process entries into the Home Manager git config. A new check proves the rendered config actually runs the LFS clean filter.

### Problem Frame

Git is installed and configured, but Git LFS is not. Cloning a repository that stores assets in LFS leaves pointer files in the working tree, and `git lfs` commands fail. Running `git lfs install` by hand would write filter config into a mutable `~/.gitconfig` outside the declarative profile.

### Requirements

- R1. `git-lfs` is on user `h82`'s PATH on every configuration, bootstrap outputs included.
- R2. The Home Manager git config registers the LFS filter, so a path tracked in `.gitattributes` with `filter=lfs` is stored as an LFS pointer on commit and restored as content on checkout.
- R3. No mutable git config file (`~/.gitconfig`) is needed for R2.

### Scope Boundaries

- The system-wide `git` in `modules/nixos/system/base.nix` stays unchanged; root and other users get no LFS filter config.
- `skipSmudge` stays at its default (`false`), so clones download LFS objects.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Use Home Manager `programs.git.lfs.enable = true` in `home/h82/dev/git.nix`.** It installs the package and renders `filter.lfs.{clean,smudge,process,required}` with absolute store paths in the same `git/config` the rest of the git settings live in. Adding `pkgs.git-lfs` only to `environment.systemPackages` beside `git` would leave the filter unregistered until someone runs `git lfs install`, which writes mutable state and misses R3.
- KTD2. **Prove the filter behaviourally, not by reading config text.** The check commits a tracked file with the rendered config installed at `$XDG_CONFIG_HOME/git/config` and asserts the stored blob is an LFS pointer and the checkout restores the content. Reading the option value would pass for a config that never reaches the rendered file (see `.compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md`).

### Assumptions

- "Beside `git`" means next to the user's existing git configuration, where the filter must be registered to be useful; a bare system package was considered and rejected per KTD1.

---

## Implementation Units

### U1. Enable Git LFS in the Home Manager git module

- **Goal:** R1, R2, R3 via KTD1.
- **Requirements:** R1, R2, R3.
- **Dependencies:** none.
- **Files:** `home/h82/dev/git.nix`.
- **Approach:** add `lfs.enable = true;` inside the existing `programs.git` attribute set. Leave `package` and `skipSmudge` at their defaults.
- **Test scenarios:** covered by U2.
- **Verification:** U2's check passes; every `nixosConfigurations` output builds.

### U2. Add the `git-lfs` regression check

- **Goal:** prove R1, R2, and R3 on every configuration, per KTD2.
- **Requirements:** R1, R2, R3.
- **Dependencies:** U1.
- **Files:** `tests/git-lfs.nix` (new), `flake.nix` (register as `checks.<system>.git-lfs` beside `git-trim`).
- **Approach:** follow `tests/git-trim.nix`: iterate `tests/lib/configurations.nix` entries, run `configurations.guard` first, read `entry.user.home.path` and `entry.user.xdg.configFile."git/config".source` with `or ""` fallbacks, run each host in a subshell that appends to a failures file, and fail at the end if the file is non-empty. Install the rendered config at `$XDG_CONFIG_HOME/git/config` under a sandboxed `HOME`, disable commit signing via `GIT_CONFIG_COUNT`, and put `$homePath/bin` on PATH. Unlike `tests/git-trim.nix`, a missing `git-lfs` binary records a failure without exiting the host subshell, so the commit and checkout fixture still runs and each mutation below can reach its own assertion. Read the mutation-testing solutions listed in `AGENTS.md` before writing assertions.
- **Test scenarios:**
  - `$homePath/bin/git-lfs` exists and is executable; otherwise the host fails with "git-lfs is not in home.path".
  - In a fresh repo, `.gitattributes` has `*.bin filter=lfs diff=lfs merge=lfs -text`; committing `data.bin` with known content stores a blob whose content starts with `version https://git-lfs.github.com/spec/v1` and carries the content's `oid sha256:`.
  - After deleting `data.bin` and running `git checkout -- data.bin`, the working-tree file equals the original content, not pointer text. This also guards the `skipSmudge = false` default, since a `--skip` smudge would restore pointer text.
  - Mutation 1: with `lfs.enable` removed, the check fails on the missing binary and on the stored blob being raw content.
  - Mutation 2: with `lfs.skipSmudge = true`, the check fails on the checkout restoring pointer text.
- **Verification:** `nix build .#checks.x86_64-linux.git-lfs` passes, and fails under each of the two mutations (run in a scratch copy per `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`).

---

## Verification Contract

| Gate | Command |
| --- | --- |
| Formatting | `nix fmt -- --ci` |
| New check | `nix build .#checks.x86_64-linux.git-lfs` |
| All checks | `nix flake check` |
| Every output | build each `nixosConfigurations.<name>.config.system.build.toplevel` per `AGENTS.md` |

---

## Definition of Done

- U1 and U2 are merged into one branch, and every gate above passes.
- The U2 check was seen to fail under both U2 mutations.
- No abandoned experiment code remains in the diff.
