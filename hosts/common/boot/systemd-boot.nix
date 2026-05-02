{
  config,
  lib,
  ...
}:
let
  cfg = config.my.system.boot.systemd-boot;
in
{
  options.my.system.boot.systemd-boot = {
    enable = lib.mkEnableOption "systemd-boot bootloader (UEFI) — includes EFI variable writes + Plymouth splash. ESP mount uses NixOS defaults (/boot). For BIOS/Legacy hosts use my.system.boot.grub";
  };

  config = lib.mkIf cfg.enable {
    boot.loader.systemd-boot.enable = true;

    # Allow bootctl to write EFI variables (BootOrder, BootXXXX) directly.
    # Required for NixOS to register/refresh boot entries.
    # On firmware that misbehaves with this (some Macs), don't enable this module — set up
    # systemd-boot inline and pair it with `boot.loader.efi.canTouchEfiVariables = false;`.
    boot.loader.efi.canTouchEfiVariables = true;

    # Boot splash (Plymouth) — bundled into the standard policy for UEFI/systemd-boot hosts.
    # Shared Plymouth kernel-param policy lives in ./plymouth.nix.
    # Theme changes go in the host's default.nix via boot.plymouth.theme.
    boot.plymouth = {
      enable = true;
      extraConfig = ''
        DeviceScale=1
      '';
    };
  };
}
