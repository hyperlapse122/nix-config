{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../common
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.initrd.luks.devices."luks-65f6a6d1-31e0-4bf5-bf13-cbc7705a1163".device =
    "/dev/disk/by-uuid/65f6a6d1-31e0-4bf5-bf13-cbc7705a1163";
  networking.hostName = "h82-t14-gen2"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # nix-vscode-extensions overlay — must be applied to the host's pkgs so allowUnfree propagates.
  # Applying it inside home-manager creates a separate pkgs instance and Copilot/Pylance/etc. silently fail.
  # See home/modules/editors/AGENTS.md and the root AGENTS.md ANTI-PATTERNS section for details.
  nixpkgs.overlays = [ inputs.nix-vscode-extensions.overlays.default ];

  # Enable shared modules (hosts/common/*)
  my.system.users.h82.enable = true;
  my.system.locale.korean.enable = true;
  my.system.networking.networkmanager.enable = true;
  my.system.networking.tailscale.enable = true;
  my.system.audio.pipewire.enable = true;
  my.system.ssh.server.enable = true;
  my.system.desktop.plasma.enable = true;
  my.system.programs.nix-ld.enable = true;
  my.system.programs.nix-index.enable = true;
  my.system.programs._1password = {
    enable = true;
    # Auto-spawn into the system tray at login — lets the browser extension and
    # SSH agent attach to the 1Password daemon immediately.
    autostart = true;
  };
  my.system.virtualisation.docker.enable = true;
  my.system.hardware.logitech.enable = true;

  # Enable aarch64 (arm64) cross-compilation — binfmt_misc + qemu-user runs aarch64-linux binaries on this host.
  # Both `nix build nixpkgs#pkgsCross.aarch64-multiplatform.<pkg>` artifacts and native aarch64 builds
  # (leveraging cache.nixos.org) work. Policy: hosts/common/cross-compile.nix.
  my.system.cross-compile.aarch64.enable = true;

  home-manager.users.h82 = {
    my.desktop.plasma.autoLock.enable = true;
    my.desktop.plasma.screenOff.enable = true;
  };

  my.system.laptop-input.enable = true;
  my.system.networking.firewall.enable = true;

  # Korean input (fcitx5) is managed by a home-manager module: home/modules/i18n/fcitx5.nix

  hardware.bluetooth.enable = true;
  services.fprintd.enable = true;

  # state version — never change arbitrarily (the NixOS release this host was first installed on)
  system.stateVersion = "26.05";
}
