{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.i18n.fcitx5;
in
{
  options.my.i18n.fcitx5 = {
    enable = lib.mkEnableOption "fcitx5 input method (Korean / Wayland frontend)";
  };

  config = lib.mkIf cfg.enable {
    # Korean input
    # NOTE: home-manager's i18n.inputMethod runs fcitx5-daemon as a systemd user unit
    #       rather than at the system level.
    #       When waylandFrontend = true, HM does NOT set GTK_IM_MODULE / QT_IM_MODULE,
    #       so hosts don't need to clear them separately.
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        addons = with pkgs; [
          fcitx5-hangul
          qt6Packages.fcitx5-configtool
        ];
        # Use the Wayland frontend (recommended for KDE Plasma 6)
        waylandFrontend = true;
        # Input-method toggle key: dedicated Hangul key on Korean keyboards
        # Serialized to ~/.config/fcitx5/config as INI. TriggerKeys is a key-list,
        # so it is written as the [Hotkey/TriggerKeys] section + numerically-indexed entries.
        # Since only a single dedicated key is the trigger, the modifier-cycle (EnumerateWithTriggerKeys) is disabled.
        settings.globalOptions = {
          Hotkey = {
            EnumerateWithTriggerKeys = false;
          };
          "Hotkey/TriggerKeys" = {
            "0" = "Hangul";
          };
        };
      };
    };
  };
}
