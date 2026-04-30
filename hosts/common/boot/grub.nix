{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.boot.grub;
in {
  options.my.system.boot.grub = {
    enable = lib.mkEnableOption "GRUB bootloader (BIOS/Legacy) — useOSProber disabled. For EFI/UEFI hosts use my.system.boot.systemd-boot";

    # `my.*` options should expose only `.enable` in principle, but a required argument that must always be paired
    # with module activation is more traceable when exposed as an option — an intentional exception to the enable-only rule.
    # Precedent: home/modules/editors/vscode.nix exposes `package` for the same reason.
    device = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "/dev/sda";
      description = ''
        Disk device on which GRUB should be installed (BIOS/Legacy boot-sector location).
        Must be set to a non-empty value when `enable = true` — enforced by the assertion below.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # NixOS's boot.loader.grub.device performs its own validation, but the message is generic — provide a friendly one
    # that points directly at the `my.system.boot.grub.device` option name.
    assertions = [{
      assertion = cfg.device != "";
      message = "Hosts with my.system.boot.grub.enable = true must set my.system.boot.grub.device (e.g. \"/dev/sda\").";
    }];

    boot.loader.grub = {
      enable = true;
      device = cfg.device;
      # Most hosts are single-OS, not multi-boot, so OS prober is disabled.
      # Faster boot + more stable (immune to other OSes' boot-sector changes).
      # If a host needs multi-boot, do not enable this module — configure GRUB inline directly.
      useOSProber = false;
    };
  };
}
