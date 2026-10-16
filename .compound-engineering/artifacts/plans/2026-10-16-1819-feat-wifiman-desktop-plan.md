---
title: WiFiman Desktop on macOS and NixOS hosts - Plan
type: feat
date: 2026-10-16
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# WiFiman Desktop on macOS and NixOS hosts - Plan

## Goal Capsule

- **Objective:** The user can open UniFi WiFiman Desktop, with its network scanner, speed test, and Teleport working, on the MacBook and on the NixOS desktop after an ordinary rebuild, with no manual installer.
- **Means:** a Homebrew cask on macOS (KTD1) and a repackaged upstream `.deb` plus a root system service on NixOS (KTD2, KTD3).
- **Authority:** this plan, then `AGENTS.md`, then existing patterns in `packages/chatgpt.nix`, `modules/shared/darwin-apps.nix`, `modules/nixos/services/proton-vpn.nix`, and `tests/winbox.nix`.
- **Stop conditions:** stop and report if the upstream `.deb` cannot be patched to start on NixOS, or if the daemon ignores `BASE` and still writes its state beside its executable (KTD4).
- **Execution profile:** `ce-work` implements and verifies locally; `lfg` reviews, commits, and opens the PR.

---

## Product Contract

### Summary

Install WiFiman Desktop declaratively on every macOS host through the `wifiman` Homebrew cask, and on NixOS hosts as a Nix package built from Ubiquiti's `.deb`, behind a trait the NixOS profile turns on. On NixOS a root systemd service runs the bundled `wifiman-desktopd` daemon, which the GUI talks to on `127.0.0.1:63150`. A release helper keeps the Linux pin current through the existing update workflow.

### Problem Frame

WiFiman Desktop is a two-part app: a Tauri GUI and a root network daemon. The upstream Linux `.deb` relies on a `postinst` script that copies a systemd unit into `/etc/systemd/system`, and its binaries expect `/lib64/ld-linux-x86-64.so.2`; neither works on NixOS. The daemon also writes its log, Teleport connection list, and WireGuard config into its own directory, which is read-only in the Nix store. The repository installs every app declaratively, and `tests/darwin-config.nix` fails when a NixOS user package has no macOS decision, so the two platforms have to be added together.

### Key Decisions

- **Install on both macOS and Linux hosts.** (session-settled: user-directed — chosen over installing on one platform only: the user asked for both.) Governs R1, R2.
- **"Linux host" means NixOS hosts.** `AGENTS.md` scopes GUI apps to NixOS hosts; non-NixOS Linux hosts get the user environment without the desktop, and none exists in `hosts/` today. Governs R2.
- **The NixOS side sits behind a trait that the profile turns on.** `AGENTS.md` has hosts differ only through traits, and every service module under `modules/nixos/services/` has one; a root network daemon follows the same rule. Governs R2, R3.

### Requirements

**Installation**

- R1. Every macOS host installs WiFiman Desktop from the `wifiman` Homebrew cask.
- R2. Every NixOS host with `my.wifiman.enable` set, which the NixOS profile sets by default for production and bootstrap alike, has a `wifiman-desktop` user package with `bin/wifiman-desktop` and `share/applications/wifiman-desktop.desktop`; a host with it unset has neither the package nor the service.

**NixOS daemon**

- R3. Every NixOS host with the trait runs `wifiman-desktop.service` as root at boot, executing the packaged `wifiman-desktopd` with a writable state directory, restarting on failure.
- R4. The daemon finds the tools it shells out to: `sh`, `awk`, `iw`, `ip`, `ifconfig`/`netstat`, `nmcli`, `resolvconf`, the host's firewall tool, and its bundled `wg`, `wg-quick`, and `wireguard-go`; the GUI finds `iw` and `awk` for its own `iw phy` query.

**Updates**

- R5. A `wifiman-desktop-release` helper resolves the newest WiFiman Desktop version from Ubiquiti's releases API and writes `packages/wifiman-desktop-version.json` with its SRI hash, refusing downgrades.
- R6. The scheduled update workflow runs the helper and commits a bump the same way it does for ChatGPT.

### Scope Boundaries

- Non-NixOS Linux hosts get nothing; they carry no GUI apps.
- aarch64 Linux is out: upstream ships only an amd64 `.deb`.
- No autostart entry; WiFiman opens on demand.
- No firewall ports are opened. The scanner finds devices by ARP, ping, NDP, and a unicast probe from a connected UDP socket to each device's port 10001 (`net.Dial` in the daemon's `discovery/ubiquiti.sendUdpPacket`), so the stateful firewall already admits every reply.

### Sources

- Upstream downloads: `https://desktop.wifiman.com/wifiman-desktop-<version>-amd64.deb`, `-arm64.pkg`, `-amd64.pkg`.
- Homebrew cask `wifiman` (version 1.3.0), whose livecheck posts `query { releases(tags: ["wifiman"]) { items { title version } } }` to `https://community.svc.ui.com/` and keeps items whose title contains `Desktop`.
- `.deb` 1.3.0 contents, inspected during planning: `usr/bin/wifiman-desktop` (Tauri, needs `libwebkit2gtk-4.1`, `libsoup-3.0`, `libgtk-3`; dlopens the tray library), `usr/lib/wifiman-desktop/{wifiman-desktopd,wg,wireguard-go,wg-quick,wg_report.sh,.env,wifiman-desktop.service}`, icons under `usr/share/icons/hicolor`, and `usr/share/applications/wifiman-desktop.desktop`. Control `Depends: net-tools, iw, resolvconf, libayatana-appindicator3-1, libwebkit2gtk-4.1-0, libgtk-3-0`. The unit runs `/usr/lib/wifiman-desktop/wifiman-desktopd` as root with `Restart=always`, `RestartSec=30`. The `.deb` 1.3.0 SRI hash is `sha256-K7dbc8CS5DWSu9QIQWKPIiAAvqlaKDiar+hK2vJ5zXg=`.
- The daemon takes its base directory from `$BASE`, falling back to `osext.ExecutableFolder()`, and builds `.env`, `service.json`, `utun.conf`, `wifiman-desktop.log`, and its `wg`/`wg-quick` command paths from it. The bundled `wg-quick` prepends its own resolved directory to `PATH`.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **macOS uses the `wifiman` core cask through the `apps` mapping.** Add `wifiman-desktop.cask = "wifiman"` to `modules/shared/darwin-apps.nix`, keyed by the NixOS pname so `darwin-config` sees the decision. Not `darwinOnly`, which is for casks with no NixOS counterpart. Governs R1.
- KTD2. **NixOS repackages the upstream `.deb` in `packages/wifiman-desktop.nix`, following `packages/chatgpt.nix`.** nixpkgs has no `wifiman`. Use `dpkg`, `autoPatchelfHook`, and `wrapGAppsHook3` with `webkitgtk_4_1`, `libsoup_3`, `gtk3`, `glib`, `cairo`, `gdk-pixbuf`, and `dbus`. The tray library is dlopened, so `libayatana-appindicator` goes in `appendRunpaths`, as `packages/chatgpt.nix` does for libGL. The wrapper prefixes `PATH` with `iw` and `gawk` through `gappsWrapperArgs`. Keep `usr/lib/wifiman-desktop` intact under `$out/lib/wifiman-desktop`. `x86_64-linux` only. Governs R2, R4.
- KTD3. **The trait and the daemon live in a NixOS module, `modules/nixos/services/wifiman.nix`, imported by `modules/nixos/profile.nix`.** `my.wifiman.enable` is declared in `modules/shared/host.nix` beside the other traits, because Home Manager reads it too, and the profile sets it with `lib.mkDefault true`. Under the trait the module declares `systemd.services.wifiman-desktop` with the upstream unit's semantics: root, `After=network.target`, `WantedBy=multi-user.target`, `Restart=always`, `RestartSec=30`. Its `path` carries `${pkg}/lib/wifiman-desktop`, `bash`, `gawk`, `iw`, `iproute2`, `nettools`, `procps`, `config.networking.networkmanager.package`, `config.networking.resolvconf.package`, and `config.networking.firewall.package`. An `ExecStart` unit gets no `bash` on its default `path`, and the daemon runs `sh -c` through `PATH`. The GUI goes in the `gui [ ... ]` list in `home/h82/default.nix`, gated on `config.my.wifiman.enable`. Both import the same `packages/wifiman-desktop.nix` so GUI and daemon versions match. Governs R2, R3, R4.
- KTD4. **The daemon runs with `BASE` set to its state directory.** The service sets `StateDirectory=wifiman-desktop` and `Environment=BASE=/var/lib/wifiman-desktop`. An `ExecStartPre` symlinks `.env`, `wg`, `wg-quick`, and `wireguard-go` from `${pkg}/lib/wifiman-desktop` into that directory on each start, replacing stale links. It copies `wg_report.sh` instead with mode 0755, because the daemon runs `os.Chmod` on it before use and a link into the store would fail with `EROFS`. Writable files (`service.json`, `utun.conf`, the log) then land in the state directory and survive upgrades. Governs R3, R4.
- KTD5. **`scripts/wifiman-desktop-release` mirrors `scripts/chatgpt-release`.** It posts the GraphQL query above, keeps the highest numeric version among items whose title contains `Desktop`, builds the `.deb` URL, and hashes it with a fetch-and-hash command that the `WIFIMAN_DESKTOP_RELEASE_FETCH` and `WIFIMAN_DESKTOP_RELEASE_PREFETCH` env vars override so tests run offline. Upstream publishes no checksum, so the helper downloads and hashes the file. The pin stores `version`, `sha256`, and `hash`. Governs R5.

### Assumptions

- Upstream keeps the `wifiman-desktop-<version>-amd64.deb` URL scheme; versions 1.1.3 and 1.3.0 both follow it.
- The daemon's self-updater fails harmlessly on NixOS because it cannot write the store or run `dpkg`; the pin is the update path.
- On macOS the cask's own `pkg` installs the privileged helper and launchd job, so nix-darwin needs nothing beyond the cask.

### Risks

| Risk | Mitigation |
| --- | --- |
| The GUI fails at runtime from a missing GIO module or webkit dependency that autoPatchelf cannot see | `wrapGAppsHook3`; the check runs `ldd` on both binaries and reads the GUI's RUNPATH for the tray library |
| The daemon ignores `BASE` | U2's execution note confirms it before the module settles; the stop condition covers a daemon that ignores it |
| The update workflow pins a broken release | The helper refuses downgrades; the workflow's pre-push verification builds the hosts before it pushes the bump to main, as it does for ChatGPT |

---

## Implementation Units

### U1. Package WiFiman Desktop for NixOS

- **Goal:** a buildable `wifiman-desktop` package with patched GUI and daemon binaries.
- **Requirements:** R2, R4, KTD2.
- **Files:** `packages/wifiman-desktop.nix`, `packages/wifiman-desktop-version.json`, `flake.nix` (expose `packages.x86_64-linux.wifiman-desktop`).
- **Approach:** model on `packages/chatgpt.nix`: fetch from the pin, unpack with `dpkg-deb`, install `usr/share` and `usr/lib/wifiman-desktop`, and install `usr/bin/wifiman-desktop` to `$out/bin`. Let `patchShebangs` fix `wg-quick` and `wg_report.sh`. Seed the pin with 1.3.0 and the hash in Sources.
- **Test scenarios:** covered by U4.
- **Verification:** `nix build --no-link .#wifiman-desktop` succeeds; `ldd` on `bin/wifiman-desktop` and `lib/wifiman-desktop/wifiman-desktopd` reports no `not found`.

### U2. Trait and daemon on NixOS hosts

- **Goal:** `wifiman-desktop.service` runs on every NixOS host with the trait.
- **Requirements:** R2, R3, R4, KTD3, KTD4.
- **Dependencies:** U1.
- **Files:** `modules/shared/host.nix`, `modules/nixos/services/wifiman.nix`, `modules/nixos/profile.nix`.
- **Approach:** declare the trait and the service per KTD3 and KTD4, following `modules/nixos/services/proton-vpn.nix`; keep comments to the non-obvious constraints, such as why `BASE` points at the state directory.
- **Execution note:** before settling the module, run the patched daemon briefly as an unprivileged user with `BASE` set to a scratch directory holding the KTD4 symlinks, and confirm `wifiman-desktop.log` appears there; it needs no network for that.
- **Test scenarios:** covered by U4.
- **Verification:** every `nixosConfigurations.<host>` evaluates and builds.

### U3. Add the GUI to the user environment and the cask to macOS

- **Goal:** the app appears on both platforms.
- **Requirements:** R1, R2, KTD1, KTD3.
- **Dependencies:** U1, U2.
- **Files:** `home/h82/default.nix`, `modules/shared/darwin-apps.nix`.
- **Approach:** append the package to the existing `gui [ ... ]` list that holds Claude Desktop and ChatGPT, gated on the trait; add the `apps` entry per KTD1. Find how an existing trait such as `my.t3.desktop` reaches Home Manager on a NixOS host and follow it.
- **Test scenarios:** `darwin-config` passes with the mapping and fails without it, because `wifiman-desktop` would then be a NixOS user package with no macOS decision.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.darwin-config`.

### U4. Check what the NixOS hosts materialize

- **Goal:** a regression check that reads the built package and units.
- **Requirements:** R2, R3, R4.
- **Dependencies:** U2, U3.
- **Files:** `tests/wifiman.nix`, `flake.nix` (register under `checks` and in `hostClosureChecks`).
- **Approach:** follow `tests/winbox.nix` over `tests/lib/configurations.nix`, reading the materialized output, never option values, and collecting every failure before exiting. Read the mutation-testing learnings that `AGENTS.md` lists before writing it.
- **Test scenarios:**
  - Each configuration's user packages include `wifiman-desktop` with `bin/wifiman-desktop` and `share/applications/wifiman-desktop.desktop` (use `assertUserPackage` or its equivalent).
  - The unit file `wifiman-desktop.service` in the system's `etc/systemd/system` is a regular file, not a link to `/dev/null`, and has `ExecStart` naming that package's `lib/wifiman-desktop/wifiman-desktopd`.
  - The unit sets `BASE=/var/lib/wifiman-desktop` and `StateDirectory=wifiman-desktop`, and its `ExecStartPre` script copies `wg_report.sh` rather than linking it.
  - `multi-user.target.wants` contains `wifiman-desktop.service`.
  - The unit's `Environment=PATH` contains the package's `lib/wifiman-desktop`, `bash`, `gawk`, `iw`, `iproute2`, and NetworkManager store paths, a `resolvconf`, and the host's firewall package.
  - With the trait forced off through `configurations.withTrait "my.wifiman.enable"`, as `tests/printing.nix` does, the user packages lack `wifiman-desktop` and no `wifiman-desktop.service` runs `wifiman-desktopd`.
  - `ldd` on both binaries reports no `not found`, and the GUI's RUNPATH (`patchelf --print-rpath`) names a store path containing `libayatana-appindicator3.so.1`.
  - The GUI wrapper puts an `iw` store path on `PATH`.
  - Mutation: dropping the service, pointing `ExecStart` elsewhere, removing `BASE`, removing `iw` from `path`, or removing the tray library from the RUNPATH each turns the check red.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.wifiman` passes, and `check-shards-guard` passes.

### U5. Release helper and update workflow

- **Goal:** the Linux pin stays current without hand edits.
- **Requirements:** R5, R6, KTD5.
- **Files:** `scripts/wifiman-desktop-release`, `tests/test_wifiman_desktop_release.py`, `packages/agent-tools.nix`, `flake.nix` (app plus a `wifiman-desktop-release` check beside `chatgpt-release`), `.github/workflows/update-dependencies.yml`.
- **Approach:** mirror `scripts/chatgpt-release` and its test. In the workflow, add a step after ChatGPT's and a matching `chore(packages): bump wifiman-desktop to $NEW_VER` commit block.
- **Test scenarios:**
  - A fixture response with Desktop 1.3.0 and 1.2.8 plus Android 2.13.0 resolves to 1.3.0 with the URL `https://desktop.wifiman.com/wifiman-desktop-1.3.0-amd64.deb`.
  - Non-Desktop items are ignored even when their version is higher.
  - A pin already at 1.3.0 is left unchanged; a pin at 1.4.0 is not downgraded.
  - A response with no Desktop item, malformed JSON, or a failing fetch exits non-zero with a message and leaves the pin untouched.
  - A version string that is not dotted digits is skipped.
  - The SRI hash `nix store prefetch-file --json` prints is pinned with its hex digest, and prefetch output without a sha256 SRI hash fails.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.wifiman-desktop-release`; `nix run .#wifiman-desktop-release -- --dry-run` prints 1.3.0 with the hash in Sources.

---

## Verification Contract

| Gate | Command |
| --- | --- |
| Format | `nix fmt -- --ci` |
| Flake checks | `nix flake check` |
| New checks | `nix build --no-link .#checks.x86_64-linux.wifiman .#checks.x86_64-linux.wifiman-desktop-release .#checks.x86_64-linux.darwin-config` |
| Hosts shard | `nix build --no-link .#checkShards.hosts` |
| NixOS outputs | build every `nixosConfigurations.<host>.config.system.build.toplevel`, production and bootstrap |
| macOS outputs | left to CI's `build-darwin` job; no macOS builder here |

Hardware verification on the NixOS desktop (launch, scan, speed test, Teleport) is reported separately from build evidence, per `docs/verification.md`.

## Definition of Done

- R1 to R6 hold and each unit's verification passes.
- `wifiman` and `wifiman-desktop-release` checks are registered and in a shard.
- No scratch or abandoned-attempt code remains in the diff.
