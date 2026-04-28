{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.plasma;
in {
  options.my.desktop.plasma = {
    enable = lib.mkEnableOption "KDE Plasma desktop configuration (plasma-manager)";
  };

  config = lib.mkIf cfg.enable {
    programs.plasma = {
      enable = true;

      configFile = {
        # KWin Wayland의 가상 키보드 활성화 및 fcitx5 선택
        "kwinrc"."Wayland" = {
          InputMethod = {
            value = "/run/current-system/sw/share/applications/org.fcitx.Fcitx5.desktop";
            immutable = true;
          };
          VirtualKeyboardEnabled = true;
        };
      };
    };
  };
}
