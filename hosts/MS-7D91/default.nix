{ config, lib, ... }:
{
  config.networking.hostName = "MS-7D91";
  imports = [
    ./hardware.nix
    ./disko.nix
    ../../modules/nixos/system/base.nix
    ../../modules/nixos/system/boot.nix
    ../../modules/nixos/desktop/desktop.nix
    ../../modules/nixos/desktop/user-avatar.nix
    ../../modules/nixos/desktop/fonts.nix
    ../../modules/nixos/system/nix-ld.nix
    ../../modules/nixos/services/podman.nix
    ../../modules/nixos/services/tailscale.nix
    ../../modules/nixos/system/secrets.nix
    ../../modules/nixos/wifi.nix
    ../../modules/nixos/hardware/yubikey.nix
    ../../modules/nixos/hardware/nuphy-gem80.nix
    ../../modules/nixos/hardware/sennheiser-btd.nix
    ../../modules/nixos/hardware/dualsense.nix
    ../../modules/nixos/hardware/bluetooth-audio.nix
  ];
  config.my.podman.enable = true;
  config.my.cliAuth.enable = !config.my.bootstrap;
  config.my.tailscale.enable = !config.my.bootstrap;
  config.my.tailscale.advertiseRoutes = !config.my.bootstrap;
  config.fileSystems."/mnt/data" = {
    device = "/dev/disk/by-id/ata-ST2000DM008-2UB102_ZK30PHAD-part1";
    fsType = "exfat";
    options = [
      "nofail"
      "uid=1000"
      "gid=100"
      "dmask=0022"
      "fmask=0133"
    ];
  };
  options.my.bootstrap = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Install without private boot keys or user authentication secrets.";
  };
}
