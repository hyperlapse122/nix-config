{ config, lib, ... }:
{
  config.networking.hostName = "ThinkPad-X1-Carbon-Gen-11";
  imports = [
    ./hardware.nix
    ./disko.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/boot.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/fingerprint.nix
    ../../modules/nixos/fonts.nix
    ../../modules/nixos/keyd.nix
    ../../modules/nixos/nix-cleanup.nix
    ../../modules/nixos/nix-ld.nix
    ../../modules/nixos/podman.nix
    ../../modules/nixos/secrets.nix
    ../../modules/nixos/yubikey.nix
  ];
  config.my.podman.enable = true;
  config.my.cliAuth.enable = !config.my.bootstrap;
  config.my.fingerprint.enable = !config.my.bootstrap;
  # The Gen 11 predates the Copilot key, so the chord binding stays out of the
  # generated keyd configuration on this host.
  config.my.keyd.copilotKey = false;
  # Fallback lid-switch policy: consulted only when no Plasma session holds
  # the systemd-logind handle-lid-switch inhibitor (Powerdevil normally does;
  # see home/h82/kde/power-lid.nix for the mechanism actually in effect).
  config.services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
  options.my.bootstrap = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Install without private boot keys or user authentication secrets.";
  };
}
