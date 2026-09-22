{ config, lib, ... }:
{
  config.networking.hostName = "MS-7D91";
  imports = [
    ./hardware.nix
    ./disko.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/boot.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/fonts.nix
    ../../modules/nixos/nix-ld.nix
    ../../modules/nixos/podman.nix
    ../../modules/nixos/secrets.nix
    ../../modules/nixos/yubikey.nix
  ];
  config.my.podman.enable = true;
  config.my.cliAuth.enable = !config.my.bootstrap;
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
