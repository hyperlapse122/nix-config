# H82's NixOS Configurations

**Generated:** 2026-05-04
**Commit:** 2609740
**Branch:** main

## OVERVIEW

Multi-host flake-based NixOS config tracking `nixos-unstable` exclusively. Hosts are declared explicitly in `flake.nix#nixosConfigurations`; shared system modules live in `hosts/common/`, shared Home Manager modules live in `home/modules/`, and per-host divergence stays in `hosts/<hostname>/default.nix`.

Home Manager follows `master`, plasma-manager configures KDE Plasma 6, Codex CLI comes from `codex-cli-nix`, and reusable modules use a custom option namespace: `my.system.*` for NixOS modules and `my.*` for Home Manager modules.

## STRUCTURE

```plain
nix-config/
+-- flake.nix                    # inputs + explicit nixosConfigurations
+-- flake.lock                   # pinned nixpkgs, home-manager, plasma-manager, tooling flakes
+-- hosts/
|   +-- common/                  # shared system modules; see hosts/common/AGENTS.md
|   +-- jpi-vmware/              # VMware desktop host
|   +-- h82-t14-gen2/            # ThinkPad host with Secure Boot + TPM2 LUKS
+-- home/
|   +-- h82.nix                  # user entrypoint; flips my.* enables
|   +-- modules/                 # shared Home Manager modules; see home/modules/AGENTS.md
+-- agents/                      # runtime OpenCode skills; see agents/AGENTS.md
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add a host | `hosts/<hostname>/default.nix`, `flake.nix` | Host directory, `networking.hostName`, and flake key must match. |
| Change one host | `hosts/<hostname>/default.nix` | Hardware, boot device, host overlays, host Home Manager overrides, stateVersion. |
| Add shared system feature | `hosts/common/<name>.nix` | Gate as `my.system.<group>.<name>.enable`; document local caveats in `hosts/common/AGENTS.md`. |
| Toggle shared system feature | `hosts/<hostname>/default.nix` | Flip `my.system.*.enable`; do not duplicate common module internals inline. |
| Add shared user feature | `home/modules/<name>.nix` | Gate as `my.<group>.<name>.enable`, import in nearest `default.nix`, enable in `home/h82.nix`. |
| Add editor extension/setting | `home/modules/editors/{vscode,zed}.nix` | VS Code marketplace overlay still belongs in every host `default.nix`. |
| Change dev tooling | `home/modules/dev/` | See `home/modules/dev/AGENTS.md` for opencode, agents, Docker, Playwright, mise wrappers. |
| Change opencode config | `home/modules/dev/opencode/{opencode.json,context.md,commands/,oh-my-openagent.jsonc}` | `context.md` is installed as `~/.config/opencode/AGENTS.md`. |
| Change Plasma user settings | `home/modules/desktop/plasma.nix` | User-level plasma-manager config; system session setup is in `hosts/common/desktop/plasma.nix`. |
| Change input method | `home/modules/i18n/fcitx5.nix` | Home Manager owns fcitx5; Plasma points KWin at the fcitx5 store path. |
| Update inputs | `flake.lock` | Run `nix flake update` or target a specific input. |
| Change Codex CLI cache/input | `flake.nix`, `hosts/common/base.nix`, `home/h82.nix` | Keep flake `nixConfig`, system `nix.settings`, and the Home Manager package source aligned. |

## CONVENTIONS

- Single-channel policy: every package comes from the locked `nixos-unstable` nixpkgs. Do not add stable/unstable splits or secondary package sets.
- Plain flake layout only: explicit `nixpkgs.lib.nixosSystem` blocks, no flake-parts, snowfall, devshell, or devenv abstraction.
- Imports are explicit `imports = [ ... ]` lists, aggregated by `default.nix` files.
- Package lists use `with pkgs; [ ... ]` when that is the local style.
- Nix code is formatted with `nixfmt`; this flake does not define a `formatter`, so do not document `nix fmt` unless one is added.
- Every tracked human-readable text must be English. Technical literals such as `ko_KR.UTF-8`, `Asia/Seoul`, `Pretendard`, and key names are allowed.
- Home Manager is integrated as a NixOS module with `useGlobalPkgs`, `useUserPackages`, and plasma-manager in `sharedModules`; standalone `home-manager switch` is not supported.
- Codex CLI uses `inputs.codex-cli-nix.packages.${system}.default`; the matching `codex-cli.cachix.org` substituter is declared in both flake `nixConfig` and `hosts/common/base.nix`.
- `home/modules/git.nix` hard-codes `Joosung Park <iam@h82.dev>` while this repo has one user.

## ADDING A HOST

1. Create `hosts/<new-hostname>/hardware-configuration.nix` with `nixos-generate-config`.
2. Create `hosts/<new-hostname>/default.nix`; import `./hardware-configuration.nix` and `../common`.
3. Set `networking.hostName = "<new-hostname>"`; it must match the directory and flake key.
4. Keep host-only details inline: hardware modules, boot device policy arguments, overlays, virtualization quirks, host Home Manager overrides, and `system.stateVersion`.
5. Add the explicit `nixosConfigurations.<new-hostname>` block to `flake.nix` and mirror the existing Home Manager wiring.
6. If the host enables VS Code, declare `nixpkgs.overlays = [ inputs.nix-vscode-extensions.overlays.default ];` in that host's `default.nix`.
7. Verify with `nixos-rebuild build --flake .#<new-hostname>`.

## LANGUAGE

All version-controlled comments, docs, option descriptions, human-readable strings, commit messages, branch names, tags, and PR/MR text must be English.

Allowed exceptions:
- Technical values that require non-English or non-Latin forms, such as locale codes, timezone names, font names, and key codes.
- Generated `hosts/*/hardware-configuration.nix` files.
- Managed OpenCode skill contents under `agents/skills/` and `agents/.skill-lock.json`.

Pre-commit guardrail for files you changed:

```bash
git diff --name-only HEAD | xargs -r grep -lP '[^\x00-\x7F]' \
  | grep -vE '^(agents/skills/|agents/\.skill-lock\.json$|hosts/.*/hardware-configuration\.nix$)' \
  || true
```

## ANTI-PATTERNS

- Do not edit `hosts/*/hardware-configuration.nix`; regenerate it.
- Do not change `system.stateVersion` or `home.stateVersion` casually. `jpi-vmware` is `25.11`, `h82-t14-gen2` is `26.05`, and `home/h82.nix` is `25.11`.
- Do not move `nix-vscode-extensions` overlay out of host `default.nix`; unfree marketplace extensions depend on the host `pkgs` with `allowUnfree`.
- Do not put host-specific config in `hosts/common/` or `home/modules/`.
- Do not duplicate shared module internals inline in a host; flip the existing `my.system.*.enable` toggle or add a shared module.
- Do not let `networking.hostName`, host directory name, and `flake.nix` key drift apart.
- Do not add hidden secret management assumptions; this repo currently has no `sops-nix` or `agenix`.
- Do not commit `result`, `result-*`, or `.direnv/`.
- Do not add non-English tracked text.

## COMMANDS

```bash
# Apply current-host system changes. Wrappers are defined in home/modules/shell.nix.
rebuild
rebuild-test
rebuild-boot

# Build or switch a specific host.
sudo nixos-rebuild build --flake ~/nix-config#<hostname>
sudo nixos-rebuild switch --flake ~/nix-config#<hostname>

# Update inputs.
nix flake update
nix flake update nixpkgs
nix flake update home-manager

# Validate.
nix flake check
nixos-rebuild build --flake .#<hostname>

# Format Nix sources. No flake formatter is configured.
nixfmt flake.nix hosts/**/*.nix home/**/*.nix
```

## PER-HOST QUIRKS

### `jpi-vmware`

VMware guest desktop. Uses GRUB BIOS on `/dev/sda`, VMware guest graphics, host-level VS Code overlay, shared desktop/audio/SSH/Docker/Tailscale/1Password/nix-index/nix-ld/logitech/cross-compile modules, no laptop-input, and firewall disabled because the guest sits behind VMware NAT.

Host Home Manager overrides disable Plasma idle lock and display auto-off because they are annoying inside a VM.

### `h82-t14-gen2`

ThinkPad T14 Gen 2 Intel. Uses nixos-hardware ThinkPad/Tiger Lake modules, latest kernel, systemd initrd TPM2 unlock, systemd-boot, sbctl Secure Boot, TPM2 LUKS enrollment helper, laptop-input, firewall, fwupd, Bluetooth, fingerprint service, redistributable firmware, Logitech rules, Tailscale, Docker, and aarch64 cross-compilation.

Run `sudo enroll-luks-tpm2 --check` before enrollment, then `sudo enroll-luks-tpm2 --recovery-key --yes` only after LUKS header backups exist.

## NOTES

- Three-layer model: `hosts/common/` defines shared system policy, `home/modules/` defines shared user policy, and `hosts/<hostname>/default.nix` applies host-specific divergence.
- Plasma is split: NixOS session/display/PAM setup in `hosts/common/desktop/plasma.nix`; user-level panels, fonts, KWin, and PowerDevil behavior in `home/modules/desktop/plasma.nix`.
- `agents/` is runtime-mutable through an out-of-store symlink. Treat `agents/skills/` and `.skill-lock.json` as managed artifacts.
