---
title: Autostart Claude, ChatGPT, and Tailscale Tray - Plan
type: feat
date: 2026-10-01
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Autostart Claude, ChatGPT, and Tailscale Tray - Plan

## Goal Capsule

- **Objective:** After a Plasma login on a production NixOS host, Claude Desktop, ChatGPT, and the Tailscale tray are running with no manual launch, and the Tailscale tray can change Tailscale settings without sudo.
- **Means:** Home Manager-owned XDG autostart entries beside the existing four in `home/h82/desktop/kde/autostart.nix` (KTD1–KTD3), plus a Tailscale operator preference (KTD4).
- **Authority:** the user's answers in this session (R1–R6 scope, operator on), then this plan, then repository conventions in `AGENTS.md`.
- **Stop conditions:** stop and report if `tailscale systray` cannot run from the system Tailscale package, or if `tailscale-provisioning` cannot pass with the operator flag in both up and set flags.
- **Execution profile:** Lightweight; three units; Nix module edits plus check updates; no hardware actions, no `nr switch`.
- **Finishing:** `ce-work` implements and verifies locally; the `lfg` pipeline reviews, ships the PR, and watches CI.

---

## Product Contract

### Summary

Add three login autostart entries: Claude Desktop started without its window, ChatGPT started normally, and the Tailscale system tray. Make the user a Tailscale operator so the tray's controls work.

### Problem Frame

The user expects ChatGPT to start at login "like Claude", but Claude Desktop has no autostart entry in this repository, and Plasma starts with an empty session (`loginMode=emptySession` in `home/h82/desktop/kde/session.nix`), so nothing relaunches it. Tailscale runs as a system daemon with no tray, so its status and controls are invisible in the desktop.

### Key Decisions

- **Scope covers Claude Desktop, ChatGPT, and the Tailscale tray.** (session-settled: user-directed — chosen over ChatGPT only: the user chose both apps when told Claude had no entry, then added Tailscale.) Governs R1, R2, R3.
- **Start in the background where the app supports it.** (session-settled: user-directed — chosen over always opening a window: the user asked for background start when possible.) Governs R1, R2.
- **The user becomes a Tailscale operator.** (session-settled: user-directed — chosen over a read-only tray: without operator rights the tray cannot toggle the connection or pick an exit node.) Governs R4.

### Requirements

Autostart

- R1. Claude Desktop starts at login without opening its main window.
- R2. ChatGPT starts at login; it opens its window, because the app offers neither a tray nor a hidden start (KTD2).
- R3. The Tailscale system tray starts at login on every production host that runs `tailscaled`.
- R5. Every new entry follows the existing entry shape: Home Manager-owned and forced, `Type=Application`, `Hidden=false`, `NoDisplay=true`, `X-KDE-autostart-phase=2`, and absent from bootstrap configurations.

Tailscale

- R4. The primary user is the Tailscale operator on every host that enables `my.tailscale`, so `tailscale` commands and the tray change settings without sudo.

Documentation

- R6. `docs/provisioning.md` and `docs/verification.md` describe the new entries and the operator preference.

### Scope Boundaries

- No restart-on-failure drop-ins for the new entries (KTD5).
- No autostart on non-NixOS hosts; `home/h82/desktop/` is NixOS-only already.

---

## Planning Contract

### Key Technical Decisions

- KTD1. Claude Desktop runs `<claude-desktop>/bin/claude-desktop --startup`. The app's main bundle reads `process.argv.includes("--startup")` and, when set, skips showing the main window, which is the background start R1 asks for. Governs R1.
- KTD2. ChatGPT runs `<chatgpt>/bin/chatgpt` with no flag. Its `app.asar` parses no hidden-start argument, so it always opens its window at launch. The bundle does contain a status-item `Tray`, created only when a runtime flag enables it. When that flag is on, the tray keeps the app alive after the window closes, but it does not skip the first window. Governs R2.
- KTD3. The Tailscale tray runs `<tailscale>/bin/tailscale systray`, with `<tailscale>` the system's `services.tailscale.package`. `lib/nixos-host.nix` passes it to Home Manager through `home-manager.extraSpecialArgs`, the way `onePasswordGui` is passed, and passes `null` when `services.tailscale.enable` is false; `autostart.nix` declares the entry only for a non-null package. This keeps the tray and daemon on one version and avoids reading `osConfig`. `tailscale configure systray --enable-startup` is not used because it writes an unmanaged file. Governs R3.
- KTD4. `modules/nixos/services/tailscale.nix` adds `--operator=${config.my.user.name}` to `nodeFlags`, which both `extraUpFlags` and `extraSetFlags` use. It must go in both. `tailscaled-autoconnect` runs `tailscale up ... ${extraUpFlags}` as root on `NeedsLogin` or `Stopped`, and `tailscale up` refuses a command that leaves out a non-default pref such as a stored operator, so a set-only operator would break unattended re-authentication. `tailscaled-set` applies the same flags on every daemon start, so already-registered nodes get the operator too. A known effect: a Disconnect from the tray leaves the node `Stopped`, and autoconnect reconnects it at the next boot, as it already does today. Governs R4.
- KTD5. No restart drop-ins. Issue #60 asked for them for Discord and Telegram only. A drop-in for the new apps would also require escaping the generated unit names, such as `app-claude\x2ddesktop@autostart.service`.
- KTD6. Entry file names are `autostart/claude-desktop.desktop`, `autostart/chatgpt.desktop`, and `autostart/tailscale-systray.desktop`. The Claude and ChatGPT packages come from the same `packages/*.nix` imports `home/h82/default.nix` uses, so the Exec path equals the installed package's store path.

### Sources

- `home/h82/desktop/kde/autostart.nix` — the existing entry pattern and the `!config.my.bootstrap` gate.
- `lib/nixos-host.nix:41-47` — `onePasswordGui` passed through `extraSpecialArgs`.
- `tests/desktop-autostart.nix` — locates entries by resolved target, checks enable, force, and body lines, and checks bootstrap absence.
- `tests/tailscale-provisioning.nix:29-37,109-112` — test nodes import only sops-nix, `secrets.nix`, and `tailscale.nix`, and the test asserts `extraUpFlags` as an exact set.
- nixpkgs `tailscaled-autoconnect` runs `tailscale up --auth-key ... ${extraUpFlags}` on `NeedsLogin|NeedsMachineAuth|Stopped`.
- nixpkgs `nixos/modules/services/networking/tailscale.nix` — `tailscaled-set` runs `tailscale set ${extraSetFlags}`.
- https://tailscale.com/docs/features/client/linux-systray — `tailscale systray`; KDE Plasma is supported through StatusNotifierItem; the tray must not run as root.

---

## Implementation Units

### U1. Operator preference and Tailscale package hand-off

- **Goal:** Make the user the Tailscale operator and expose the system Tailscale package to Home Manager.
- **Requirements:** R4; KTD3, KTD4.
- **Files:** `modules/nixos/services/tailscale.nix`, `lib/nixos-host.nix`, `tests/tailscale-provisioning.nix`, `tests/desktop-autostart.nix`.
- **Approach:** add the operator flag to `nodeFlags` (KTD4). `mkTestHost` in `tests/tailscale-provisioning.nix` imports `../modules/shared/host.nix` so `config.my.user.name` resolves on the test nodes. Its exact-set assertion then expects `--operator=<node my.user.name>` beside `--ssh` and `--accept-routes`, read from the node rather than written as a literal. Add a nullable Tailscale package argument beside `onePasswordGui`. Every fixture configuration must still build; `tests/lib/configurations.nix` goes through `mkHost`.
- **Test scenarios:**
  - On every production configuration with `services.tailscale.enable`, the materialized `tailscaled-set` unit's start script contains `--operator=h82`. The user name is read from `config.my.user.name`, not written as a literal.
  - `tailscale-provisioning` passes with the operator in `extraUpFlags`, and its RouteAll/RunSSH assertions still hold.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.desktop-autostart` and `nix build --no-link .#vmChecks.tailscale-provisioning`.

### U2. Autostart entries

- **Goal:** Declare the three entries.
- **Requirements:** R1, R2, R3, R5; KTD1, KTD2, KTD3, KTD6.
- **Dependencies:** U1.
- **Files:** `home/h82/desktop/kde/autostart.nix`, `tests/desktop-autostart.nix`.
- **Approach:** copy the existing entry shape. Claude Desktop gets `--startup`, ChatGPT gets no flag, and the Tailscale entry runs `tailscale systray` behind the non-null guard.
- **Test scenarios:**
  - Each production configuration declares enabled, forced entries at the three targets, with the existing header, `Type`, `Hidden`, and phase checks.
  - The Exec lines are exactly `Exec=<claude-desktop pkg>/bin/claude-desktop --startup`, `Exec=<chatgpt pkg>/bin/chatgpt`, and `Exec=<services.tailscale.package>/bin/tailscale systray`. The Claude and ChatGPT packages are found in the user package list, and the Tailscale package is read from the configuration.
  - Bootstrap configurations declare none of the three; extend `autostartNames`.
  - One production configuration is re-evaluated through `extendModules` with `services.tailscale.package` set to a distinct derivation, such as `pkgs.tailscale.overrideAttrs` with a marker. Its tailscale-systray Exec line must name that derivation. Without this, a hardcoded `pkgs.tailscale` would be byte-identical to the default and pass.
  - Mutation checks, per the solutions on decorative assertions: dropping `--startup`, hardcoding `pkgs.tailscale` in `autostart.nix`, or removing the bootstrap gate each turns the check red.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.desktop-autostart`.

### U3. Documentation

- **Goal:** Describe the new behavior.
- **Requirements:** R6.
- **Dependencies:** U2.
- **Files:** `docs/provisioning.md`, `docs/verification.md`, and the `desktop-autostart` header comment in `tests/desktop-autostart.nix`.
- **Approach:** extend the existing autostart paragraph in provisioning and the `desktop-autostart` and `tailscale-provisioning` descriptions in verification. In provisioning, add that operator rights let any process running as the user change Tailscale preferences, serve configuration, and exit node without sudo. Also say that a tray Disconnect is undone at the next boot by autoconnect. Add a hardware checklist item: the three apps run after login, the Claude window stays closed, the Tailscale tray icon appears and can toggle the connection without sudo, and `tailscale serve status` shows nothing unexpected.
- **Test expectation:** none, documentation only.
- **Verification:** `nix fmt -- --ci`, then reread the docs.

---

## Verification Contract

- `nix fmt -- --ci`
- `nix flake check`
- `nix build --no-link .#vmChecks.tailscale-provisioning`
- Build every `nixosConfigurations` output, production and bootstrap, as `AGENTS.md` lists.
- Hardware evidence (log in, see the tray icon) is reported separately and is not run by the agent.

## Definition of Done

- U1–U3 are done and every Verification Contract command passes.
- The PR reports hardware login verification separately, as pending, and points to the `docs/verification.md` checklist.
- `desktop-autostart` fails under each U2 mutation and passes on the final tree.
- No abandoned-attempt code remains in the diff.
