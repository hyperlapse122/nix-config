---
title: ghq repository layout - Plan
type: feat
date: 2026-09-25
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# ghq repository layout - Plan

## Goal Capsule

- **Objective:** On both machines, `ghq get <url>` clones every repository into one predictable tree, `~/src/<host>/<owner>/<repo>`, and `ghq list` finds them.
- **Means:** Install `pkgs.ghq` through Home Manager and set `ghq.root` in the declared Git config (KTD1, KTD2). Guard the behavior with a flake check that runs the packaged binary (KTD3).
- **Authority:** The user's request to integrate [ghq](https://github.com/x-motemen/ghq), then this plan's R-IDs, then KTDs.
- **Execution profile:** Lightweight. Two units.
- **Stop conditions:** Stop if `ghq.root` conflicts with an existing Git setting, or if any host build fails.

## Product Contract

### Requirements

- R1. `ghq` is on `h82`'s PATH on every host configuration, with its zsh completion.
- R2. ghq's root is `~/src`, not its `~/ghq` default, so `ghq get` and `ghq create` place repositories at `~/src/<host>/<owner>/<repo>`.
- R3. A flake check fails when ghq leaves `home.path`, or when the rendered Git config no longer makes ghq resolve its root to `~/src`.

### Scope Boundaries

- No migration of repositories already cloned elsewhere. Moving them is a manual step.
- No fuzzy-finder `cd` helper. The flake does not configure fzf or peco.
- ghq uses the Git credential helpers already declared in `home/h82/dev/git.nix`. No new authentication.

### Sources

- ghq reads `ghq.root` with `git config --path --get-all ghq.root`, so `~` expands and the setting belongs in Git config. `GHQ_ROOT` overrides it. Neither host sets that variable.
- `pkgs.ghq` 1.10.1 ships `share/zsh/site-functions/_ghq`, which `programs.zsh.enableCompletion` picks up from `home.path`.

## Planning Contract

### Key Technical Decisions

- KTD1. **A focused `home/h82/dev/ghq.nix` module, imported from `home/h82/dev/default.nix`.** It carries both the package and its one Git setting, so removing the module removes ghq completely. `programs.git.settings` merges with `git.nix`.
- KTD2. **`~/src` as root.** It is short, and it keeps `~/src/github.com/hyperlapse122/nix-config` separate from the home directory's dotfiles and XDG directories.
- KTD3. **Run the binary, do not match config text.** Install the rendered `git/config` at `$XDG_CONFIG_HOME/git/config` under a sandboxed `HOME`, as in `tests/git-trim.nix`. Then assert on `ghq root`, `ghq create`, and `ghq list --full-path`. Every lookup has an `or` fallback, so a removed declaration fails in the builder, per `.compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md`.

## Implementation Units

### U1. Install ghq and set its root

- **Files:** `home/h82/dev/ghq.nix` (new), `home/h82/dev/default.nix`.
- **Requirements:** R1, R2. KTD1, KTD2.

### U2. Add the ghq flake check

- **Files:** `tests/ghq.nix` (new), `flake.nix`.
- **Requirements:** R3. KTD3.
- **Test scenarios:**
  - Happy path: both production hosts resolve `ghq root` to `$HOME/src`, and `ghq create github.com/example/project` initializes `$HOME/src/github.com/example/project`.
  - Error path: setting `ghq.root = "~/ghq"` fails the check.
  - Error path: deleting `ghq.root` fails the check, since ghq falls back to `~/ghq`.
  - Error path: deleting `pkgs.ghq` from `home.packages` fails with "ghq is not in home.path".

## Verification Contract

| Gate | Command |
| --- | --- |
| Formatting | `nix fmt -- --ci` |
| New check | `nix build --no-link .#checks.x86_64-linux.ghq` |
| All checks | `nix flake check` |
| Host builds | `nix build --no-link .#nixosConfigurations.<host>.config.system.build.toplevel` for all four hosts |

After a user-run rebuild, `ghq root` printing `/home/h82/src` confirms the change on hardware. Report that separately from build evidence.
