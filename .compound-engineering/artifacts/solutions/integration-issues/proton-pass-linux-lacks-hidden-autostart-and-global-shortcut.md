---
title: "Proton Pass on Linux has no hidden autostart flag or global shortcut"
date: 2026-09-26
category: integration-issues
module: "Proton Pass desktop autostart (Electron app, Home Manager/KDE)"
problem_type: best_practice
component: desktop-integration
severity: medium
applies_when:
  - "Adding or changing an autostart entry or KDE shortcut for Proton Pass"
  - "Upgrading proton-pass, when its shortcut or start-hidden behavior matters to the change"
  - "Adding another Electron app to home/h82/desktop/kde/autostart.nix and deciding whether it has a start-in-tray flag or a global hotkey"
tags:
  - proton-pass
  - electron
  - autostart
  - home-manager
  - kde-plasma
  - single-instance-lock
  - global-shortcut
  - xdg-autostart
---

# Proton Pass on Linux has no hidden autostart flag or global shortcut

## Context

A request to add Proton Pass to the KDE desktop "like the other apps", with login autostart and "KDE shortcuts", assumed two features that the Linux build of the Proton Pass desktop app does not have. The user picked "use Proton Pass's default shortcut" for the shortcut part. The app has no default global shortcut on Linux, so that choice resolved to adding no KDE shortcut. The autostart part also worked differently from the repo's other autostart entries, because the app has no flag to start hidden.

All of this was confirmed by reading the app bundle in the store, not the app's menus or documentation. Version checked: Proton Pass desktop 1.40.2 from nixpkgs `proton-pass` (`/nix/store/62d0nwbd75a8c9k6ygjya103rqdh4c3w-proton-pass-1.40.2`). Its Electron bundle `share/proton-pass/app.asar` is not compressed, so `grep -a` or a short Python scan can search it as text.

Findings for 1.40.2:

1. **No global shortcut.** `globalShortcut` does not appear anywhere in `app.asar`, so the main process registers no system-wide hotkey. The only shortcut beyond the window-scoped app-menu accelerators is Ctrl+Shift+V autotype. It is a renderer keydown handler, so it works only while the Proton Pass window has focus, and it is gated on the `PassDesktopAutotype` feature flag and a non-free plan. KDE has no app shortcut to import or rebind.
2. **No start-hidden flag.** The main process does not handle `--hidden` or any start-minimized argument. The only "Start Proton Pass at login" toggle is a macOS app-menu item, built inside an `isMac()` branch, that calls `app.setLoginItemSettings({ openAtLogin })`. Linux builds show no such toggle, and per Electron's API docs that call is not implemented on Linux anyway. An XDG autostart entry therefore opens the full window at every login. Closing the window hides it to the tray, because the app's close handler hides the window instead of quitting.
3. **Single instance with focus on relaunch.** The main process calls `app.requestSingleInstanceLock()` and registers `app.addListener('second-instance', handleActivate)`. Running `proton-pass` again while it is already running shows (and normally focuses) the existing window instead of starting a second copy.

## Guidance

- Before promising an Electron app a KDE global shortcut or a hidden autostart, search its `app.asar` for the Electron APIs involved. Menus, help pages, and the app's settings screen describe what the app offers on macOS and Windows too, and do not show whether a feature works on Linux.
- If an app registers no `globalShortcut`, there is nothing on the app side to bind. Say so plainly, and do not add a KDE shortcut that implies the app has one.
- If the user later wants a global hotkey for Proton Pass, create a KDE custom shortcut that runs `proton-pass`. Because of finding 3, this opens the app if it is closed and focuses it if it is already running. That is the whole mechanism. No D-Bus call or command-line flag is needed.
- Write the autostart `Exec=` line with no arguments. Do not copy the start-in-tray flag from a neighbouring entry: the app does not recognise one, and an Exec line with an unrecognised flag gives the reader a false idea of what happens at login.
- Record in the plan or PR that this autostart entry shows a window at login, unlike the other autostart entries (1Password, Kleopatra, Discord, Telegram), so nobody later mistakes it for a regression.

Current configuration in the repo:

- `proton-pass` is in `home.packages` (`home/h82/default.nix:26`).
- `xdg.configFile."autostart/proton-pass.desktop"` sets `force = true` and `Exec=${pkgs.proton-pass}/bin/proton-pass` with no arguments, plus `NoDisplay=true` and `X-KDE-autostart-phase=2` (`home/h82/desktop/kde/autostart.nix:79-90`). Like the other entries, it sits inside `lib.mkIf (!osConfig.my.bootstrap)` (`home/h82/desktop/kde/autostart.nix:23`), so the bootstrap host does not get it.
- The comment at `home/h82/desktop/kde/autostart.nix:24-26` explains why these entries use `force = true`: apps write these paths themselves from their own "start at login" settings. On Linux, Proton Pass never writes this file, because its only login toggle is macOS-only. `force = true` is kept anyway for consistency and in case a later version starts writing the file.
- `tests/desktop-autostart.nix` checks this entry the same way it checks the others. It fails if `proton-pass` is missing from the user packages (`tests/desktop-autostart.nix:219`) or if the entry is missing (`:220`). `present` (`:130` onward) checks that the entry is enabled and forced. `protonPassExec` (`:179-181`) requires an exact argument-free `Exec=` line. The bootstrap-leak section checks that the entry does not appear on the bootstrap host. The check is registered as `desktop-autostart` in `flake.nix:726`. During this work, all 10 mutations of the Proton Pass assertions caused the check to fail at build time.

## Why This Matters

Without looking inside the bundle, the natural move is to copy a neighbouring entry. That produces either an `Exec=proton-pass --hidden` line, whose flag the app silently ignores, or a KDE shortcut bound to an app action that does not exist. Both look correct in review and fail only at a real login or keypress, which no VM check here tests. Knowing what the app actually does also sets the user's expectations correctly: the window appears at login and closes to the tray. Anyone asked to "make it start hidden" learns that doing so needs an upstream change, not a repo change.

## When to Apply

- Adding or changing an autostart entry or KDE shortcut for Proton Pass.
- Upgrading `proton-pass` in `flake.lock`, if the behaviour described here matters for the change. A later version could add a global shortcut or a hidden-start flag.
- Adding any other Electron app to `home/h82/desktop/kde/autostart.nix`, when you need to know whether it has a start-in-tray flag or a global hotkey.

## Examples

To re-check a newer Proton Pass, find the store path and search the bundle:

```sh
pp=$(nix build --no-link --print-out-paths nixpkgs#proton-pass)   # or the path from the evaluated host
asar=$pp/share/proton-pass/app.asar

grep -a -c globalShortcut "$asar"                 # 0 on 1.40.2: no global shortcut
grep -a -c requestSingleInstanceLock "$asar"      # >0: single instance
grep -a -c "second-instance" "$asar"              # >0: relaunch shows/focuses the window
grep -a -c setLoginItemSettings "$asar"           # >0, but macOS/Windows-only in Electron
grep -a -o -e "--hidden" -e "start-minimized" -e "startMinimized" "$asar" | sort | uniq -c
```

Interpret the results carefully. If the flag search finds a match, open the surrounding code before trusting it: the text can appear in a bundled dependency without the main process reading it from `process.argv`. If `globalShortcut` starts appearing, find the accelerator string it registers before creating a matching KDE binding.

The entry this learning led to, argument-free on purpose (`home/h82/desktop/kde/autostart.nix:79-90`):

```nix
xdg.configFile."autostart/proton-pass.desktop" = {
  force = true;
  text = ''
    [Desktop Entry]
    Type=Application
    Name=Proton Pass
    Exec=${pkgs.proton-pass}/bin/proton-pass
    Hidden=false
    NoDisplay=true
    X-KDE-autostart-phase=2
  '';
};
```

Compare the flags on the neighbouring entries, which the app does support: `1password --silent` (`:33`), `discord --start-minimized` (`:59`), and `Telegram -startintray` (`:72`).
