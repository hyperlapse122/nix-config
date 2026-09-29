{ config, lib, ... }:
{
  # Every host imports this profile. Hardware-specific modules are imported
  # here too and stay inert until the host enables their trait, so every trait
  # option exists on every configuration.
  imports = [
    ./system/base.nix
    ./system/boot.nix
    ./desktop/desktop.nix
    ./desktop/user-avatar.nix
    ./hardware/fingerprint.nix
    ./desktop/fonts.nix
    ./hardware/keyd.nix
    ./system/nix-cleanup.nix
    ./system/nix-ld.nix
    ./system/agent-browser-deps.nix
    ./services/podman.nix
    ./services/tailscale.nix
    ./services/proton-vpn.nix
    ./services/resolved.nix
    ./system/secrets.nix
    ./wifi.nix
    ./hardware/yubikey.nix
    ./hardware/nuphy-gem80.nix
    ./hardware/sennheiser-btd.nix
    ./hardware/dualsense.nix
    ./hardware/bluetooth-audio.nix
    ./hardware/thunderbolt.nix
    ./hardware/laptop.nix
  ];

  options.my.bootstrap = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Install without private boot keys or user authentication secrets.";
  };

  config.my = {
    podman.enable = lib.mkDefault true;
    cliAuth.enable = lib.mkDefault (!config.my.bootstrap);
    cliAuth.enableTokscaleToken = lib.mkDefault true;
    tailscale.enable = lib.mkDefault (!config.my.bootstrap);
    protonVpn.enable = lib.mkDefault (!config.my.bootstrap);
  };
}
