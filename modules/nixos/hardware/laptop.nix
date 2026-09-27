{ config, lib, ... }:
{
  options.my.laptop = {
    enable = lib.mkEnableOption "the laptop lid-switch policy";
  };

  # Fallback lid-switch policy: consulted only when no Plasma session holds
  # the systemd-logind handle-lid-switch inhibitor (Powerdevil normally does;
  # see home/h82/desktop/kde/power-lid.nix for the mechanism actually in
  # effect). Both halves follow the same trait.
  config = lib.mkIf config.my.laptop.enable {
    services.logind.settings.Login = {
      HandleLidSwitch = "suspend-then-hibernate";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
    };
  };
}
