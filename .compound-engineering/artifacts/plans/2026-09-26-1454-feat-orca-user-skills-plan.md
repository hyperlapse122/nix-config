---
title: "Orca Agent Skills for Every Harness - Plan"
type: feat
date: 2026-09-26
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Orca Agent Skills for Every Harness - Plan

## Goal Capsule

- **Objective:** Every coding agent user `h82` runs on either host (Claude Code, the Antigravity CLI, and any agent that reads the shared `~/.agents/skills` root) discovers Orca's published skills user-wide, at the revision matching the installed Orca build, without a manual `orca skills install`.
- **Means:** Home Manager places each `skills/<name>` directory from the version-pinned `stablyai/orca` source into the three user-level skill roots (KTD1, KTD2, KTD3).
- **Authority Hierarchy:** Product Contract requirements govern intended state; Key Technical Decisions govern mechanism; Implementation Units define execution packets.
- **Execution Profile:** Native execution on a feature branch.
- **Stop Conditions:** An evaluation or build failure on any host, a failing flake check, or failing formatting.
- **Who Finishes and Ships:** The LFG pipeline implements, simplifies, reviews, verifies, commits, and opens a pull request.

---

## Product Contract

### Summary

Install all eight Orca skills (`computer-use`, `linear-tickets`, `orca-cli`, `orca-emulator`, `orca-emulator-android`, `orca-linear`, `orca-per-workspace-env`, `orchestration`) declaratively into the user-wide skill roots of every harness this flake installs, sourced from the Orca release tag matching the packaged Orca version.
Add a flake check that reads the materialized home files and update the docs that currently say skills are left unmanaged.

### Problem Frame

Orca (`packages/orca.nix`, v1.4.206) ships as an unmanaged desktop app, but agents on this machine do not know how to drive it.
Orca publishes discovery-stub skills in its repository's `skills/` directory; each stub tells the agent how to resolve the right executable (never the GNOME screen reader `orca`) and to load the version-matched guide with `orca skills get <name>`.
Orca's own installer (`orca skills install`) shells out to `npx skills add https://github.com/stablyai/orca`, which installs from the repository's default branch rather than the installed version, writes mutable state outside this flake, and must be re-run by hand on every machine.
`docs/provisioning.md` and `README.md` currently state that skills are left as mutable user state.

### Requirements

**Placement**

- R1. Every directory under `skills/` of the pinned Orca source is present as a skill at `~/.claude/skills/<name>` (Claude Code).
- R2. The same set is present at `~/.gemini/config/skills/<name>` (Antigravity CLI global discovery root).
- R3. The same set is present at `~/.agents/skills/<name>` (the shared root Codex, the Gemini CLI, and Orca's `universal` target read).
- R4. The skill set is derived from the source tree, so a skill added or removed upstream follows on the next Orca bump without editing a hand-kept list.

**Version coupling**

- R5. The skill source revision is the `v<version>` tag of the same `version` that `packages/orca.nix` downloads, so the stubs and the installed CLI cannot drift apart.
- R6. Bumping the Orca version without updating the skill source hash fails the build instead of silently reusing the previous version's skills.

**Verification and docs**

- R7. A flake check asserts, on every host in `self.nixosConfigurations`, that each expected skill reaches all three roots in the materialized Home Manager files and that the linked source is the one keyed to the packaged Orca version.
- R8. `README.md` and `docs/provisioning.md` describe the Orca skills as declared and name the three roots.

### Scope Boundaries

- Claude Code's other skills, plugins, and `~/.claude/skills/synced` stay user-owned; this plan adds only the Orca skill directories.
- The repository-level `agents.toml` (dotagents, project scope) is not touched; the request is user-wide.
- Orca's in-app skill sharing, `orca skills install`/`update`, and Orca settings reconciliation (removed deliberately in the earlier Orca config plan) stay out of scope.
- No per-harness exclusion list is built; every harness gets the full set.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Pin the source with `fetchFromGitHub` keyed to `packages/orca.nix`'s `version`, exposed from that package.** The AppImage bundles only `resources/skills/*.json` manifests, not the `SKILL.md` files, so the repository is the only source. A flake input was rejected because its lock is independent of the package version and would drift. Expose the fetched tree from `packages/orca.nix` (for example through `passthru`) so the version literal has one owner.
- KTD2. **Give the fetch a version-bearing `name`.** A fixed-output derivation with a stale hash and the default `source` name can resolve to an already-present store path and silently keep the old content. A name such as `orca-skills-<version>` changes the output path on every bump, so a stale hash fails with a mismatch (R6).
- KTD3. **Place skills with `home.file` directory links, not an activation script.** Each root is a directory other writers also use (Claude Code writes `~/.claude/skills/synced`, the Antigravity CLI owns `~/.gemini/config`), so only the per-skill subdirectories are declared. A store symlink per skill is read-only, which suits discovery stubs, and both Claude Code and Codex document following symlinked skill directories. Home Manager refuses to clobber an existing non-managed path, which surfaces a prior `npx skills add` install as an activation error instead of overwriting it.
- KTD4. **Target three roots from evidence, not a guess.** `orca skills install --all --dry-run` on this host resolves to `--agent antigravity --agent claude-code --agent universal`. The Antigravity CLI's bundled `agy-customizations` skill names `~/.gemini/config/` as the global discovery root with skills under `skills/`, and resolves same-named skills by priority, so a duplicate through another root cannot collide.
- KTD5. **Put the module in `home/h82/agents/orca-skills.nix`, imported from `home/h82/agents/default.nix`.** It is one concern and matches the domain layout in `AGENTS.md`.

### Assumptions

- The legacy `linear-tickets` skill duplicates `orca-linear`; it is included because the request says "all skills" and the set is derived from the tree (R4).
- No Gemini CLI or Codex binary is installed today; `~/.agents/skills` is still populated because Orca itself treats it as the canonical root and any future harness reads it.
- The upstream `skills/<name>/` directories contain only `SKILL.md` today; linking whole directories keeps any future `references/` subtree intact.

### Sources

- `stablyai/orca` tag `v1.4.206`, `skills/*/SKILL.md` and `docs/reference/agent-skill-provider-paths.md`.
- `~/.gemini/antigravity-cli/builtin/skills/agy-customizations/SKILL.md` and `docs/skills.md` (Antigravity discovery order).
- `.compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md`, `mutation-testing-reveals-decorative-nix-check-assertions.md`, `unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md`.

---

## Implementation Units

### U1. Expose the version-pinned Orca skill source and place it in all three roots

- **Goal:** User-wide Orca skills appear in every harness root on both hosts.
- **Requirements:** R1, R2, R3, R4, R5, R6.
- **Dependencies:** none.
- **Files:** `packages/orca.nix`, `home/h82/agents/orca-skills.nix` (new), `home/h82/agents/default.nix`.
- **Approach:**
  1. In `packages/orca.nix`, fetch `stablyai/orca` at `v${version}` with a version-bearing name (KTD1, KTD2) and expose it on the package.
  2. In the new module, read the skill names from the source's `skills/` directory (`builtins.readDir`, directories only) and generate one `home.file` entry per root per skill (KTD3, KTD4).
  3. Obtain the source from the same `packages/orca.nix` import used by `home/h82/default.nix`, so there is one package evaluation path.
- **Patterns to follow:** `home/h82/agents/gemini.nix` for a `home.file` declaration; `home/h82/agents/agent-plugins.nix` for comments that explain non-obvious constraints.
- **Test scenarios:** covered by U2's check.
- **Verification:** All four host toplevels build, and the Home Manager files derivation contains `.claude/skills/orca-cli/SKILL.md`, `.gemini/config/skills/orca-cli/SKILL.md`, and `.agents/skills/orca-cli/SKILL.md`.

### U2. Add an `orca-skills` flake check over the materialized home files

- **Goal:** A regression that drops a root, a skill, or the version coupling turns a check red.
- **Requirements:** R7.
- **Dependencies:** U1.
- **Files:** `tests/orca-skills.nix` (new), `flake.nix`.
- **Approach:** For each host in `self.nixosConfigurations`, read `home-manager.users.h82.home-files` (the materialized output, not the option value) and assert:
  1. Every expected skill's `SKILL.md` exists under each root, is non-empty, and carries a `name:` frontmatter field matching its directory.
  2. The source those links resolve into has a root `package.json` whose `version` equals the `version` of the `orca-ide` package in `home.packages`. This checks the fetched content, not the store name, which KTD2 derives from the same `version` and so cannot disagree with it.
  Derive the expected names independently of the module (for example from the pinned source's `skills/` listing plus a hard-coded minimum such as `orca-cli` and `orchestration`) so the check does not compare the module with itself. Guard every lookup with `or` fallbacks and `lib.optionalString`, and collect all failures before exiting.
- **Patterns to follow:** `tests/agent-plugins.nix` (host iteration, failure collection, guarded lookups) and its header comment style.
- **Test scenarios:**
  - Happy path: all eight skills exist under all three roots on every host, and the check passes.
  - Missing root: removing the `.gemini/config/skills` placement makes the check fail naming that root and host.
  - Missing skill: filtering out `orchestration` makes the check fail naming it.
  - Version drift: pointing the fetch `rev` and hash at another release tag while keeping the version-bearing name makes the check fail on the `package.json` version.
  - Hollow source: a `SKILL.md` that is empty or lacks `name:` frontmatter fails.
- **Execution note:** Mutation-test each assertion once (break the module, confirm red, restore) per the linked solutions.
- **Verification:** `nix build .#checks.x86_64-linux.orca-skills` passes, and each mutation above turns it red.

### U3. Update the docs

- **Goal:** The docs state which skills are declared and where they land.
- **Requirements:** R8.
- **Dependencies:** U1.
- **Files:** `README.md`, `docs/provisioning.md`.
- **Approach:** Replace the claims that skills are wholly unmanaged with a statement that Orca's skills are declared into the three roots and follow the packaged Orca version, while other skills stay user-owned. Note that bumping Orca requires updating both hashes in `packages/orca.nix`.
- **Test expectation:** none -- documentation only.
- **Verification:** The docs name the three roots and the bump procedure.

---

## Verification Contract

| Gate | Command |
|---|---|
| Formatting | `nix fmt -- --ci` |
| Checks | `nix flake check` |
| New check | `nix build --no-link .#checks.x86_64-linux.orca-skills` |
| Host builds | `nix build --no-link .#nixosConfigurations.<host>.config.system.build.toplevel` for `ThinkPad-X1-Carbon-Gen-11`, `ThinkPad-X1-Carbon-Gen-11-bootstrap`, `MS-7D91`, `MS-7D91-bootstrap` |

No `nixos-rebuild switch` is run as validation.

---

## Definition of Done

- U1 through U3 are implemented, and every gate in the Verification Contract passes.
- Each U2 assertion was observed failing under its mutation.
- No abandoned-attempt code remains in the diff.
