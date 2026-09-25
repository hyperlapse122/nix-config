{ config, lib, ... }:
{
  config.networking.hostName = "ThinkPad-X1-Carbon-Gen-11";
  imports = [
    ./hardware.nix
    ./disko.nix
    ../../modules/nixos/system/base.nix
    ../../modules/nixos/system/boot.nix
    ../../modules/nixos/desktop/desktop.nix
    ../../modules/nixos/desktop/user-avatar.nix
    ../../modules/nixos/hardware/fingerprint.nix
    ../../modules/nixos/desktop/fonts.nix
    ../../modules/nixos/hardware/keyd.nix
    ../../modules/nixos/system/nix-cleanup.nix
    ../../modules/nixos/system/nix-ld.nix
    ../../modules/nixos/services/podman.nix
    ../../modules/nixos/services/tailscale.nix
    ../../modules/nixos/system/secrets.nix
    ../../modules/nixos/wifi.nix
    ../../modules/nixos/hardware/yubikey.nix
    ../../modules/nixos/hardware/sennheiser-btd.nix
    ../../modules/nixos/hardware/bluetooth-audio.nix
  ];
  config.my.podman.enable = true;
  config.my.cliAuth.enable = !config.my.bootstrap;
  config.my.tailscale.enable = !config.my.bootstrap;
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
