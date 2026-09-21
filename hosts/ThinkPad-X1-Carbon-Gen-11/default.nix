{ config, lib, ... }:
{
  imports = [
    ./hardware.nix
    ./disko.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/boot.nix
    ../../modules/nixos/claude.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/fonts.nix
    ../../modules/nixos/keyd.nix
    ../../modules/nixos/nix-ld.nix
    ../../modules/nixos/secrets.nix
    ../../modules/nixos/yubikey.nix
  ];
  config.my.cliAuth.enable = !config.my.bootstrap;
  # The Gen 11 predates the Copilot key, so the chord binding stays out of the
  # generated keyd configuration on this host.
  config.my.keyd.copilotKey = false;
  options.my.bootstrap = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Install without private boot keys or user authentication secrets.";
  };
}
