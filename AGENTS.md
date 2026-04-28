# H82's NixOS Configuration

**Generated:** 2026-04-28
**Commit:** 8925203
**Branch:** main

## OVERVIEW

Single-host flake-based NixOS 25.11 config for `jpi-vmware` (VMware guest, `x86_64-linux`).
Home Manager runs as a NixOS module; KDE Plasma 6 is configured via `plasma-manager`.
Reusable home-manager modules live under a custom `my.*` option namespace and are toggled per-user in `home/h82.nix`.

## STRUCTURE

```plain
nix-config/
├── flake.nix                  # Inputs + the only nixosConfiguration: jpi-vmware
├── flake.lock                 # Pinned: nixpkgs 25.11, home-manager 25.11, plasma-manager, nix-vscode-extensions
├── hosts/
│   └── jpi-vmware/            # Only host (VMware VM)
│       ├── default.nix        # System config + nix-vscode-extensions overlay (host-level, by design)
│       └── hardware-configuration.nix  # GENERATED — DO NOT MODIFY
└── home/
    ├── h82.nix                # User entrypoint; flips my.*.enable toggles
    └── modules/               # Reusable home-manager modules — see home/modules/AGENTS.md
```

## WHERE TO LOOK

| Task | Location |
| ---- | -------- |
| Add a system-level package or service | `hosts/jpi-vmware/default.nix` |
| Add a user package / program | `home/modules/<name>.nix`, then enable in `home/h82.nix` |
| Add a VS Code extension or setting | `home/modules/editors/vscode.nix` (see `home/modules/editors/AGENTS.md`) |
| Add a KDE Plasma setting | `home/modules/desktop/plasma.nix` |
| Bump nixpkgs / home-manager / plasma-manager | `flake.lock` via `nix flake update` |
| Add a second host | New `hosts/<name>/default.nix` + new entry in `flake.nix#nixosConfigurations` |

## CONVENTIONS

- **`my.*` option namespace** — every reusable home module exposes `my.<group>.<name>.enable` and nothing else (sole exception: `vscode` adds `package`). User opts in via `home/h82.nix`. See `home/modules/AGENTS.md`.
- **Imports are explicit `imports = [ ... ]` lists**, not auto-discovered. Aggregated via `default.nix` per directory (`./modules`, `./editors`).
- **`with pkgs; [ ... ]`** style for package lists.
- **No flake-parts / snowfall / devshell / devenv.** Plain `nixpkgs.lib.nixosSystem` + `home-manager.nixosModules.home-manager`.
- **Mixed Korean / English comments are normal.** Keep Korean intent comments untouched when editing — they encode design rationale.
- **Nix code is formatted with `nixfmt-rfc-style`** (Zed invokes `nixfmt`). There is no `treefmt`, no `nix fmt` formatter output, no pre-commit hook, no CI.
- **Git identity is hard-coded** (`Joosung Park <iam@h82.dev>`) in `home/modules/git.nix`. Do not parameterize unless adding a second user.

## ANTI-PATTERNS (THIS PROJECT)

- ❌ **Do not modify `hosts/jpi-vmware/hardware-configuration.nix`** — regenerate via `nixos-generate-config` if hardware changes. The file's own header forbids edits.
- ❌ **Do not change `system.stateVersion` or `home.stateVersion`** (both `25.11`). The host file calls this out explicitly: `# state version - 절대 임의로 바꾸지 말 것`.
- ❌ **Do not move `inputs.nix-vscode-extensions.overlays.default` out of `hosts/jpi-vmware/default.nix`.** It must be applied to the *host's* `nixpkgs` so `allowUnfree` propagates to marketplace extensions. Adding it inside `home-manager` produces a separate `pkgs` instance without `allowUnfree` and silently breaks Copilot, Pylance, etc.
- ❌ **Do not clear `GTK_IM_MODULE` / `QT_IM_MODULE` overrides** in the host. fcitx5 Wayland frontend handles input directly; restoring those vars breaks Korean input.
- ❌ **Do not introduce flake-parts / module library indirection** unless rewriting the layout deliberately. The simplicity is intentional.
- ❌ **Do not commit `result`, `result-*`, or `.direnv/`** — already in `.gitignore`.

## COMMANDS

```bash
# Apply changes — zsh wrappers defined in home/modules/shell.nix
rebuild           # → sudo nixos-rebuild switch --flake ~/nix-config
rebuild-test      # → sudo nixos-rebuild test   --flake ~/nix-config
rebuild-boot      # → sudo nixos-rebuild boot   --flake ~/nix-config

# Without wrappers
sudo nixos-rebuild switch --flake ~/nix-config#jpi-vmware

# Update inputs
nix flake update                  # all inputs
nix flake update home-manager     # one input

# Validate
nix flake check

# Format Nix files (no `nix fmt` configured in this flake)
nixfmt flake.nix hosts/**/*.nix home/**/*.nix
```

## NOTES

- **Single user / single host.** No multi-host machinery exists. If you add a second host, lift `system`, the home-manager block, and `users.h82` into shared helpers first.
- **No secret management** (`sops-nix`, `agenix`). Git auth uses `git-credential-manager` + `secretservice` (KDE Wallet via PAM, configured in `hosts/jpi-vmware/default.nix`).
- **VMware-specific.** `virtualisation.vmware.guest.enable`, GRUB BIOS on `/dev/sda`, `ata_piix`/`mptspi` initrd modules. None of this is portable to bare metal or other hypervisors without changes.
- **Korean locale + fcitx5-hangul** with Wayland frontend. `time.timeZone = "Asia/Seoul"`, `i18n.defaultLocale = "ko_KR.UTF-8"`.
- **Home Manager is integrated into the NixOS host**, not a standalone flake output. There is no `homeConfigurations.h82`; running `home-manager switch` standalone is not supported.
