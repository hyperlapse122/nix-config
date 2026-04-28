# H82's NixOS Configurations

**Generated:** 2026-04-28
**Commit:** 8925203
**Branch:** main

## OVERVIEW

Multi-host flake-based NixOS 25.11 config. Each host lives under `hosts/<hostname>/` and is wired into `flake.nix#nixosConfigurations`.
Shared system-level config lives in `hosts/common/`; shared user-level config lives in `home/modules/`. Per-host divergence stays inside `hosts/<hostname>/default.nix`.
Home Manager runs as a NixOS module; KDE Plasma 6 is configured via `plasma-manager`.
Reusable modules use a custom `my.*` option namespace — `my.<group>.<name>.enable` for home modules (toggled in `home/h82.nix`), `my.system.<group>.<name>.enable` for shared system modules (toggled in each host's `default.nix`).

> Currently only `jpi-vmware` exists. New hosts: NixOS only (no nix-darwin / WSL planned).

## STRUCTURE

```plain
nix-config/
├── flake.nix                  # Inputs + every nixosConfiguration entry
├── flake.lock                 # Pinned: nixpkgs 25.11, home-manager 25.11, plasma-manager, nix-vscode-extensions
├── hosts/
│   ├── common/                # Reusable, host-agnostic system modules — `my.system.*` namespace
│   │   ├── default.nix        # Aggregator
│   │   ├── base.nix           # Always-on baseline (nix flakes, allowUnfree, dbus, minimal pkgs) — no toggle
│   │   ├── users.nix          # my.system.users.h82           — h82 user account + zsh
│   │   ├── locale.nix         # my.system.locale.korean       — Asia/Seoul + ko_KR.UTF-8
│   │   ├── networking.nix     # my.system.networking.networkmanager
│   │   ├── audio.nix          # my.system.audio.pipewire      — PipeWire (ALSA + Pulse compat)
│   │   ├── ssh.nix            # my.system.ssh.server          — OpenSSH (sshd, no password / no root)
│   │   ├── desktop/plasma.nix # my.system.desktop.plasma      — Plasma 6 + SDDM Wayland + KWallet PAM
│   │   └── programs/          # my.system.programs.{nix-ld,_1password}
│   └── <hostname>/            # One directory per machine; name MUST match networking.hostName
│       ├── default.nix        # Imports ../common, flips `my.system.*.enable`, declares per-host bits (bootloader, hostname, hardware-specific overlays, stateVersion)
│       └── hardware-configuration.nix  # GENERATED per host — DO NOT MODIFY
└── home/
    ├── h82.nix                # User entrypoint (host-agnostic); flips my.*.enable toggles
    └── modules/               # Reusable, host-agnostic home-manager modules — see home/modules/AGENTS.md
```

## WHERE TO LOOK

| Task | Location |
|------|----------|
| Add a system-level package or service for ONE host | `hosts/<hostname>/default.nix` |
| Add a system-level package or service for ALL hosts | `hosts/common/<name>.nix` (gated by `my.system.<group>.<name>.enable`), then flip the toggle in each host's `default.nix`. Always-on baseline lives in `hosts/common/base.nix` (no toggle). |
| Toggle Korean locale / KDE Plasma / OpenSSH / etc. on a host | Flip `my.system.locale.korean.enable` / `my.system.desktop.plasma.enable` / `my.system.ssh.server.enable` etc. in `hosts/<hostname>/default.nix` |
| Add a user package / program (all hosts) | `home/modules/<name>.nix`, then enable in `home/h82.nix` |
| Add a VS Code extension or setting | `home/modules/editors/vscode.nix` (see `home/modules/editors/AGENTS.md`) |
| Add a KDE Plasma setting | `home/modules/desktop/plasma.nix` |
| Add an input method (fcitx5) addon | `home/modules/i18n/fcitx5.nix` |
| Bump nixpkgs / home-manager / plasma-manager / nix-vscode-extensions | `flake.lock` via `nix flake update` |
| Add a new host | See **ADDING A HOST** below |

## CONVENTIONS

- **`my.*` option namespace** — reusable modules expose `<path>.enable` and nothing else (sole exception: `vscode` adds `package`). Two slices:
  - `my.<group>.<name>.enable` for **home** modules (`home/modules/`), toggled in `home/h82.nix`. See `home/modules/AGENTS.md`.
  - `my.system.<group>.<name>.enable` for **shared system** modules (`hosts/common/`), toggled in `hosts/<hostname>/default.nix`.
  - Always-on baseline in `hosts/common/base.nix` is the **only** system file without an `enable` gate (nix flakes / allowUnfree / dbus / minimal pkgs are universal across hosts).
- **Imports are explicit `imports = [ ... ]` lists**, not auto-discovered. Aggregated via `default.nix` per directory (`hosts/common`, `home/modules`, `editors`, etc.).
- **`with pkgs; [ ... ]`** style for package lists.
- **No flake-parts / snowfall / devshell / devenv.** Plain `nixpkgs.lib.nixosSystem` + `home-manager.nixosModules.home-manager`.
- **Mixed Korean / English comments are normal.** Keep Korean intent comments untouched when editing — they encode design rationale.
- **Nix code is formatted with `nixfmt-rfc-style`** (Zed invokes `nixfmt`). There is no `treefmt`, no `nix fmt` formatter output, no pre-commit hook, no CI.
- **Git identity is hard-coded** (`Joosung Park <iam@h82.dev>`) in `home/modules/git.nix`. Do not parameterize unless adding a second user.

## ADDING A HOST

1. `mkdir hosts/<new-hostname>` and run `nixos-generate-config --root /mnt --dir hosts/<new-hostname>` (or copy the file from the running machine). This produces `hardware-configuration.nix`.
2. Create `hosts/<new-hostname>/default.nix` — start by copying `hosts/jpi-vmware/default.nix`. The shared layer is pulled in via `imports = [ ./hardware-configuration.nix ../common ];`; everything else in the file should be host-specific.
3. Set `networking.hostName = "<new-hostname>";` — **must match the directory name** (the rebuild aliases rely on this).
4. Declare host-specific bits inline: bootloader (GRUB / systemd-boot / EFI), hardware-specific options (e.g. `virtualisation.<flavor>.guest.enable`), and `system.stateVersion` (set to the NixOS release on which this host was first installed).
5. Flip the `my.system.*.enable` toggles the host needs (see `hosts/common/` modules). Skip the ones that don't apply: a headless server typically drops `my.system.desktop.plasma`, `my.system.audio.pipewire`; a non-Korean host drops `my.system.locale.korean` and sets its own `time.timeZone` / `i18n.*` directly.
6. If the host uses VS Code, add `nixpkgs.overlays = [ inputs.nix-vscode-extensions.overlays.default ];` to its `default.nix` (see `home/modules/editors/AGENTS.md` for why it must be host-level).
7. In `flake.nix`, add a new entry to `nixosConfigurations` mirroring the `jpi-vmware` block. Pass the same `inherit system; specialArgs; modules = [ ./hosts/<new-hostname> home-manager.nixosModules.home-manager { ... } ];`.
8. The user `h82` and `home/modules/*` import automatically — no per-host home config needed unless the host needs a different module set (then create `home/<user>-<hostname>.nix`).
9. Verify: `nixos-rebuild build --flake .#<new-hostname>` from the repo root.

## ANTI-PATTERNS (THIS PROJECT)

- ❌ **Do not modify any host's `hardware-configuration.nix`** — regenerate via `nixos-generate-config` if hardware changes. The file's own header forbids edits.
- ❌ **Do not change `system.stateVersion` or `home.stateVersion`** (both `25.11`). The `jpi-vmware` host calls this out explicitly: `# state version - 절대 임의로 바꾸지 말 것`. New hosts inherit the same rule — set `stateVersion` to the NixOS release on which they were first installed and never bump it casually.
- ❌ **Do not move `inputs.nix-vscode-extensions.overlays.default` out of the host's `default.nix`.** It must be applied to that host's `nixpkgs` so `allowUnfree` propagates to marketplace extensions. Each host that uses VS Code declares the overlay locally. Adding it inside `home-manager` produces a separate `pkgs` instance without `allowUnfree` and silently breaks Copilot, Pylance, etc.
- ❌ **Do not put host-specific config in `home/modules/`.** Modules under `home/modules/` are shared by every host. Anything that depends on hardware, hostname, or per-machine quirks belongs in `hosts/<hostname>/default.nix`.
- ❌ **Do not put host-specific config in `hosts/common/`.** Same rule, system side. No `if config.networking.hostName == "..." then ...`, no hardware-specific overlays, no per-machine paths. Host-only divergence (bootloader, virtualization flavor, `nix-vscode-extensions` overlay, `system.stateVersion`) lives in `hosts/<hostname>/default.nix`.
- ❌ **Do not duplicate shared config inline in a host's `default.nix` if `hosts/common/` already provides it.** If a feature has a `my.system.*.enable` toggle in common, **flip the toggle**; don't paste the underlying NixOS options. Inline duplication causes the host to drift from the shared baseline silently — the duplicate may merge, shadow, or conflict with the shared version. The only legitimate inline overrides are host-only quirks (bootloader, hardware, hostname, stateVersion, host-level overlays).
- ❌ **Do not let `networking.hostName` drift from the directory name** under `hosts/`. The rebuild aliases (`rebuild`, `rebuild-test`, `rebuild-boot`) call `nixos-rebuild --flake ~/nix-config` with no `#hostname` attribute, which resolves to `nixosConfigurations.${current hostname}`. Mismatch = silent build of the wrong host.
- ❌ **Do not introduce flake-parts / module library indirection** unless rewriting the layout deliberately. The simplicity is intentional even with N hosts — copy-paste the `nixosSystem` block, don't abstract it prematurely.
- ❌ **Do not commit `result`, `result-*`, or `.direnv/`** — already in `.gitignore`.

## COMMANDS

```bash
# Apply changes — zsh wrappers defined in home/modules/shell.nix.
# All wrappers default to the CURRENT machine's hostname (resolved by nixos-rebuild).
rebuild           # → sudo nixos-rebuild switch --flake ~/nix-config "$@"
rebuild-test      # → sudo nixos-rebuild test   --flake ~/nix-config "$@"
rebuild-boot      # → sudo nixos-rebuild boot   --flake ~/nix-config "$@"

# Build/switch a specific host explicitly (run from any machine)
sudo nixos-rebuild switch --flake ~/nix-config#<hostname>
sudo nixos-rebuild build  --flake ~/nix-config#<hostname>   # dry build, no activation

# Update inputs
nix flake update                  # all inputs
nix flake update home-manager     # one input

# Validate
nix flake check                   # evaluates ALL hosts; catches breakage early

# Format Nix files (no `nix fmt` configured in this flake)
nixfmt flake.nix hosts/**/*.nix home/**/*.nix
```

## PER-HOST QUIRKS

Anything in this section is specific to ONE host and should NOT leak into shared modules.

### `jpi-vmware` (VMware guest, KDE Plasma 6, Korean desktop)
- **VMware-only** (inline in host): `virtualisation.vmware.guest.enable`, GRUB BIOS on `/dev/sda`, `ata_piix`/`mptspi` initrd modules. Not portable.
- **`nixpkgs.overlays = [ inputs.nix-vscode-extensions.overlays.default ]`** — declared at host level (see ANTI-PATTERNS for why it can't move to `hosts/common/` or home-manager).
- **Shared toggles enabled** (provided by `hosts/common/`): `my.system.users.h82`, `my.system.locale.korean`, `my.system.networking.networkmanager`, `my.system.audio.pipewire`, `my.system.ssh.server`, `my.system.desktop.plasma`, `my.system.programs.nix-ld`, `my.system.programs._1password`. Hosts in other regions / without a desktop should leave the corresponding toggles off.

> **fcitx5 입력기**: 시스템 레벨이 아닌 home-manager 모듈 (`my.i18n.fcitx5`) 로 관리되며 모든 호스트가 공유한다. `home/modules/i18n/fcitx5.nix` 참고. KDE Wayland InputMethod 경로는 `home/modules/desktop/plasma.nix` 의 `kwinrc` 에서 fcitx5-with-addons 패키지의 store 경로를 직접 가리킨다.

## NOTES

- **Three-layer config.** `hosts/common/` provides shared system-level modules (`my.system.*`). `home/modules/` provides shared user-level modules (`my.*`), imported by every host's home-manager block via `home/h82.nix`. `hosts/<hostname>/default.nix` is per-host: imports `../common`, flips `my.system.*.enable` toggles, declares hardware/bootloader/overlays inline.
- **No secret management** (`sops-nix`, `agenix`). Git auth uses `git-credential-manager` + `secretservice` (KDE Wallet via PAM); on a non-KDE host you'll need a different credential store.
- **Git identity is hard-coded** (`Joosung Park <iam@h82.dev>`) in `home/modules/git.nix`. Acceptable while there's only one user; parameterize before adding a second.
- **Home Manager is integrated into each NixOS host**, not exposed as `homeConfigurations`. Running `home-manager switch` standalone is not supported.
