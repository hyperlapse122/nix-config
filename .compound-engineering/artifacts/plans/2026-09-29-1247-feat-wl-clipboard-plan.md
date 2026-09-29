---
title: wl-clipboard Command-Line Clipboard - Plan
type: feat
date: 2026-09-29
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# wl-clipboard Command-Line Clipboard - Plan

## Goal Capsule

- **Objective:** On every host, user `h82` can pipe text into and out of the Plasma Wayland clipboard from a shell or script with `wl-copy` and `wl-paste`.
- **Means:** add `wl-clipboard` to the shell-utilities package list (KTD1).
- **Authority:** this plan, then `AGENTS.md`, then existing patterns in `home/h82/shell/utilities.nix` and `tests/shell-utilities.nix`.
- **Stop conditions:** stop if `pkgs.wl-clipboard` no longer ships `bin/wl-copy` and `bin/wl-paste`, or if adding it breaks any `nixosConfigurations` build.
- **Execution profile:** one list entry plus two assertions in an existing check; `ce-work` finishes it and the LFG pipeline ships it.

## Product Contract

### Summary

Add `wl-clipboard` to `home/h82/shell/utilities.nix` so `wl-copy` and `wl-paste` are on the user's PATH, and extend `tests/shell-utilities.nix` so removing the package fails the check.

### Problem Frame

The desktop is Plasma on Wayland, but no command-line clipboard tool is installed. Scripts and terminal pipelines cannot copy output to the clipboard or read it back, and X11 tools such as `xclip` do not reach native Wayland clients.

### Requirements

- R1. `wl-copy` and `wl-paste` are on user `h82`'s PATH on every configuration, bootstrap outputs included.
- R2. Removing `wl-clipboard` from the Home Manager profile fails `nix flake check`.

### Scope Boundaries

- No shell aliases (`pbcopy`/`pbpaste`) or clipboard-manager integration.
- No system-wide package; root and other users do not get it.

## Planning Contract

### Key Technical Decisions

- KTD1. **List `wl-clipboard` in `home/h82/shell/utilities.nix`.** That module already holds plain pipeline commands with no shell integration, and its check already runs every configuration, bootstrap included. A new desktop-domain module would need its own check for one package.
- KTD2. **Assert by running `--version`, not by file existence.** The Nix build sandbox has no Wayland compositor, so a copy/paste round trip cannot run there. `wl-copy --version` and `wl-paste --version` print `wl-clipboard <version>` and exit 0 without connecting to a display, so the check proves each binary executes, matching how the check already treats `wget`.

### Assumptions

- Placing the package with the shell utilities rather than under `home/h82/desktop/` is the right home, since its use is from pipelines (KTD1).
- Bootstrap outputs getting the package is acceptable, because the shell-utilities check already requires every utility there.

## Implementation Units

### U1. Add wl-clipboard and its check assertions

- **Goal:** R1 and R2 via KTD1 and KTD2.
- **Requirements:** R1, R2.
- **Dependencies:** none.
- **Files:** `home/h82/shell/utilities.nix`, `tests/shell-utilities.nix`.
- **Approach:**
  1. Add `wl-clipboard` to the `home.packages` list in alphabetical order.
  2. In `tests/shell-utilities.nix`, add one `expect` line each for `wl-copy` and `wl-paste` that runs `--version` and compares the first line's first word to `wl-clipboard`, in the style of the existing `wget` line.
  3. Update the check's header comment only if its description of the tool set no longer holds.
- **Execution note:** mostly packaging; prove it with the check and a mutation, not new test infrastructure.
- **Patterns to follow:** the `wget` assertion in `tests/shell-utilities.nix`.
- **Test scenarios:**
  - `$homePath/bin/wl-copy --version` prints a first line starting with `wl-clipboard`; otherwise the host fails with "wl-copy is not in home.path" or a mismatch.
  - The same holds for `wl-paste`.
  - Mutation: with `wl-clipboard` removed from `home/h82/shell/utilities.nix`, the check fails naming both `wl-copy` and `wl-paste` on every configuration.
- **Verification:** `nix build .#checks.x86_64-linux.shell-utilities` passes and fails under the mutation (run in a scratch copy per `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`).

## Verification Contract

| Gate | Command |
| --- | --- |
| Formatting | `nix fmt -- --ci` |
| Changed check | `nix build .#checks.x86_64-linux.shell-utilities` |
| All checks | `nix flake check` |
| Every output | build each `nixosConfigurations.<name>.config.system.build.toplevel` per `AGENTS.md` |

## Definition of Done

- U1 is on one branch and every gate above passes.
- The check was seen to fail with `wl-clipboard` removed.
- No abandoned experiment code remains in the diff.
