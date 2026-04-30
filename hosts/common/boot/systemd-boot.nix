{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.boot.systemd-boot;
in {
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
    # `splash` is automatically appended to boot.kernelParams by NixOS's plymouth module.
    # Other quiet-boot params (`quiet`, `loglevel=3`, `rd.systemd.show_status=false`, etc.) are intentionally
    # NOT applied — they affect the system globally and kernel messages are often needed for debugging.
    # Theme changes go in the host's default.nix via boot.plymouth.theme.
    boot.plymouth = {
      enable = true;

      # 2x render scale for HiDPI displays — port of `[Daemon] DeviceScale=2` from
      # ~/dotfiles/etc/plymouth/plymouthd.conf. NixOS's boot.plymouth.extraConfig is
      # appended as raw text inside the auto-generated [Daemon] section (right after Theme=).
      # See nixpkgs' plymouth.nix.
      extraConfig = ''
        DeviceScale=2
      '';
    };
  };
}
