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

        # 전역 테마: 자동 (낮/밤 시간대에 따라 Breeze ↔ Breeze Dark 자동 전환)
        # NOTE: plasma-manager 의 `workspace.lookAndFeel` 은 구체적 패키지 ID
        #       (org.kde.breeze.desktop / org.kde.breezedark.desktop) 만 받기 때문에
        #       "Automatic" 을 직접 표현하지 못한다. Plasma 6 에서 "Automatic" 은
        #       lookAndFeel 패키지가 아니라 kdeglobals 의 [KDE] 섹션 boolean
        #       `AutomaticLookAndFeel=true` 로 동작하며, 낮/밤 각각의 테마는
        #       `DefaultLightLookAndFeel` / `DefaultDarkLookAndFeel` 로 별도 저장된다.
        #       (참고: KDE/plasma-workspace kcms/lookandfeel/lookandfeelsettings.kcfg)
        "kdeglobals"."KDE" = {
          AutomaticLookAndFeel = true;
          DefaultLightLookAndFeel = "org.kde.breeze.desktop";
          DefaultDarkLookAndFeel = "org.kde.breezedark.desktop";
        };
      };
    };
  };
}
