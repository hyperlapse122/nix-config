---
title: Tokscale counts T3 Code Antigravity sessions - Plan
type: feat
date: 2026-10-06
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Tokscale counts T3 Code Antigravity sessions - Plan

## Goal Capsule

- **Objective:** Antigravity usage from T3 Code threads and delegated tasks appears in `tokscale` reports and submissions alongside the Antigravity CLI usage it already shows.
- **Means:** the `tokscale` wrapper adds each T3 Antigravity conversations directory to `TOKSCALE_EXTRA_DIRS` as an `antigravity-cli` source, the same way it adds Orca's Codex sessions (KTD1).
- **Authority:** this plan, then `AGENTS.md`, then existing wrapper conventions in `scripts/tokscale`.
- **Stop conditions:** stop and report if the wrapper would need a non-builtin command, or if Tokscale stops accepting `antigravity-cli:<dir>` entries.
- **Execution profile:** one unit, shell script plus its shell test and docs.
- **Finish and ship:** the caller (`lfg`) reviews, commits, and opens the PR.

## Product Contract

### Summary

The wrapper globs `~/.t3/userdata/providers/antigravity/*/antigravity-acp/conversations`, plus the standalone ACP default `~/.gemini/antigravity-acp/conversations`, and passes every existing match to Tokscale as `antigravity-cli:<dir>`, after the caller's value and the Orca Codex entries. Tests and docs cover the new source.

### Problem Frame

T3 Code runs Antigravity through its own ACP server with `GEMINI_HOME` set to `~/.t3/userdata/providers/antigravity/<hash>`, so its conversation databases land under that directory instead of `~/.gemini/antigravity-cli/conversations`. Tokscale only scans the default location, so on this machine it reported 16 Antigravity CLI messages ($0.23) while T3 had produced 302 ($7.19 in total). The usage the user pays for through T3 orchestration is invisible.

### Requirements

- R1. When one or more `~/.t3/userdata/providers/antigravity/*/antigravity-acp/conversations` directories exist, the wrapper passes each to Tokscale as an `antigravity-cli:<dir>` entry in `TOKSCALE_EXTRA_DIRS`; the standalone ACP default `~/.gemini/antigravity-acp/conversations` is passed the same way when it exists.
- R2. Existing behavior is kept: a caller-exported `TOKSCALE_EXTRA_DIRS` stays first and unchanged, Orca Codex entries keep their position, a path containing a comma is skipped, and with no matching directory the variable is untouched.
- R3. `docs/provisioning.md` and `README.md` describe the new source.

### Scope Boundaries

- A T3 state directory other than `~/.t3` is not followed; this configuration runs T3 under `~/.t3`.

## Planning Contract

### Key Technical Decisions

- KTD1. **Report T3 Antigravity sessions as the `antigravity-cli` client.** The T3 `.db` files share the exact SQLite schema of `~/.gemini/antigravity-cli/conversations/*.db`, and Tokscale 4.18.0 accepted `TOKSCALE_EXTRA_DIRS=antigravity-cli:<t3 dir>`: `tokscale clients` listed it as "extra (env)" and `tokscale models -c antigravity-cli --json` rose from 16 to 302 messages. No Tokscale client type matches the ACP server more closely.
- KTD2. **Generalize the existing extra-dirs collection rather than duplicate it.** The Orca loop already handles nullglob, the directory test, comma skipping, and joining after the caller value; one collection over both `(client, glob)` pairs keeps a single copy of those rules. Order of entries is caller value, then Orca Codex, then T3 Antigravity, then the standalone ACP default. A manual ACP run outside T3 (as in the CA-bundle debugging) writes to the default, and it holds a conversation on this machine.
- KTD3. **Builtins only.** The wrapper header promises nothing but bun on `PATH`; the test runs it with `PATH` holding only bash and the stub bun, which enforces this.

## Implementation Units

### U1. Add T3 Antigravity directories to the Tokscale wrapper

- **Goal:** Tokscale sees T3's and standalone ACP Antigravity conversations on every wrapper run.
- **Requirements:** R1, R2, R3; KTD1, KTD2, KTD3.
- **Dependencies:** none.
- **Files:**
  - `scripts/tokscale`
  - `tests/tokscale.sh`
  - `docs/provisioning.md`
  - `README.md`
  - `tests/tokscale.nix` (only its comment naming the wrapper behaviors the `tokscale-wrapper` check covers)
- **Approach:**
  1. In `scripts/tokscale`, extend the extra-dirs block to also glob `$HOME/.t3/userdata/providers/antigravity/*/antigravity-acp/conversations` and `$HOME/.gemini/antigravity-acp/conversations` with prefix `antigravity-cli:`, applying the same directory and comma checks; update the header comment.
  2. In `tests/tokscale.sh`, add a T3 section beside the Codex one.
  3. Update the Tokscale bullet list in `docs/provisioning.md` and the wrapper description in `README.md`.
- **Patterns to follow:** the `# --- Codex session directories ---` section of `tests/tokscale.sh`; the existing loop in `scripts/tokscale`.
- **Test scenarios:**
  - With no `~/.t3` tree, `TOKSCALE_EXTRA_DIRS` is unset when the caller set none, and a caller value (including an empty one) passes through unchanged.
  - Two provider hashes with `antigravity-acp/conversations` directories produce two `antigravity-cli:` entries, appended after a caller value `claude:/x`.
  - A provider directory without `conversations`, and one where `conversations` is a regular file, add nothing.
  - A provider path containing a comma is skipped.
  - An existing `~/.gemini/antigravity-acp/conversations` adds one `antigravity-cli:` entry after the T3 entries; when it is absent or a regular file it adds nothing.
  - With Orca Codex sessions and T3 conversations both present, the result is caller value, then the `codex:` entries, then the `antigravity-cli:` entries, with no leading comma when the caller value is empty.
  - Both the source and the `--packaged` runs of `tests/tokscale.sh` pass, since the `tokscale-wrapper` check runs both.
- **Verification:** the `tokscale-wrapper` flake check passes; the real wrapper on this machine lists the T3 directory as "extra (env)" under Antigravity CLI in `tokscale clients`.

## Verification Contract

| Gate | Command | Proves |
|---|---|---|
| Wrapper behavior | `nix build --no-link .#checks.x86_64-linux.tokscale-wrapper` | R1, R2 on source and packaged wrapper |
| Static checks | `nix build --no-link .#checks.x86_64-linux.tokscale` | packaging still evaluates |
| Format | `nix fmt -- --ci` | formatting |
| Full checks | `nix flake check` | nothing else regressed |
| Live smoke | run the patched `scripts/tokscale` (placeholders substituted) with a stub-free bun, `clients` subcommand | the real Tokscale reads the T3 directory |

Host outputs need not be rebuilt beyond what `nix flake check` builds: the change touches only the wrapper script, its test, and docs, all of which the checks above cover.

## Definition of Done

- U1 test scenarios exist in `tests/tokscale.sh` and pass in both modes.
- `nix flake check` and `nix fmt -- --ci` pass.
- Docs name the T3 Antigravity source.
- No abandoned experimental code remains in the diff.
