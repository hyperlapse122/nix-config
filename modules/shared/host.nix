{ lib, ... }:
{
  # Host facts and traits, declared once and imported by every assembly: the
  # NixOS system, the Home Manager user inside it, and the standalone Home
  # Manager and system-manager outputs of a non-NixOS host. Modules and checks
  # branch on these values, never on a host name.
  options.my = {
    bootstrap = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install without private boot keys or user authentication secrets.";
    };

    hostName = lib.mkOption {
      type = lib.types.str;
      description = "The host's name, taken from its directory under hosts/.";
    };

    kind = lib.mkOption {
      type = lib.types.enum [
        "nixos"
        "linux"
      ];
      default = "nixos";
      description = "Whether the host runs NixOS or another Linux distribution.";
    };

    user = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "h82";
        description = "The account the user environment is applied to.";
      };
      home = lib.mkOption {
        type = lib.types.str;
        default = "/home/h82";
        description = "The home directory of that account.";
      };
    };

    laptop.enable = lib.mkEnableOption "the laptop lid-switch policy";
    keyd.enable = lib.mkEnableOption "the keyd remap of the internal keyboard";
    fingerprint.enable = lib.mkEnableOption "fingerprint authentication for the lock screen, polkit and sudo";
    thunderbolt.enable = lib.mkEnableOption "Thunderbolt device authorization through bolt";
    nuphyGem80.enable = lib.mkEnableOption "device access for the NuPhy Gem80 configurator and firmware flashing";
  };
}
