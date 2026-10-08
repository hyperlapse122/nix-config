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
        "darwin"
      ];
      default = "nixos";
      description = "Whether the host runs NixOS, another Linux distribution, or macOS.";
    };

    desktopSSH.publicKey = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Public SSH metadata shared by the desktop provisioner and user agent.";
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

    nuphyGem80.enable = lib.mkEnableOption "device access for the NuPhy Gem80 configurator and firmware flashing";
    t3.cli.enable = lib.mkEnableOption "the headless T3 Code `t3` CLI";
    t3.desktop.enable = lib.mkEnableOption "the T3 Code desktop app (NixOS and macOS hosts only)";
  };
}
