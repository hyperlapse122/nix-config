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
        # NOTE: fcitx5 가 home-manager 모듈로 옮겨졌으므로 시스템 프로파일 경로
        #       (/run/current-system/sw/...) 대신 fcitx5-with-addons 패키지의
        #       store 경로를 직접 가리킨다. HM 의 i18n.inputMethod.fcitx5 기본
        #       package 가 pkgs.qt6Packages.fcitx5-with-addons 이므로 일치.
        "kwinrc"."Wayland" = {
          InputMethod = {
            value = "${pkgs.qt6Packages.fcitx5-with-addons}/share/applications/fcitx5-wayland-launcher.desktop";
            immutable = true;
          };
          VirtualKeyboardEnabled = true;
        };
      };
    };
  };
}
