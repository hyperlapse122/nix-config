---
title: Weekly Rootless Podman Prune Timer - Plan
type: feat
date: 2026-10-06
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Weekly Rootless Podman Prune Timer - Plan

## Goal Capsule

- **Objective:** Rootless Podman storage on NixOS hosts no longer grows without bound: stopped containers, unused networks, and dangling images are collected every week without the user running anything.
- **Means:** A systemd user service and weekly timer, both named `podman-prune`, declared in `modules/nixos/services/podman.nix` under `my.podman.enable` (KTD1, KTD2).
- **Authority:** This plan's R-IDs govern behavior; KTDs govern mechanism. `AGENTS.md` governs repository conventions and verification.
- **Stop conditions:** Stop if `podman system prune --force` in the pinned Podman removes named volumes or images that a container still uses.
- **Execution profile:** One module change, an evaluation check, and a NixOS VM test that runs the service as a user.
- **Finishing:** The implementer lands the change; the user observes the timer on a real host after their own `nr switch`.

Source: [issue #68](https://github.com/hyperlapse122/nix-config/issues/68).

## Product Contract

### Summary

Add a weekly systemd user timer on NixOS hosts that runs `podman system prune --force` against each user's rootless storage. Cover it with an evaluation check of the rendered units and a VM test showing that a stopped container and a dangling image are gone after the service runs.

### Problem Frame

Local development leaves stopped containers, throwaway networks, and untagged images in rootless Podman storage under `~/.local/share/containers`. Nothing removes them, so the home filesystem fills over time. The legacy dotfiles ran a weekly `podman-prune` user timer; the NixOS migration dropped it.

### Requirements

- R1. On every NixOS host with `my.podman.enable`, a systemd user timer fires weekly and runs a Podman prune for the user's rootless storage.
- R2. The prune removes stopped containers, unused networks, and dangling images.
- R3. The prune keeps named and anonymous volumes, and images that a container still uses.
- R4. A run missed while the machine was off or the user was logged out runs at the next opportunity.
- R5. A host with `my.podman.enable = false` gets no prune units.

### Scope Boundaries

- Volume pruning is out of scope (R3, KTD3).
- Rootful Podman storage is out of scope: the rootful socket is disabled on every host.
- Non-NixOS hosts are out of scope: this flake does not install Podman there, and `my.podman` is a NixOS option.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **A systemd user timer, not `virtualisation.podman.autoPrune`.** nixpkgs' `autoPrune` declares a system service that runs as root and `requires = [ "podman.service" ]`, so it prunes rootful storage only, which holds nothing here. A user timer runs in each user's manager against that user's storage. Declaring it through NixOS `systemd.user.services` and `systemd.user.timers` installs it for every user, which is harmless for a user without containers. Governs R1, R2.
- KTD2. **Declare it in the NixOS Podman module, not Home Manager.** `modules/nixos/services/podman.nix` already owns the `my.podman.enable` gate, and `config.virtualisation.podman.package` is the wrapped Podman whose `PATH` includes `/run/wrappers` for the setuid `newuidmap`/`newgidmap` that rootless storage needs. A NixOS user service sets its own `PATH` from its `path` option, so a bare `pkgs.podman` would lose those wrappers. Home Manager cannot read `my.podman.enable`. Governs R1, R5.
- KTD3. **Run only `podman system prune --force`.** Without `--all` it removes dangling images only, so images kept for later use survive; without `--volumes` it keeps every volume, so a development database volume is never lost. It also removes unused pods and build cache. The legacy units also ran `podman volume prune --force`, which removes named volumes too; that is dropped. No `--filter until=` age guard: it filters on creation time, so it would not spare a long-lived container stopped yesterday, and the request is to collect stopped containers. Governs R2, R3.
- KTD4. **Timer: `OnCalendar = "weekly"`, `Persistent = true`, `RandomizedDelaySec = "1h"`, `WantedBy = [ "timers.target" ]`.** `Persistent` makes a missed run fire when the user manager next starts (R4), matching the legacy timer and nixpkgs `autoPrune`. The service is `Type = "oneshot"` and is not wanted by any target, so only the timer starts it. Governs R1, R4.
- KTD5. **Run only in the configured account's user manager.** NixOS user units are installed for every user manager, including the display manager greeter's, and only the configured account gets subordinate ID ranges. The service sets `ConditionUser = config.my.user.name` so other user managers skip it instead of creating container storage or failing. Governs R1.

### Research

- `nixos/modules/virtualisation/podman/default.nix` in the pinned nixpkgs: `autoPrune` runs `podman system prune -f` from a root `systemd.services.podman-prune` with `requires = [ "podman.service" ]`; its timer sets `Persistent = true` and `RandomizedDelaySec = 1800`. The `package` option's `apply` adds `"/run/wrappers"` and `config.systemd.package` to `extraPackages`.
- Legacy dotfiles `home/dot_config/systemd/user/podman-prune.service` ran `podman system prune --force` and `podman volume prune --force`; `podman-prune.timer` used `OnCalendar=Mon 03:00`, `Persistent=true`, `RandomizedDelaySec=1h`.
- `modules/nixos/profile.nix` sets `podman.enable = lib.mkDefault true`, so every production configuration enables the trait; `tests/lib/configurations.nix`'s `withTrait` re-evaluates a configuration with the trait forced off for the negative branch.
- `tests/podman-registry-auth.nix` is the existing Podman VM test: it imports `modules/nixos/services/podman.nix` directly with a `h82` user and runs Podman through `su - h82`.
- Learnings applied: assert materialized unit text, not option values (`nix-check-reads-option-value-not-materialized-output.md`); a unit masked to `/dev/null` passes an existence test (`nix-check-unit-existence-passes-for-masked-unit.md`); every assertion must fail under a mutation (`mutation-testing-reveals-decorative-nix-check-assertions.md`).

- `tests/desktop-ssh-session.nix` runs commands as the user with `runuser` and explicit `XDG_RUNTIME_DIR` and `DBUS_SESSION_BUS_ADDRESS`. NixOS `su` starts no systemd session, so Podman run through `su -` before the user manager exists records `/tmp/storage-run-<uid>` as its run root, and a later run with `XDG_RUNTIME_DIR=/run/user/<uid>` fails Podman's database configuration check.

### Assumptions

- Weekly cadence with a one-hour random delay is acceptable; the exact weekday and hour do not matter.
- Removing every stopped container weekly is acceptable, as the legacy timer did; a container meant to be kept is recreated from its compose file or devcontainer spec.

---

## Implementation Units

### U1. Declare the user prune service and timer

- **Goal:** Every NixOS configuration with `my.podman.enable` renders `podman-prune.service` and `podman-prune.timer` user units.
- **Requirements:** R1, R2, R3, R4, R5; KTD1-KTD5.
- **Dependencies:** none.
- **Files:**
  - `modules/nixos/services/podman.nix`
  - `tests/podman-containers.nix`
- **Approach:**
  1. Inside the existing `lib.mkIf cfg.enable` block, add `systemd.user.services.podman-prune` (oneshot, `ConditionUser` per KTD5, `ExecStart` running `${config.virtualisation.podman.package}/bin/podman system prune --force`) and `systemd.user.timers.podman-prune` per KTD4.
  2. Add a short comment giving KTD1's reason for a user timer over `autoPrune`, in the style of the module's existing comments.
  3. Extend `tests/podman-containers.nix` to read the rendered unit files (`systemd.user.units."podman-prune.service".unit` and `."podman-prune.timer".unit`) per production and bootstrap entry, and to add a negative branch through `configurations.withTrait "my.podman.enable"`.
- **Patterns to follow:** the trait split in `tests/printing.nix`; the collect-every-failure builder shape already in `tests/podman-containers.nix`.
- **Test scenarios:**
  - Each enabled configuration's rendered service file contains `Type=oneshot`, `ConditionUser=` naming `my.user.name`, and an `ExecStart` whose binary is `virtualisation.podman.package`'s `bin/podman` with `system prune --force`, and contains neither `--volumes` nor `--all`.
  - The `ExecStart` binary exists and is executable.
  - Each enabled configuration's rendered timer file contains `OnCalendar=weekly`, `Persistent=true`, and `RandomizedDelaySec=1h`, and the timer unit is wanted by `timers.target`.
  - A configuration with `my.podman.enable = false` has no `podman-prune.service` or `podman-prune.timer` user unit.
  - Mutations, each turning the check red: removing `Persistent`; adding `--volumes`; changing `ExecStart` to `pkgs.podman`; moving the units outside the `mkIf`.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.podman-containers` passes, and each mutation above makes it fail.

### U2. Prove the prune collects rootless garbage in a VM

- **Goal:** A NixOS VM test shows that starting `podman-prune.service` in `h82`'s user manager removes a stopped container and a dangling image and keeps a named volume and a tagged image.
- **Requirements:** R1, R2, R3; KTD1, KTD2, KTD3, KTD5.
- **Dependencies:** U1.
- **Files:**
  - `tests/podman-prune.nix` (new)
  - `tests/vm-checks.nix`
- **Approach:**
  1. Build a node like `tests/podman-registry-auth.nix`'s: import `modules/nixos/services/podman.nix` and the shared host options it now reads, declare `h82` as a normal user, enable `my.podman`, and enable lingering for `h82` so its user manager runs without a login.
  2. Wait for `user@1000.service`, then run every Podman and `systemctl --user` command as `h82` through `runuser` with `XDG_RUNTIME_DIR` and `DBUS_SESSION_BUS_ADDRESS` set, never `su -`, so seeding and the service share one run root.
  3. Seed rootless storage offline: `podman load` two small `pkgs.dockerTools` images that differ in content, so their IDs differ; keep one tagged and untag the other so it is dangling; create and stop a container from the tagged image; create a named volume.
  4. Assert the timer is active in `h82`'s user manager, start `podman-prune.service` there, wait for it to finish, and assert the expected objects are gone or kept.
  5. Register the test in `tests/vm-checks.nix`.
- **Patterns to follow:** `tests/podman-registry-auth.nix` for node shape; the `runuser` helper in `tests/desktop-ssh-session.nix` for commands in the user session.
- **Test scenarios:**
  - Before the run, `podman ps -a` lists the stopped container and `podman images --filter dangling=true` lists one image.
  - After the run, the stopped container and the dangling image are gone; the tagged image and the named volume remain.
  - `systemctl --user list-timers` for `h82` lists `podman-prune.timer`.
  - The service unit's result is `success`.
- **Verification:** `nix build --no-link .#vmChecks.podman-prune` passes. Mutation: replacing the `ExecStart` with `true` makes the test fail on the leftover container.

---

## Verification Contract

| Gate | Command |
| --- | --- |
| Formatting | `nix fmt -- --ci` |
| Flake checks | `nix flake check` |
| Focused check | `nix build --no-link .#checks.x86_64-linux.podman-containers` |
| Focused VM test | `nix build --no-link .#vmChecks.podman-prune` |
| NixOS VM tests | `nix build --no-link .#vmChecks.all` |
| Host outputs | Build every `nixosConfigurations`, `homeConfigurations`, and `systemConfigs` output per `AGENTS.md` |

Do not run `nixos-rebuild switch` or `nr switch` as validation.

## Definition of Done

- U1 and U2 are landed, and each listed mutation was run and reverted.
- Every gate in the Verification Contract passes.
- No experimental or abandoned edits remain in the diff.
