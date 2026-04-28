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

      # 기본 폰트 (UI / 고정폭)
      # NOTE: family 문자열은 fontconfig 등록명과 정확히 일치해야 함.
      #       특히 "JetBrainsMono Nerd Font" 는 'JetBrainsMono' 사이에 공백이 없음.
      fonts = {
        general = {
          family = "Pretendard";
          pointSize = 10;
        };
        fixedWidth = {
          family = "JetBrainsMono Nerd Font";
          pointSize = 10;
        };
        small = {
          family = "Pretendard";
          pointSize = 8;
        };
        toolbar = {
          family = "Pretendard";
          pointSize = 10;
        };
        menu = {
          family = "Pretendard";
          pointSize = 10;
        };
        windowTitle = {
          family = "Pretendard";
          pointSize = 10;
        };
      };

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
