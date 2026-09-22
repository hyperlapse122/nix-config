---
title: Python 3 Runtime and Tooling - Plan
type: feat
date: 2026-09-21
topic: python3-runtime
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

## Goal Capsule

- **Objective:** User `h82` has a reliable, out-of-the-box Python 3 runtime and modern virtual environment tooling readily available across interactive shells on ThinkPad X1 Carbon Gen 11.
- **Means:** Declare `python3` and `uv` in Home Manager packages for user `h82` (KTD1).
- **Product Authority:** User `h82` on ThinkPad X1 Carbon Gen 11. Operating system base configuration outside user packages and desktop environment customization are non-goals.
- **Open Blockers:** None.

---

## Product Contract

*Product Contract preservation: Product Contract unchanged.*

### Summary

Add `python3` and `uv` to Home Manager package configuration for user `h82`, providing a baseline CLI interpreter and modern package/virtual environment management without NixOS PEP 668 friction.

### Problem Frame

The developer environment packages Node.js, Bun, and coding agent CLIs in Home Manager, but lacks a baseline Python runtime on PATH in daily interactive shell sessions. On NixOS, running ad-hoc Python workflows or package installations without isolated virtual environments triggers PEP 668 externally-managed-environment errors due to the immutable Nix store.

### Key Decisions

- **Install Python 3 and uv as declarative Home Manager packages** (session-settled: user-directed — chosen over minimal python3-only and declarative python3.withPackages: provides reliable out-of-the-box runtime and avoids NixOS PEP 668 externally-managed-environment friction using uv for isolated environments). Governs R1, R2, R3.
- **Manage developer tooling exclusively in Home Manager.** Keeps `modules/nixos/base.nix` focused on OS, hardware, and system security while isolating developer runtimes to user `h82`. Governs R1, R2.

### Requirements

**Runtimes and Tooling**

- R1. User `h82` has `pkgs.python3` available globally on PATH via Home Manager packages.
- R2. User `h82` has `pkgs.uv` available globally on PATH via Home Manager packages.

**Toolchain Interoperability**

- R3. User `h82` can create and activate Python virtual environments using `uv venv` without PEP 668 errors or Nix store mutations.
- R4. Project-level version configuration via `mise` takes precedence in subdirectories without conflicting with global Nix-installed Python.

### Acceptance Examples

- AE1. Runtime CLI execution
  - **Covers R1, R2.**
  - **Given:** An interactive shell session for user `h82`.
  - **When:** `python3 --version` and `uv --version` are executed.
  - **Then:** Both tools execute successfully and output valid version strings.

- AE2. Isolated virtual environment creation
  - **Covers R3.**
  - **Given:** A local working directory without an existing Python environment.
  - **When:** `uv venv` is executed to generate an isolated virtual environment.
  - **Then:** The virtual environment is created successfully in `.venv` without permission or PEP 668 failures.

- AE3. Project version precedence with mise
  - **Covers R4.**
  - **Given:** A directory containing a project-specific `.tool-versions` or `mise.toml` pinning a specific runtime.
  - **When:** User navigates into the directory in an interactive Zsh shell.
  - **Then:** `mise` resolves the project-pinned runtime ahead of the Nix baseline.

### Scope Boundaries

- Base system package changes in `modules/nixos/base.nix` are excluded to maintain separation of system and user packages.
- Global `pip` modifications or global declarative package sets via `python3.withPackages` are excluded in favor of `uv` virtual environments.

### Sources / Research

- `home/h82/default.nix`: Home Manager package declarations for user `h82`.
- `home/h82/shell.nix`: Mise and Zsh shell integration.
- `.compound-engineering/artifacts/plans/2026-09-21-0935-feat-dev-tools-coding-agents-plan.md`: Established precedents for developer runtimes and user-scoped packages.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Declare `pkgs.python3` and `pkgs.uv` directly in `home.packages`** (session-settled: user-directed — chosen over minimal python3-only and declarative python3.withPackages: provides reliable out-of-the-box runtime and avoids NixOS PEP 668 externally-managed-environment friction using uv for isolated environments). Adds packages to `home/h82/default.nix` alongside Node.js and Bun. Governs R1, R2, R3.
- KTD2. **Keep developer tooling isolated to user `h82` Home Manager configuration.** Preserves separation between system security/hardware modules (`modules/nixos/base.nix`) and developer CLI tools. Governs R1, R2.
- KTD3. **Verify package availability via flake check integration test.** Add `checks.${system}.python3-runtime` in `flake.nix` validating that `python3` and `uv` are included in `home-manager.users.h82.home.packages` and their CLI commands run. Governs R1, R2.

### Technical Design

The implementation modifies `home/h82/default.nix` to include `python3` and `uv` in `home.packages`. To ensure no regressions and verify the package declarations, a new check `python3-runtime` is declared in `flake.nix` `checks.${system}`, matching existing test patterns (`zsh-prezto-tests`, `ghostty-font-tests`).

### Assumptions

- Upstream `nixpkgs` (nixos-unstable) carries standard `python3` and `uv` packages that build and evaluate cleanly on `x86_64-linux`.

---

## Implementation Units

### U1. Add Python 3 and uv to Home Manager packages

- **Goal:** Add `python3` and `uv` to `home.packages` in `home/h82/default.nix`.
- **Requirements:** R1, R2, R3
- **Dependencies:** None
- **Files:** `home/h82/default.nix`
- **Approach:**
  1. Edit `home/h82/default.nix` to insert `python3` and `uv` into the `home.packages` list in alphabetical order.
- **Patterns to follow:** Existing entries in `home/h82/default.nix` (e.g. `bun`, `nodejs`, `claude-code`).
- **Test scenarios:**
  - Happy path: `home.packages` evaluates cleanly in NixOS host configuration with `python3` and `uv` present.
- **Verification:** Evaluated `config.home-manager.users.h82.home.packages` contains `python3` and `uv`.

### U2. Add automated flake check for Python runtime

- **Goal:** Register a flake check in `flake.nix` validating `python3` and `uv` in user packages.
- **Requirements:** R1, R2, R4
- **Dependencies:** U1
- **Files:** `flake.nix`
- **Approach:**
  1. Add `python3-runtime` to `checks.${system}` in `flake.nix`.
  2. The check inspects the evaluated `home-manager.users.h82.home.packages` to ensure `python3` and `uv` are present, and validates basic execution.
- **Patterns to follow:** `checks.${system}.zsh-prezto` and `checks.${system}.ghostty-font` in `flake.nix`.
- **Test scenarios:**
  - Covers AE1, AE2, AE3.
  - Happy path: `nix build --no-link .#checks.x86_64-linux.python3-runtime` passes.
- **Verification:** `nix flake check` runs and passes.

---

## Verification Contract

| Verification Command | Purpose | Expected Outcome |
| --- | --- | --- |
| `nix fmt -- --ci` | Formatting compliance | Clean exit 0 |
| `nix flake check` | All flake checks including `python3-runtime` | Clean exit 0 |
| `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel` | Host system build check | Builds successfully |
| `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel` | Bootstrap system build check | Builds successfully |

---

## Definition of Done

- Requirements R1, R2, R3, and R4 are satisfied.
- Both `python3` and `uv` packages are declared in `home/h82/default.nix`.
- Flake check `python3-runtime` passes in `nix flake check`.
- Host and bootstrap system toplevel builds succeed.
- Code conforms to repository formatting guidelines (`nix fmt -- --ci`).
