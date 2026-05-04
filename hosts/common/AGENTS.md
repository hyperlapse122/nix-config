# hosts/common - Shared NixOS Modules

Shared system-level modules under the `my.system.*` namespace. Imported by every host through `hosts/<hostname>/default.nix -> ../common`.

## STRUCTURE

```plain
hosts/common/
+-- default.nix              # aggregator for every shared system module
+-- base.nix                 # always-on Nix settings, Codex CLI cache, allowUnfree, D-Bus, base packages
+-- users.nix                # my.system.users.h82
+-- locale.nix               # my.system.locale.korean
+-- networking.nix           # my.system.networking.{networkmanager,firewall}
+-- tailscale.nix            # my.system.networking.tailscale
+-- boot/                    # grub, systemd-boot, sbctl, plymouth, TPM LUKS helper
+-- desktop/plasma.nix       # system Plasma session/SDDM/KWallet setup
+-- hardware/logitech.nix    # shared Logitech udev rule
+-- programs/                # nix-ld, nix-index, 1Password
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add shared system module | `hosts/common/<name>.nix` or a subdirectory | Import it from the nearest `default.nix`. |
| Enable module for a host | `hosts/<hostname>/default.nix` | Flip `my.system.*.enable`; keep host-specific values there. |
| Add boot policy | `hosts/common/boot/` | Use a shared module only when policy is reusable across hosts. |
| Add host-required boot arg | Module option plus assertion | See `boot/grub.nix` and `boot/tpm-luks-enroll.nix`. |
| Change firewall behavior | `networking.nix` | False must be assigned directly, not hidden behind `mkIf`. |
| Change Secure Boot flow | `boot/sbctl.nix` | Handles key creation, enrollment, signing, and EFI var immutability. |
| Change TPM LUKS helper | `boot/tpm-luks-enroll.nix` | Installs `enroll-luks-tpm2`; validates Secure Boot, TPM2, and LUKS2. |

## CONVENTIONS

- Shared system options use `my.system.<group>.<name>.enable`.
- Most modules follow `let cfg = config.my.system.<path>; in { options...; config = lib.mkIf cfg.enable ...; }`.
- `base.nix` is the only always-on module. It owns flakes, the Codex CLI Cachix substituter, `allowUnfree`, D-Bus, and minimal universal packages.
- Extra options are allowed only when activation needs host data: `boot.grub.device`, `boot.tpm-luks-enroll.devices`, `boot.tpm-luks-enroll.pcrs`, `programs._1password.autostart`, and `networking.firewall.enable`.
- Use assertions for required host arguments so failures name the `my.system.*` option directly.
- Subdirectory `default.nix` files are aggregators only.

## BOOT AND SECURITY

- `boot/grub.nix` is BIOS/Legacy and single-OS oriented; it disables OS prober. Multi-boot hosts should configure GRUB inline instead.
- `boot/systemd-boot.nix` is UEFI-oriented and includes Plymouth. Avoid it on firmware known to mishandle EFI variable writes.
- `boot/sbctl.nix` enables `systemd-boot`, creates keys when missing, enrolls them in Setup Mode, signs EFI files, and restores immutable EFI variables.
- `boot/tpm-luks-enroll.nix` is manual by design. `--check` validates prerequisites; mutation requires root and `--yes`.
- `_1password.nix` stays system-level because browser integration needs the setuid wrapper; autostart is implemented with a system desktop entry.

## NIX SETTINGS

- Flakes are enabled globally through `nix.settings.experimental-features`.
- `codex-cli.cachix.org` is trusted here so NixOS rebuilds can substitute `codex-cli-nix` packages without requiring every host to repeat the cache settings.
- Keep the system-level cache settings aligned with root `flake.nix` `nixConfig`.

## NETWORKING

- `networking.firewall.enable` defaults to true with `mkOption`, not `mkEnableOption`.
- `networking.firewall.enable = cfg.firewall.enable` is intentionally unconditional so host-level `false` wins over the NixOS default.
- NetworkManager unmanaged interfaces already cover `lo`, `vmnet*`, `tailscale*`, `docker*`, and `veth*`.
- Tailscale has no auth-key automation. First boot still needs `sudo tailscale up`.

## ANTI-PATTERNS

- Do not put host-specific paths, hostnames, disks, hardware quirks, or overlays here.
- Do not replace required-argument assertions with vague NixOS module errors.
- Do not wrap the firewall false path in `mkIf`; that silently falls back to NixOS's default true.
- Do not use the GRUB module for multi-boot.
- Do not assume secrets or Tailscale auth keys exist in this repo.
- Do not move 1Password autostart into Home Manager unless browser integration is redesigned too.
- Do not add per-host substituter policy here unless it is intended for every host.
