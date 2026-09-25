---
title: Development session variables for Testcontainers and telemetry opt-outs - Plan
type: feat
date: 2026-09-25
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Development session variables for Testcontainers and telemetry opt-outs - Plan

## Goal Capsule

- **Objective:** On both machines, Testcontainers suites that start the Ryuk reaper work against rootless Podman, Turborepo passes the user's environment through to tasks, and .NET, Turborepo, and PowerShell send no CLI telemetry. This holds in login shells and in systemd user services started from the Plasma session.
- **Means:** Declare the seven variables once per concern in Home Manager, in both `home.sessionVariables` and `systemd.user.sessionVariables` (KTD1, KTD2). Guard the materialized session files with a flake check (KTD3).
- **Authority:** Issue #62, then this plan's R-IDs, then KTDs.
- **Execution profile:** Lightweight. Two units.
- **Stop conditions:** Stop if a new variable conflicts with an existing declaration of the same name, or if any host build fails.
- **Finish and ship:** `ce-work` implements. The LFG pipeline reviews, opens the PR, and watches CI.

## Product Contract

### Summary

Home Manager declares three Testcontainers/Turborepo compatibility variables and four telemetry opt-outs for `h82`. They reach the shell through `hm-session-vars.sh` and the systemd user manager through `~/.config/environment.d/10-home-manager.conf`. A new flake check reads both rendered files on all four host configurations.

### Problem Frame

The legacy dotfiles set these values in `environment.d` drop-ins (`65-containers.conf`, `60-development.conf`, `80-privacy.conf`). This flake never carried them over. Without `TESTCONTAINERS_RYUK_*PRIVILEGED`, the Ryuk reaper container cannot manage the rootless Podman socket, so Testcontainers suites fail at startup. Without the opt-outs, the .NET SDK, Turborepo, and PowerShell send usage telemetry.

### Requirements

**Container compatibility**

- R1. The user session and the systemd user session set `TESTCONTAINERS_RYUK_CONTAINER_PRIVILEGED=true` and `TESTCONTAINERS_RYUK_PRIVILEGED=true`.
- R2. Both sessions set `TURBO_ENV_MODE=loose`.

**Telemetry opt-outs**

- R3. Both sessions set `DOTNET_CLI_TELEMETRY_OPTOUT=1`, `DOTNET_TELEMETRY_OPTOUT=1`, `TURBO_TELEMETRY_DISABLED=1`, and `POWERSHELL_TELEMETRY_OPTOUT=1`.

**Regression guard**

- R4. A flake check fails when any R1-R3 variable is missing or wrong in the rendered `hm-session-vars.sh` or `environment.d/10-home-manager.conf` of ThinkPad-X1-Carbon-Gen-11, ThinkPad-X1-Carbon-Gen-11-bootstrap, MS-7D91, or MS-7D91-bootstrap.

### Scope Boundaries

- No change to the existing `REGISTRY_AUTH_FILE` and `DOCKER_HOST` values.
- No other variables from the legacy `environment.d` files. Only the seven the issue lists.
- A real Testcontainers run under rootless Podman is hardware verification after a user-run rebuild, reported separately per `docs/verification.md`. It is not part of this change's automated evidence.

### Sources

- Issue: <https://github.com/hyperlapse122/nix-config/issues/62>
- Home Manager `modules/systemd.nix` renders `systemd.user.sessionVariables` as `KEY=value` lines into `xdg.configFile."environment.d/10-home-manager.conf"`. `modules/home-environment.nix` renders `home.sessionVariables` into `home.sessionVariablesPackage` at `etc/profile.d/hm-session-vars.sh`.
- All four host configurations import the same `home/h82` tree through `home-manager.users.h82` in `flake.nix`.

## Planning Contract

### Key Technical Decisions

- KTD1. **Add the Testcontainers pair to `containerSessionVariables` in `home/h82/dev/containers.nix`.** That attribute set already feeds both session targets for `DOCKER_HOST` and `REGISTRY_AUTH_FILE`, and the Ryuk flags exist only for the rootless Podman socket. The issue names `home/h82/containers.nix`, which has since moved to `home/h82/dev/`.
- KTD2. **Put `TURBO_ENV_MODE` and the four opt-outs in a new `home/h82/dev/tool-environment.nix`, imported from `home/h82/dev/default.nix`.** They configure development CLIs, not the shell or containers. One local attribute set feeds both `home.sessionVariables` and `systemd.user.sessionVariables`, mirroring `containers.nix`. Values are strings, as in the issue, so both renderers write `true` and `1` literally.
- KTD3. **Assert on the rendered files, not the option values.** Read `home.sessionVariablesPackage` at `etc/profile.d/hm-session-vars.sh`, and read environment.d from the Home Manager generation's `home-files` derivation at `.config/environment.d/10-home-manager.conf`, following `.compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md`. Anchor each environment.d match to the whole line (`^KEY=value$`) and each shell match to the full `export KEY="value"` line, so a longer value cannot satisfy it. Use explicit `if ...; then exit 1; fi` for every failure. Reading `home-files` catches a disabled, retargeted, or re-sourced entry, which reading the entry's `text` would miss. Fail in the builder, not at evaluation, when the file is absent.

### Assumptions

- `TURBO_ENV_MODE=loose` is wanted despite being a behavior change rather than an opt-out. The issue lists it, and the legacy `60-development.conf` carried it.
- `hm-session-vars.sh` renders `export KEY="value"` lines. The implementer confirms the exact quoting from the built file before anchoring the match.

### Risks

- The Plasma session reads `environment.d` only through the systemd user manager. Applications launched outside it read only what the shell sourced. Declaring both targets covers both paths.

## Implementation Units

### U1. Declare the session variables

- **Goal:** Render R1-R3 into both session files on every host configuration.
- **Requirements:** R1, R2, R3. KTD1, KTD2.
- **Dependencies:** none.
- **Files:** `home/h82/dev/containers.nix`, `home/h82/dev/tool-environment.nix` (new), `home/h82/dev/default.nix`.
- **Approach:**
  1. Add the two `TESTCONTAINERS_RYUK_*` entries to `containerSessionVariables`.
  2. Create `tool-environment.nix` with one `let` attribute set for the other five variables, assigned to both `home.sessionVariables` and `systemd.user.sessionVariables`.
  3. Import it from `home/h82/dev/default.nix`.
- **Patterns to follow:** `home/h82/dev/containers.nix` for the shared attribute set.
- **Test expectation:** covered by U2's check.
- **Verification:** All four host toplevels build, and `nix fmt -- --ci` passes.

### U2. Add the session-variables flake check

- **Goal:** Fail the build when any host stops rendering R1-R3 in either session file (R4).
- **Requirements:** R4. KTD3.
- **Dependencies:** U1.
- **Files:** `tests/session-variables.nix` (new), `flake.nix`.
- **Approach:**
  1. Take `{ pkgs, self }` and run one per-host helper for the four host configurations inside one `pkgs.runCommand`, like `tests/podman-containers.nix`.
  2. Per host, fail when `home-files` has no regular file at `.config/environment.d/10-home-manager.conf`, then grep that file and the built `hm-session-vars.sh` for each expected line.
  3. Register it as `session-variables` in `flake.nix` checks, beside `podman-containers`.
- **Patterns to follow:** `tests/podman-containers.nix` for layout and the header comment block. `tests/kernel-sysctl.nix` for anchored grep over a rendered file.
- **Test scenarios:**
  - Happy path: all four hosts render all seven variables in both files, and the check builds.
  - Error path: removing `TESTCONTAINERS_RYUK_PRIVILEGED` from `containerSessionVariables` fails the check.
  - Error path: assigning the tool attribute set only to `home.sessionVariables` fails the environment.d assertions.
  - Error path: changing `DOTNET_CLI_TELEMETRY_OPTOUT` to `"0"` fails the check.
  - Edge case: a value like `TURBO_ENV_MODE=looser` does not satisfy the anchored match.
  - Error path: setting `enable = false` on the environment.d `xdg.configFile` entry fails the check.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.session-variables` passes on the real configuration and fails under each mutation above. Revert every mutation afterward.

## Verification Contract

| Gate | Command |
| --- | --- |
| Formatting | `nix fmt -- --ci` |
| New check | `nix build --no-link .#checks.x86_64-linux.session-variables` |
| All checks | `nix flake check` |
| Host builds | `nix build --no-link .#nixosConfigurations.<host>.config.system.build.toplevel` for ThinkPad-X1-Carbon-Gen-11, ThinkPad-X1-Carbon-Gen-11-bootstrap, MS-7D91, MS-7D91-bootstrap |

After a user-run rebuild followed by a full logout and login (or a reboot), `systemctl --user show-environment` and a Testcontainers suite using Ryuk, run from a newly opened terminal, confirm the change on hardware. The systemd user manager reads environment.d only at start, and `hm-session-vars.sh` skips itself once sourced in a session. That evidence is reported separately from build evidence.

## Definition of Done

- U1 and U2 landed. The check passes on the real configuration and fails under each U2 mutation.
- `nix fmt -- --ci`, `nix flake check`, and all four host builds pass.
- No mutation or experiment code remains in the diff.
