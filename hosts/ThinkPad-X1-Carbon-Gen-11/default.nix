{ lib, ... }:
{
  imports = [
    ./hardware.nix
    ./disko.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/boot.nix
    ../../modules/nixos/desktop.nix
  ];
  options.my.bootstrap = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Install without private boot keys or user authentication secrets.";
  };
}
