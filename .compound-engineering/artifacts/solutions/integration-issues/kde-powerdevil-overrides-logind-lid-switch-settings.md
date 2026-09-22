---
title: KDE Powerdevil overrides systemd-logind's lid and power-key settings
date: "2026-09-23"
category: integration-issues
module: KDE Plasma power management (Powerdevil vs systemd-logind)
problem_type: integration_issue
component: power-management
severity: high
symptoms:
  - "services.logind.settings.Login.HandleLidSwitch (and the analogous HandleLidSwitchExternalPower/HandleLidSwitchDocked, or the power/suspend/hibernate-key equivalents) render correctly into /etc/systemd/logind.conf and pass every build-time check, but have no effect while a Plasma session is running"
  - "Closing the lid, or pressing the power/suspend/hibernate key, on the real machine follows Powerdevil's own default profile instead of the declared logind policy"
root_cause: wrong_api
resolution_type: config_change
tags: ["kde-plasma", "powerdevil", "systemd-logind", "lid-switch", "power-management", "nixos"]
---

# KDE Powerdevil overrides systemd-logind's lid and power-key settings

## Problem

On a NixOS host running the default Plasma desktop (`services.desktopManager.plasma6.enable`), declaring `services.logind.settings.Login.HandleLidSwitch = "suspend-then-hibernate";` (or `HandleLidSwitchExternalPower`, `HandleLidSwitchDocked`, or the power/suspend/hibernate-key equivalents) renders exactly as expected into `/etc/systemd/logind.conf`, and any build-time check reading that file passes. The declared behavior still does not happen on the running desktop.

## Symptoms

- The materialized `logind.conf` carries exactly the declared `Handle*` keys, confirmed by a passing flake check.
- Closing the lid (or pressing the relevant key) on real hardware follows Powerdevil's own default per-profile action, not the declared systemd-logind policy.

## What Didn't Work

Assuming `services.logind.settings.Login` was the whole mechanism, since it is the option nixpkgs documents for exactly this purpose and the module does render it into the file `systemd-logind` reads (nixpkgs `nixos/modules/system/boot/systemd/logind.nix`, not a path in this repo: `environment.etc."systemd/logind.conf".text = utils.systemdUtils.lib.settingsToSections config.services.logind.settings`). Every build-time signal available from that layer says the declaration is correct.

## Solution

KDE Powerdevil (upstream `KDE/powerdevil` at `invent.kde.org`, not a path in this repo — `daemon/powerdevilpolicyagent.cpp`, `setupSystemdInhibition()`) unconditionally calls `logind.Inhibit("handle-power-key:handle-suspend-key:handle-hibernate-key:handle-lid-switch", "PowerDevil", "KDE handles power events", "block")` the moment its D-Bus service registers — for the entire duration of any running Plasma session. A `block`-mode inhibitor on those keys means systemd-logind never executes its own configured `Handle*` action on a raw event; Powerdevil decides the action itself and only calls back into logind with an explicit method (e.g. `SuspendThenHibernate()`) when it chooses to. The declared logind settings are therefore consulted only when nothing holds that inhibitor — before login, or when Powerdevil is not running.

Configure Powerdevil directly instead of, or in addition to (as a defense-in-depth fallback for the no-session case), systemd-logind. Its per-profile settings live in `~/.config/powerdevilrc`, in a `SuspendAndShutdown` group nested under each profile (`AC`, `Battery`, `LowBattery`):

- `LidAction` (int; `PowerDevil::PowerButtonAction`: `NoAction=0`, `Sleep=1`, `Hibernate=2`, ...)
- `SleepMode` (int; `PowerDevil::SleepMode`: `SuspendToRam=1`, `HybridSuspend=2`, `SuspendThenHibernate=3`)
- `InhibitLidActionWhenExternalMonitorPresent` (bool, upstream default `true`) — Powerdevil's own, separate "an external monitor suppresses the lid action" check. It is independent of systemd-logind's analogous but broader `manager_is_docked_or_external_displays()` (upstream systemd, `src/login/logind-core.c`, not a path in this repo), which also treats any connected external display as "docked."

`LidAction=Sleep` (`1`) together with `SleepMode=SuspendThenHibernate` (`3`) reproduces the exact composite suspend-then-hibernate behavior that a shallow reading of the `PowerButtonAction` enum alone would suggest is unavailable — that enum's `Hibernate` value is a different, non-composite action; the composite behavior lives in the separate `SleepMode` field, read together with `LidAction=Sleep`.

Write these with `kwriteconfig6 --file powerdevilrc --group <Profile> --group SuspendAndShutdown --key <Key> ...`, matching this repo's existing pattern for `powerdevilrc` in `home/h82/kde/session.nix`. See `home/h82/kde/power-lid.nix` for the applied fix (host-scoped via `osConfig.networking.hostName`, since `home-manager.users.h82` is shared unconditionally across every host).

## Why This Works

The inhibitor, not the option, decides which subsystem is authoritative. Reading only the option surface (what NixOS renders) misses that a downstream consumer — an entirely separate daemon with its own D-Bus lifecycle — can hold an exclusive lock on the event this option claims to control. The fix works because it configures the component that upstream evidence shows is actually asking systemd-logind to step aside, rather than the component whose configuration surface merely looks correct.

## Prevention

- When a NixOS option under `services.logind.settings.Login` (or a historical `services.logind.<key>` alias) is meant to change lid/power/suspend/hibernate-key behavior on a host running a desktop environment, check first whether that desktop's own power daemon takes an inhibitor over the same keys (Powerdevil for Plasma; an equivalent daemon exists for GNOME and others). Read the daemon's actual source for the inhibitor call and its `what` string — do not infer this from end-user documentation, which describes the option in isolation.
- Prove the mechanism against the materialized artifact the desktop environment actually reads (here, the Home Manager activation script that renders `powerdevilrc`), not only the systemd-side config file. A check that only reads `logind.conf` would have stayed green while this exact bug shipped.
- `tests/logind-lid-switch.nix` in this repository asserts both surfaces materialize the intended values for exactly this reason.

## Related Issues

- GitHub issue #57 (this repository)
- KDE Powerdevil upstream (`invent.kde.org/plasma/powerdevil`, `master` branch, read at this repo's nixpkgs pin): `daemon/powerdevilpolicyagent.cpp`, `PowerDevilProfileSettings.kcfg`, `daemon/powerdevilenums.h`, `daemon/actions/bundled/handlebuttonevents.cpp`, `daemon/actions/bundled/suspendsession.cpp`
- systemd `src/login/logind-core.c`, `manager_is_docked_or_external_displays()`
