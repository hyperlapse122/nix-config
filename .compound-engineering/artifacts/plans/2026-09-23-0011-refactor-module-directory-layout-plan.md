---
title: Restructure NixOS and Home Manager Module Directories - Plan
type: refactor
date: 2026-09-23
topic: module-directory-layout
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Restructure NixOS and Home Manager Module Directories - Plan

## Goal Capsule

- **Objective:** A contributor (human or coding agent) can find, add, and reason about a NixOS or Home Manager module by its domain directory alone, without scanning a flat 11-file listing — and every existing host keeps building and behaving exactly as it does today.
- **Means:** Group `modules/nixos/`'s 11 modules into subsystem directories (`hardware/`, `system/`, `desktop/`, `services/`) and `home/h82/`'s 11 flat modules plus its existing `kde/` subdirectory into domain directories (`agents/`, `desktop/`, `dev/`, `security/`, `shell/`), each Home Manager domain gaining a `default.nix` entry point (KTD1-KTD4).
- **Authority hierarchy:** Requirements below set what must hold; KTD1-KTD4 set how the move is mechanized within that scope; Implementation Units carry it out. AGENTS.md's lifecycle constraints (no `nixos-rebuild switch`, no real secrets, no hardware install) bound every unit regardless.
- **Stop conditions:** Stop and report rather than working around it if `nix flake check` or a host build fails for a reason other than a path left unfixed by this plan's own file list, or if any host's post-move build differs from its pre-move baseline in anything but the paths that declared it (a real behavioral drift, not store-path noise).
- **Execution profile:** Single-session mechanical refactor verified by evaluation and build — no runtime step, no hardware, no `nixos-rebuild switch`.
- **Who finishes and ships:** The implementing agent or engineer completes all units, runs the Verification Contract, and opens the PR per AGENTS.md's commit and PR conventions.

---

## Product Contract

### Summary

Reorganize `modules/nixos/` and `home/h82/` from flat file listings into domain-grouped directories, updating every consumer of the old paths (`hosts/`, `tests/`, `flake.nix`-adjacent automation, and prose) so the flake evaluates and builds unchanged. This is pure structural preparation for the 21+ migration issues already queued behind GitHub issue #73 — no module's behavior, option, or host membership changes.

### Problem Frame

`modules/nixos/` holds 11 flat `.nix` files and `home/h82/` holds 11 flat files alongside a single `kde/` subdirectory. GitHub issue #73 (`refactor(modules): restructure NixOS and Home Manager modules for scalability and maintainability`) queues 21+ follow-up issues — hardware udev rules, sysctl, audio/WirePlumber, VSCodium, autostart, avatars, Kubernetes, linter/LSP tooling, supply-chain hardening, network profiles — that would each add one or more files to these two directories. Landing them into the current flat layout would make the directories harder to scan, complicate import chains, and obscure which modules are host-specific versus shared. This plan lands the directory shape those issues will build into, before any of them start.

### Requirements

#### Directory restructuring

- R1. `modules/nixos/` groups its 11 modules into `hardware/`, `system/`, `desktop/`, and `services/` subdirectories by subsystem, with no domain-level `default.nix` aggregator — each host's `hosts/*/default.nix` keeps cherry-picking the exact modules it imports today (KTD1, KTD2).
- R2. `home/h82/` groups its 11 flat modules and the existing `kde/` subdirectory into `agents/`, `desktop/`, `dev/`, `security/`, and `shell/` domain directories, each with its own `default.nix` entry point that `home/h82/default.nix` imports (KTD1, KTD3).

#### Consumer-path integrity

- R3. Every relative import or interpolated path a moved file used to reach a sibling module, a repo-root resource (`packages/`, `keys/`, `config/`, `scripts/`, `secrets/`), or the flake's module graph is updated to the file's new location — across `hosts/*/default.nix`, `tests/*.nix`, `home/h82/default.nix`, and each moved leaf module's own path references.
- R4. The automated dependency-update workflow (`.github/workflows/update-dependencies.yml`) and current in-repo prose that names a moved file (`flake.nix`, `AGENTS.md`, `docs/provisioning.md`, `docs/recovery.md`, `scripts/enroll-fingerprint`, `tests/agent-plugins.nix`, and `modules/nixos/nix-cleanup.nix`'s own comment) reference the new paths.

#### Build and format verification

- R5. `nix fmt -- --ci` passes with no diff.
- R6. `nix flake check` passes with every declared check green.
- R7. `nix build --no-link` succeeds for all four host targets (`ThinkPad-X1-Carbon-Gen-11`, `ThinkPad-X1-Carbon-Gen-11-bootstrap`, `MS-7D91`, `MS-7D91-bootstrap`), and each host's `config.system.build.toplevel` output is unchanged from its pre-restructure baseline.

### Scope Boundaries

#### Deferred to Follow-Up Work

- The 21+ queued migration issues themselves — this plan only prepares the directory shape they land in.
- Converting today's unconditionally-applied NixOS modules (`keyd.nix`, `nix-cleanup.nix`, `desktop.nix`, etc.) to `my.*`-gated feature toggles — KTD1's rejected alternative, and a materially larger change if the team later wants a NixOS-side `default.nix` aggregator to match the Home Manager side.
- Renaming module basenames for clarity (e.g. `desktop.nix` → `plasma.nix` once an Audio/PipeWire module joins `desktop/`) beyond the structural move (KTD3).
- Rewriting path or line-number references inside historical `.compound-engineering/artifacts/plans/` and `.compound-engineering/artifacts/solutions/` records (see Assumptions).

#### Outside This Plan's Identity

- Any change to a host's actual enabled features or option values (`my.podman.enable`, `my.fingerprint.enable`, `my.keyd.copilotKey`, etc.) — every value stays byte-identical.
- Hardware installation, `nixos-rebuild switch`, or firmware/TPM enrollment — AGENTS.md forbids these for this kind of change regardless of scope.

### Sources / Research

- `hosts/MS-7D91/default.nix` omits `fingerprint.nix`, `keyd.nix`, and `nix-cleanup.nix` from its imports, while `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix` includes all three — host variance today is entirely which files a host's `imports` list cherry-picks, not an option toggle (evidence for KTD1, KTD2).
- `modules/nixos/keyd.nix` and `modules/nixos/nix-cleanup.nix` apply their config unconditionally (`services.keyd.enable = true`, generation cleanup) with no `enable` option at all; `modules/nixos/fingerprint.nix` is the only host-exclusive module that does define one (evidence for KTD2's regression risk).
- Of the 11 `modules/nixos/` files, only `fingerprint.nix`, `keyd.nix`, `podman.nix`, and `secrets.nix` define any `my.*` option; `base.nix`, `boot.nix`, `desktop.nix`, `fonts.nix`, `nix-cleanup.nix`, `nix-ld.nix`, and `yubikey.nix` define none (evidence for KTD1: `my.*` is used ad hoc for already-parameterized modules, not as a comprehensive toggle catalog).
- `home/h82/kde/default.nix` is the existing precedent for a domain-folder `default.nix` entry point that `home/h82/default.nix` imports as `./kde` — the pattern this plan extends to the four new Home Manager domains (evidence for KTD3).
- `.github/workflows/update-dependencies.yml:62,69,121,123` `sed -i`s and `git add`s the literal path `home/h82/agent-plugins.nix` to track the `compound-engineering-plugin` pin — a load-bearing consumer the issue text's "update imports across `hosts/`, `flake.nix`, and `tests/`" does not name (evidence for R4/U5).
- `grep -rn '\.\./' modules/nixos/ home/h82/` located every leaf-module path reference needing a `../` fixup: `modules/nixos/{base,secrets,fingerprint}.nix` and `home/h82/{gpg,ssh,agent-plugins,gemini,claude}.nix` (see U1 and U4 Approach for the exact list).

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Subsystem/domain directories, not a `my.*` feature-toggle catalog.** Only 4 of `modules/nixos/`'s 11 modules (and 1 of `home/h82/`'s) define any `my.*` option today; the rest apply their config unconditionally and are included or excluded per-host purely by presence in that host's `imports` list. Converting every currently-unconditional module to an `enable`-gated option, then inverting host wiring to "import everything, toggle per host," would be a materially larger, behavior-adjacent change — exactly the kind that risks the "unexpected generation diff" R7 forbids — for work whose only goal is directory readability ahead of the next 21 issues. Directory grouping delivers the same navigability as a near-zero-risk pure move. Research already resolved this from the per-host import evidence above, so no Bake-off was warranted. (Not session-settled: the invoking request explicitly left the grouping approach open and delegated the choice to planning.) Governs R1, R2.
- KTD2. **No domain-level `default.nix` aggregator on the NixOS side.** `fingerprint.nix`, `keyd.nix`, and `nix-cleanup.nix` are imported by `ThinkPad-X1-Carbon-Gen-11` but deliberately absent from `MS-7D91`'s imports, and `keyd.nix`/`nix-cleanup.nix` have no `enable` gate at all — a `hardware/default.nix` (or `system/default.nix`) that imported every file in its folder would silently switch keyd and generation-limit cleanup on for `MS-7D91`, a real regression R7 exists to catch. Each `hosts/*/default.nix` keeps its current per-file cherry-picked imports, pointed at the new nested paths (U2). Governs R1, R7.
- KTD3. **Home Manager domains do get a `default.nix` each, mirroring the existing `kde/` pattern.** Home Manager has exactly one shared user profile (`home/h82/default.nix`) applied identically to every host, so nothing host-specific is lost by unconditionally importing everything inside a domain folder — the same risk KTD2 avoids on the NixOS side does not exist here. Governs R2.
- KTD4. **Preserve existing basenames; pure `git mv`, no renames.** E.g. `modules/nixos/desktop.nix` becomes `modules/nixos/desktop/desktop.nix`, not `modules/nixos/desktop/plasma.nix`. Keeps the diff a structural relocation only, so it reviews as a rename plus a small, enumerable set of path-string edits rather than a mixed rename-and-rewrite. Governs R1, R2.

### Assumptions

- A1. The issue's example directory names (`hardware/`, `system/`, `desktop/`, `services/` for NixOS; `agents/`, `desktop/`, `dev/`, `security/`, `shell/` for Home Manager) are adopted verbatim as the concrete plan rather than treated as illustrative alternatives — they partition every existing file with no leftover bucket (see Output Structure).
- A2. `home/h82/containers.nix` (podman registry-auth for the user session) is not named in the issue's Home Manager examples; it is placed under `dev/`, mirroring `modules/nixos/services/podman.nix` and sitting alongside `git.nix`'s developer-tooling framing.
- A3. Historical `.compound-engineering/artifacts/plans/*.md` and `.compound-engineering/artifacts/solutions/*.md` files that mention a moved file's old path (several do, including embedded line numbers) are left untouched — they are point-in-time incident and decision records, not living documentation, and AGENTS.md asks that they be *read* before certain changes, not kept path-current on every later refactor.

### Sequencing and Dependencies

U2 and U3 depend on U1 (they reference the NixOS files at their new paths). U5 and U6 depend on U1 and U4 (they need the final paths to cite). U7 depends on U1-U6 together. U4 (the Home Manager move) has no dependency on U1-U3 and can proceed in parallel with them.

---

## Output Structure

```text
modules/nixos/
  hardware/
    fingerprint.nix
    keyd.nix
    yubikey.nix
  system/
    base.nix
    boot.nix
    nix-cleanup.nix
    nix-ld.nix
    secrets.nix
  desktop/
    desktop.nix
    fonts.nix
  services/
    podman.nix

home/h82/
  default.nix                  # unchanged location; imports the five domains below
  agents/
    default.nix                # new
    agent-plugins.nix
    claude.nix
    gemini.nix
  desktop/
    default.nix                # new
    fcitx5.nix
    terminal.nix
    kde/                       # unchanged internally, nested one level deeper
      apps.nix
      autostart.nix
      browser-integration.nix
      default.nix
      input.nix
      kwin.nix
      plasma.nix
      session.nix
  dev/
    default.nix                # new
    containers.nix
    git.nix
  security/
    default.nix                # new
    gpg.nix
    ssh.nix
  shell/
    default.nix                # new
    shell.nix
```

---

## Implementation Units

### U1. Move NixOS modules into subsystem directories

- **Goal:** Relocate all 11 `modules/nixos/` files into `hardware/`, `system/`, `desktop/`, `services/` with no domain `default.nix` (KTD1, KTD2, KTD4), fixing each moved file's own repo-root path references and self-referential comments.
- **Requirements:** R1, R3, R4.
- **Dependencies:** none.
- **Files:**
  - `modules/nixos/{fingerprint,keyd,yubikey}.nix` → `modules/nixos/hardware/`
  - `modules/nixos/{base,boot,nix-cleanup,nix-ld,secrets}.nix` → `modules/nixos/system/`
  - `modules/nixos/{desktop,fonts}.nix` → `modules/nixos/desktop/`
  - `modules/nixos/podman.nix` → `modules/nixos/services/`
- **Approach:**
  1. `git mv` each file into its new subdirectory per the mapping above, preserving basenames (KTD4).
  2. In the moved `system/base.nix`, bump `../../packages/gpg-tools.nix` to `../../../packages/gpg-tools.nix`.
  3. In the moved `system/secrets.nix`, bump all three repo-root references one level: `../../scripts/publish-cli-auth`, `../../packages/docker-credential-sops.nix`, `../../secrets/tokens.yaml` → `../../../scripts/publish-cli-auth`, `../../../packages/docker-credential-sops.nix`, `../../../secrets/tokens.yaml`.
  4. In the moved `hardware/fingerprint.nix`, bump `../../packages/enroll-fingerprint.nix` to `../../../packages/enroll-fingerprint.nix`.
  5. In the moved `system/nix-cleanup.nix`, update its comment's `modules/nixos/boot.nix` mention to `modules/nixos/system/boot.nix`.
  6. Leave `boot.nix`, `desktop.nix`, `fonts.nix`, `keyd.nix`, `nix-ld.nix`, `podman.nix`, and `yubikey.nix` content untouched — they hold no repo-root path references or stale comments.
- **Patterns to follow:** none of these files gain an `enable` option or a folder `default.nix` — see KTD2.
- **Execution note:** This is config relocation with no behavior change; prefer eval/build smoke verification (U7) over unit coverage.
- **Test expectation:** none -- pure file move plus mechanical path-depth fixups; correctness is proven transitively once U2 rewires host imports and U7's `nix flake check` / host builds evaluate every moved file.
- **Verification:** Every file listed above exists at its new path with `git status` showing a rename, not a delete+add; the four repo-root references in steps 2-4 resolve (checked by U7, since these files are not independently evaluable outside a host); `nix-cleanup.nix`'s comment no longer names the pre-move `boot.nix` path.

### U2. Repoint host imports at the new NixOS paths

- **Goal:** Update both hosts' `imports` lists to the moved paths while keeping each host's exact module membership.
- **Requirements:** R1, R3.
- **Dependencies:** U1.
- **Files:**
  - `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`
  - `hosts/MS-7D91/default.nix`
- **Approach:**
  1. In `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`, rewrite each `../../modules/nixos/<file>.nix` entry to its new subdirectory path, keeping all 11 entries (this host imports `fingerprint.nix`, `keyd.nix`, and `nix-cleanup.nix`; the others do not).
  2. In `hosts/MS-7D91/default.nix`, rewrite its 8 entries the same way, continuing to omit `fingerprint.nix`, `keyd.nix`, and `nix-cleanup.nix`.
  3. Do not add, remove, or reorder any module beyond the path string itself.
- **Patterns to follow:** the current explicit, per-file `imports` list in each host's `default.nix` — this unit changes path strings only.
- **Execution note:** Config relocation with no behavior change; prefer eval/build smoke verification (U7) over unit coverage.
- **Test expectation:** none -- path-string edits only; a wrong or missing entry fails `nix flake check`/host build (U7) loudly, not silently.
- **Verification:** `git diff` on both files shows only path-string changes, with the same set of modules present per host as before the move.

### U3. Repoint NixOS-side test imports and comments

- **Goal:** Update the VM checks that import moved `modules/nixos/` files directly, plus the comments in nearby test files that name a moved file's old path.
- **Requirements:** R3, R4.
- **Dependencies:** U1.
- **Files:**
  - `tests/auth-provisioning.nix`
  - `tests/boot-layout.nix`
  - `tests/podman-registry-auth.nix`
  - `tests/nix-cleanup.nix`
  - `tests/pam-fingerprint.nix`
- **Approach:**
  1. In `tests/auth-provisioning.nix`, update both `../modules/nixos/secrets.nix` references to `../modules/nixos/system/secrets.nix`.
  2. In `tests/boot-layout.nix`, update `bootModule = ../modules/nixos/boot.nix;` to `../modules/nixos/system/boot.nix`.
  3. In `tests/podman-registry-auth.nix`, update both `../modules/nixos/secrets.nix` and both `../modules/nixos/podman.nix` references to `../modules/nixos/system/secrets.nix` and `../modules/nixos/services/podman.nix`.
  4. In `tests/nix-cleanup.nix` and `tests/pam-fingerprint.nix`, update the prose comments naming `modules/nixos/boot.nix` and `modules/nixos/fingerprint.nix` to their new paths.
- **Execution note:** Config relocation with no behavior change; prefer eval/build smoke verification (U7) over unit coverage.
- **Test expectation:** none -- these are the checks that prove the plan; their own correctness is exercised directly by running them in U7 (`nix flake check` builds each as a VM test).
- **Verification:** `nix flake check` (U7) builds `auth-provisioning`, `boot-layout`, and `podman-registry-auth` without an import-resolution error.

### U4. Move Home Manager modules into domain directories

- **Goal:** Relocate `home/h82/`'s 11 flat files and `kde/` into `agents/`, `desktop/`, `dev/`, `security/`, `shell/`, each with a new `default.nix`, and repoint `home/h82/default.nix`'s own imports.
- **Requirements:** R2, R3.
- **Dependencies:** none (independent of U1-U3).
- **Files:**
  - `home/h82/{agent-plugins,claude,gemini}.nix` → `home/h82/agents/` (+ new `home/h82/agents/default.nix`)
  - `home/h82/{fcitx5,terminal}.nix` and `home/h82/kde/` → `home/h82/desktop/` (+ new `home/h82/desktop/default.nix`)
  - `home/h82/{containers,git}.nix` → `home/h82/dev/` (+ new `home/h82/dev/default.nix`)
  - `home/h82/{gpg,ssh}.nix` → `home/h82/security/` (+ new `home/h82/security/default.nix`)
  - `home/h82/shell.nix` → `home/h82/shell/` (+ new `home/h82/shell/default.nix`)
  - `home/h82/default.nix` (stays in place; imports list only)
- **Approach:**
  1. `git mv` each file/directory per the mapping above, preserving basenames (KTD4); `kde/`'s 8 files move as a unit with no internal edits (none reference `../`).
  2. In the moved `security/gpg.nix`, bump `../../packages/gpg-tools.nix`, `../../keys/signing.asc`, `../../keys/signing-legacy.asc` to `../../../...`.
  3. In the moved `security/ssh.nix`, bump `../../config/1password/agent.toml` to `../../../config/1password/agent.toml`.
  4. In the moved `agents/agent-plugins.nix`, `agents/claude.nix`, and `agents/gemini.nix`, bump each `../../packages/agent-tools.nix` to `../../../packages/agent-tools.nix`.
  5. Create the four new domain `default.nix` files, each importing exactly its sibling files (and `./kde` for `desktop/`), following `home/h82/kde/default.nix`'s existing shape.
  6. In `home/h82/default.nix`, replace the 11-entry flat `imports` list with `./agents`, `./desktop`, `./dev`, `./security`, `./shell`; leave every other line (its own `../../packages/*` references, `home.packages`, etc.) untouched — the file itself does not move.
- **Patterns to follow:** `home/h82/kde/default.nix` — the existing domain-folder `default.nix` this unit's four new ones mirror.
- **Execution note:** Config relocation with no behavior change; prefer eval/build smoke verification (U7) over unit coverage.
- **Test expectation:** none -- pure file move, new pass-through `default.nix` files, and mechanical path-depth fixups; proven transitively by U7.
- **Verification:** Every file above exists at its new path with `git status` showing a rename; `home/h82/default.nix` imports exactly the five domain directories; the six repo-root references in steps 2-4 resolve (checked by U7).

### U5. Repoint the dependency-update workflow

- **Goal:** Keep the `compound-engineering-plugin` pin-tracking automation working after `agent-plugins.nix` moves.
- **Requirements:** R4.
- **Dependencies:** U4.
- **Files:**
  - `.github/workflows/update-dependencies.yml`
- **Approach:**
  1. Update both `sed -i` targets (the `tag =` and `expectedRev =` rewrites) from `home/h82/agent-plugins.nix` to `home/h82/agents/agent-plugins.nix`.
  2. Update the `git status --porcelain home/h82/agent-plugins.nix` check and the `sed -n` read of the new tag to the new path.
  3. Update the `git add` line's path from `home/h82/agent-plugins.nix` to `home/h82/agents/agent-plugins.nix`.
- **Execution note:** Config relocation with no behavior change; verify by reading the diff, since this workflow only runs on its own schedule/trigger and is out of this plan's CI surface.
- **Test expectation:** none -- path-string edits in a workflow file; no local check exercises this workflow directly (see Verification Contract).
- **Verification:** Every `home/h82/agent-plugins.nix` string in the file now reads `home/h82/agents/agent-plugins.nix`; no other line changes.

### U6. Repoint documentation and code comments

- **Goal:** Keep AGENTS.md, the docs guides, and the in-repo comments that name a moved file's old path accurate, and document the new layout per the acceptance criteria.
- **Requirements:** R4.
- **Dependencies:** U1, U4.
- **Files:**
  - `flake.nix`
  - `AGENTS.md`
  - `docs/provisioning.md`
  - `docs/recovery.md`
  - `scripts/enroll-fingerprint`
  - `tests/agent-plugins.nix`
- **Approach:**
  1. In `flake.nix`'s `compound-engineering-plugin` input comment, update the `home/h82/agent-plugins.nix` mention to `home/h82/agents/agent-plugins.nix`.
  2. In `AGENTS.md`'s Project structure section, expand the bullet that currently reads `modules/nixos/`: system modules; `home/h82/`: Home Manager modules into the two directory trees from Output Structure (or an equivalent short breakdown naming each subsystem/domain and what it holds).
  3. In `docs/provisioning.md`, update every reference to a moved file — `home/h82/kde/autostart.nix`, the repeated mentions of `home/h82/claude.nix`, `home/h82/gemini.nix`, and `modules/nixos/podman.nix` — to its new path; leave the `home/h82/default.nix` mention as-is, since that file does not move.
  4. In `docs/recovery.md`, update the `modules/nixos/nix-cleanup.nix` reference to its new path.
  5. In `scripts/enroll-fingerprint`'s comment and `tests/agent-plugins.nix`'s comments, update the `modules/nixos/fingerprint.nix` and `home/h82/agent-plugins.nix` mentions to their new paths.
- **Execution note:** Documentation accuracy; no build-facing verification applies.
- **Test expectation:** none -- prose and comment edits only.
- **Verification:** `grep -rn "modules/nixos/[a-z-]*\.nix\|home/h82/[a-z-]*\.nix"` across the files above returns only new-path strings (or none, where the reference became a directory-level mention).

### U7. Verify no behavioral drift

- **Goal:** Prove the restructuring is a pure move — format, checks, and all four host builds succeed, and each host's built system is unchanged from its pre-restructure baseline.
- **Requirements:** R5, R6, R7.
- **Dependencies:** U1, U2, U3, U4, U5, U6.
- **Files:** none (verification only).
- **Approach:**
  1. Run `nix fmt -- --ci`, `nix flake check`, and `nix build --no-link` for all four host targets on the restructured tree.
  2. For the store-path-equality proof, evaluate each host's `config.system.build.toplevel.drvPath` against the pre-restructure base ref (e.g. via `git worktree add`, not a baseline captured earlier in this same sequence — U1-U6 already changed the working tree by the time this unit runs) and against the restructured working tree, then diff the two per host.
- **Test scenarios:**
  - Happy path: all four `nix build --no-link .#nixosConfigurations.<host>.config.system.build.toplevel` commands succeed for `ThinkPad-X1-Carbon-Gen-11`, `ThinkPad-X1-Carbon-Gen-11-bootstrap`, `MS-7D91`, `MS-7D91-bootstrap`.
  - Happy path: `nix fmt -- --ci` exits 0 with no diff.
  - Happy path: `nix flake check` exits 0, with `auth-provisioning`, `boot-layout`, `podman-registry-auth`, `podman-containers`, `nix-cleanup`, `pam-fingerprint`, and `keyd-remap` (the checks that evaluate the moved production modules) all green.
  - Integration scenario: each host's `config.system.build.toplevel.drvPath` on the restructured tree is byte-identical to the same evaluation against the pre-restructure base ref — proves the move changed no evaluated config, not just that it built.
  - Edge case: `MS-7D91`'s built closure still shows `services.keyd.enable` false and no fingerprint PAM service — proves KTD2 held and no module leaked across the host boundary.
  - Error path (pre-merge, not user-facing): a deliberately reverted single path fixup in a scratch check reproduces a `nix flake check` failure, confirming the verification would have caught a missed fixup rather than silently passing.
- **Verification:** Every command in the Verification Contract exits 0, and the per-host `drvPath` diff against the base ref is empty for all four hosts.

---

## Verification Contract

```sh
# Format
nix fmt -- --ci

# Declared checks
nix flake check

# All four host targets
nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.MS-7D91.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.MS-7D91-bootstrap.config.system.build.toplevel
```

For the store-path-equality proof in U7, evaluate `nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath` for all four hosts both against the restructured working tree and against the pre-restructure base ref (e.g. a `git worktree add` checkout of the commit before U1's first change) — never against a value captured earlier in the same working tree, since U1-U6 already mutate it. The two evaluations must match per host.

---

## Definition of Done

- All four `nixosConfigurations` targets build via `nix build --no-link`, and each host's `config.system.build.toplevel` store path matches its pre-restructure baseline.
- `nix fmt -- --ci` and `nix flake check` both pass with no regressions.
- No flat `.nix` file remains directly under `modules/nixos/` except the four new subdirectories, and none remains directly under `home/h82/` except `default.nix` and the five new domain directories.
- `.github/workflows/update-dependencies.yml` references `home/h82/agents/agent-plugins.nix`.
- `AGENTS.md`, `docs/provisioning.md`, and `docs/recovery.md` reference the new paths and AGENTS.md documents the new directory layout.
- Every moved file's `git` history shows a rename (via `git mv`), not a delete-and-recreate.
