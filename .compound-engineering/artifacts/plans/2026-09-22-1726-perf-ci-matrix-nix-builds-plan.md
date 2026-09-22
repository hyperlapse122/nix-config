---
title: Matrix Nix Build Jobs in CI Workflow - Plan
type: perf
date: 2026-09-22
topic: ci-matrix-nix-builds
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Matrix Nix Build Jobs in CI Workflow - Plan

## Goal Capsule

- **Objective:** Developer pull requests and main pushes build all four NixOS toplevel configurations concurrently across independent matrix runner jobs rather than sequentially inside monolithic jobs.
- **Means:** Refactor `.github/workflows/check.yml` to replace the `build-production` and `build-bootstrap` jobs with a unified `build` job using GitHub Actions matrix strategy (`target: [ThinkPad-X1-Carbon-Gen-11, ThinkPad-X1-Carbon-Gen-11-bootstrap, MS-7D91, MS-7D91-bootstrap]`) with `fail-fast: false`.
- **Product Authority:** CI workflow definition in `.github/workflows/check.yml`.
- **Open Blockers:** None.

---

## Product Contract

### Summary

Consolidate the two separate build jobs (`build-production` and `build-bootstrap`) in `.github/workflows/check.yml` into a single `build` job driven by a GitHub Actions matrix over the four `nixosConfigurations` (`ThinkPad-X1-Carbon-Gen-11`, `ThinkPad-X1-Carbon-Gen-11-bootstrap`, `MS-7D91`, `MS-7D91-bootstrap`). Run each build with `fail-fast: false` on `ubuntu-24.04` with disk cleanup, 60-minute timeout, and `big-parallel benchmark` Nix system-features.

### Problem Frame

Previously, `build-production` built `ThinkPad-X1-Carbon-Gen-11` and `MS-7D91` sequentially in one runner, and `build-bootstrap` built `ThinkPad-X1-Carbon-Gen-11-bootstrap` and `MS-7D91-bootstrap` sequentially in another. Because each runner built two heavy NixOS system closures sequentially, wall-clock time was doubled and failure of one target in a job masked the status of the second target. Since this is a public repository with unconstrained runner concurrency and no minute billing concerns, running all four targets concurrently in parallel matrix jobs minimizes wall-clock duration and provides granular per-target status checks.

### Key Decisions

- **KD1. Single `build` job with 4-target matrix over separate jobs with smaller matrices**: Replace both `build-production` and `build-bootstrap` with a single `build` job using `matrix.target` (session-settled: user-directed — chosen over maintaining separate jobs or complex multi-dimensional matrices: eliminates duplicate step definitions and maps 1:1 to flake configuration attributes). Governs R1, R3, R4.
- **KD2. `fail-fast: false` on matrix strategy**: Disable fail-fast so that all matrix jobs run to completion regardless of other job failures (session-settled: user-directed — chosen over default `fail-fast: true`: in a public repository where total runner time is not a constraint, independent execution guarantees full diagnostic feedback for every host configuration). Governs R2.
- **KD3. Preserve runner isolation and Nix features**: Retain `ubuntu-24.04`, 60-minute timeout, disk cleanup (`sudo rm -rf /usr/local/lib/android /usr/share/dotnet /opt/ghc`), and `system-features = big-parallel benchmark` without KVM (session-settled: user-directed — maintains established build prerequisites while keeping KVM enablement strictly isolated to `flake-check`). Governs R3, R5.

### Requirements

- R1. `.github/workflows/check.yml` defines a `build` job using `strategy.matrix.target` containing `ThinkPad-X1-Carbon-Gen-11`, `ThinkPad-X1-Carbon-Gen-11-bootstrap`, `MS-7D91`, and `MS-7D91-bootstrap`.
- R2. The matrix strategy specifies `fail-fast: false`.
- R3. The `build` job executes on `ubuntu-24.04` with `timeout-minutes: 60`, runs runner disk cleanup, installs Nix with `system-features = big-parallel benchmark`, and builds `.#nixosConfigurations.${{ matrix.target }}.config.system.build.toplevel` with `--no-link`.
- R4. The previous `build-production` and `build-bootstrap` jobs are removed from `.github/workflows/check.yml`.
- R5. The `fmt` and `flake-check` jobs remain untouched.

### Acceptance Examples

- AE1. CI workflow triggers 6 discrete parallel jobs: `fmt`, `flake-check`, and 4 matrix instances under `build`.
- AE2. In GitHub Actions, matrix instances appear individually with clear target identifiers.
- AE3. If one target build fails, the other 3 target builds continue running to completion due to `fail-fast: false`.

---

## Planning Contract

### Key Technical Decisions

- **KTD1. Unified matrix target attribute**: Define matrix entries matching `nixosConfigurations.<name>` directly so the build command is cleanly parameterized:
  `nix build --no-link .#nixosConfigurations.${{ matrix.target }}.config.system.build.toplevel`.
- **KTD2. Cleanup and environment consistency**: Keep the `Make room for NixOS closures` step identical to existing build jobs to prevent runner root partition exhaustion during closure downloads.

### Technical Design

In `.github/workflows/check.yml`:

```yaml
  build:
    runs-on: ubuntu-24.04
    timeout-minutes: 60
    strategy:
      fail-fast: false
      matrix:
        target:
          - ThinkPad-X1-Carbon-Gen-11
          - ThinkPad-X1-Carbon-Gen-11-bootstrap
          - MS-7D91
          - MS-7D91-bootstrap
    steps:
      - uses: actions/checkout@fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09 # v5
      - name: Make room for NixOS closures
        run: sudo rm -rf /usr/local/lib/android /usr/share/dotnet /opt/ghc
      - uses: cachix/install-nix-action@13d8dd58da0234aa297dedd986986ccb8e7f3e24
        with:
          extra_nix_config: |
            system-features = big-parallel benchmark
      - name: Build host configuration without secrets
        run: |
          nix build --no-link \
            .#nixosConfigurations.${{ matrix.target }}.config.system.build.toplevel
```

### Assumptions

- The GitHub Actions runner quota for public repositories easily supports 6 concurrent jobs without queuing.
- All four target configurations evaluate and build cleanly without secrets.

---

## Implementation Units

### U1: Refactor check.yml to use build matrix

- **Goal:** Replace `build-production` and `build-bootstrap` jobs with a unified `build` matrix job in `.github/workflows/check.yml`.
- **Files:**
  - `.github/workflows/check.yml`
- **Steps:**
  1. Remove `build-production` and `build-bootstrap` jobs.
  2. Add `build` job with `strategy.fail-fast: false` and `strategy.matrix.target`.
  3. Replicate checkout, closure disk space cleanup, and nix installation steps.
  4. Parameterize build step with `.#nixosConfigurations.${{ matrix.target }}.config.system.build.toplevel`.
- **Verification:**
  - Validate YAML structure.
  - Run flake checks and toplevel builds locally.

---

## Verification Contract

- Run YAML validation on `.github/workflows/check.yml`.
- Run `nix flake check` to verify repository checks and workflow assertions.
- Run all four host toplevel builds per `AGENTS.md`:
  - `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel`
  - `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel`
  - `nix build --no-link .#nixosConfigurations.MS-7D91.config.system.build.toplevel`
  - `nix build --no-link .#nixosConfigurations.MS-7D91-bootstrap.config.system.build.toplevel`

---

## Definition of Done

- `.github/workflows/check.yml` contains a single `build` job with a 4-target matrix and `fail-fast: false`.
- `build-production` and `build-bootstrap` are completely removed.
- `fmt` and `flake-check` jobs remain untouched.
- Flake checks and builds succeed.
