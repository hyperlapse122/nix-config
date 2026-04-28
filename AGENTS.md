# H82's NixOS Configurations

**Generated:** 2026-04-28
**Commit:** 8925203
**Branch:** main

## OVERVIEW

Multi-host flake-based NixOS 25.11 config. Each host lives under `hosts/<hostname>/` and is wired into `flake.nix#nixosConfigurations`.
The user (`h82`) and reusable home-manager modules are shared across all hosts; per-host divergence stays inside `hosts/<hostname>/default.nix`.
Home Manager runs as a NixOS module; KDE Plasma 6 is configured via `plasma-manager`.
Reusable home-manager modules use a custom `my.*` option namespace and are toggled per-user in `home/h82.nix`.

> Currently only `jpi-vmware` exists. New hosts: NixOS only (no nix-darwin / WSL planned).

## STRUCTURE

```plain
nix-config/
├── flake.nix                  # Inputs + every nixosConfiguration entry
├── flake.lock                 # Pinned: nixpkgs 25.11, home-manager 25.11, plasma-manager, nix-vscode-extensions
├── hosts/
│   └── <hostname>/            # One directory per machine; name MUST match networking.hostName
│       ├── default.nix        # System config + per-host overlays (e.g. nix-vscode-extensions, see editors/AGENTS.md)
│       └── hardware-configuration.nix  # GENERATED per host — DO NOT MODIFY
└── home/
    ├── h82.nix                # User entrypoint (host-agnostic); flips my.*.enable toggles
    └── modules/               # Reusable, host-agnostic home-manager modules — see home/modules/AGENTS.md
```

## WHERE TO LOOK

| Task | Location |
|------|----------|
| Add a system-level package or service for ONE host | `hosts/<hostname>/default.nix` |
| Add a user package / program (all hosts) | `home/modules/<name>.nix`, then enable in `home/h82.nix` |
| Add a VS Code extension or setting | `home/modules/editors/vscode.nix` (see `home/modules/editors/AGENTS.md`) |
| Add a KDE Plasma setting | `home/modules/desktop/plasma.nix` |
| Add an input method (fcitx5) addon | `home/modules/i18n/fcitx5.nix` |
| Bump nixpkgs / home-manager / plasma-manager / nix-vscode-extensions | `flake.lock` via `nix flake update` |
| Add a new host | See **ADDING A HOST** below |

## CONVENTIONS

- **`my.*` option namespace** — every reusable home module exposes `my.<group>.<name>.enable` and nothing else (sole exception: `vscode` adds `package`). User opts in via `home/h82.nix`. See `home/modules/AGENTS.md`.
- **Imports are explicit `imports = [ ... ]` lists**, not auto-discovered. Aggregated via `default.nix` per directory (`./modules`, `./editors`).
- **`with pkgs; [ ... ]`** style for package lists.
- **No flake-parts / snowfall / devshell / devenv.** Plain `nixpkgs.lib.nixosSystem` + `home-manager.nixosModules.home-manager`.
- **Mixed Korean / English comments are normal.** Keep Korean intent comments untouched when editing — they encode design rationale.
- **Nix code is formatted with `nixfmt-rfc-style`** (Zed invokes `nixfmt`). There is no `treefmt`, no `nix fmt` formatter output, no pre-commit hook, no CI.
- **Git identity is hard-coded** (`Joosung Park <iam@h82.dev>`) in `home/modules/git.nix`. Do not parameterize unless adding a second user.

## ADDING A HOST

1. `mkdir hosts/<new-hostname>` and run `nixos-generate-config --root /mnt --dir hosts/<new-hostname>` (or copy the file from the running machine). This produces `hardware-configuration.nix`.
2. Create `hosts/<new-hostname>/default.nix` — start by copying `hosts/jpi-vmware/default.nix` and stripping anything VMware/KDE/Korean-specific that doesn't apply.
3. Set `networking.hostName = "<new-hostname>";` — **must match the directory name** (the rebuild aliases rely on this).
4. If the host uses VS Code, add `nixpkgs.overlays = [ inputs.nix-vscode-extensions.overlays.default ];` to its `default.nix` (see `home/modules/editors/AGENTS.md` for why it must be host-level).
5. In `flake.nix`, add a new entry to `nixosConfigurations` mirroring the `jpi-vmware` block. Pass the same `inherit system; specialArgs; modules = [ ./hosts/<new-hostname> home-manager.nixosModules.home-manager { ... } ];`.
6. The user `h82` and `home/modules/*` import automatically — no per-host home config needed unless the host needs a different module set (then create `home/<user>-<hostname>.nix`).
7. Verify: `nixos-rebuild build --flake .#<new-hostname>` from the repo root.

## ANTI-PATTERNS (THIS PROJECT)

- ❌ **Do not modify any host's `hardware-configuration.nix`** — regenerate via `nixos-generate-config` if hardware changes. The file's own header forbids edits.
- ❌ **Do not change `system.stateVersion` or `home.stateVersion`** (both `25.11`). The `jpi-vmware` host calls this out explicitly: `# state version - 절대 임의로 바꾸지 말 것`. New hosts inherit the same rule — set `stateVersion` to the NixOS release on which they were first installed and never bump it casually.
- ❌ **Do not move `inputs.nix-vscode-extensions.overlays.default` out of the host's `default.nix`.** It must be applied to that host's `nixpkgs` so `allowUnfree` propagates to marketplace extensions. Each host that uses VS Code declares the overlay locally. Adding it inside `home-manager` produces a separate `pkgs` instance without `allowUnfree` and silently breaks Copilot, Pylance, etc.
- ❌ **Do not put host-specific config in `home/modules/`.** Modules under `home/modules/` are shared by every host. Anything that depends on hardware, hostname, or per-machine quirks belongs in `hosts/<hostname>/default.nix`.
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
- **VMware-only**: `virtualisation.vmware.guest.enable`, GRUB BIOS on `/dev/sda`, `ata_piix`/`mptspi` initrd modules. Not portable.
- **Korean locale**: `time.timeZone = "Asia/Seoul"`, `i18n.defaultLocale = "ko_KR.UTF-8"`. Hosts in other regions should override these in their own `default.nix`.
- **KDE Plasma 6** via `services.desktopManager.plasma6` + `plasma-manager` home module. Hosts without a desktop should not enable `my.desktop.plasma`.

> **fcitx5 입력기**: 시스템 레벨이 아닌 home-manager 모듈 (`my.i18n.fcitx5`) 로 관리되며 모든 호스트가 공유한다. `home/modules/i18n/fcitx5.nix` 참고. KDE Wayland InputMethod 경로는 `home/modules/desktop/plasma.nix` 의 `kwinrc` 에서 fcitx5-with-addons 패키지의 store 경로를 직접 가리킨다.

## NOTES

- **Shared user, per-host system config.** `home/h82.nix` and `home/modules/*` are imported by every host's home-manager block. Per-host divergence belongs in `hosts/<hostname>/default.nix`.
- **No secret management** (`sops-nix`, `agenix`). Git auth uses `git-credential-manager` + `secretservice` (KDE Wallet via PAM); on a non-KDE host you'll need a different credential store.
- **Git identity is hard-coded** (`Joosung Park <iam@h82.dev>`) in `home/modules/git.nix`. Acceptable while there's only one user; parameterize before adding a second.
- **Home Manager is integrated into each NixOS host**, not exposed as `homeConfigurations`. Running `home-manager switch` standalone is not supported.
