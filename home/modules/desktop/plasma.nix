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

      # 하단 패널 (작업 표시줄): Plasma 6 표준 위젯 셋 + 자주 쓰는 앱 (Konsole / VS Code / Zed) 핀
      # NOTE: `programs.plasma.panels` 를 선언하면 Plasma 의 기본 패널 레이아웃을 통째로
      #       대체한다. 기본 패널을 그대로 두고 런처만 추가하는 방법은 없으므로,
      #       표준 위젯 (kickoff / pager / icontasks / systemtray / digitalclock / showdesktop)
      #       을 모두 명시해야 정상적인 작업 표시줄이 된다.
      #       (참고: nix-community/plasma-manager modules/panels.nix)
      # NOTE: `iconTasks` 헬퍼는 기본적으로 `org.kde.plasma.icontasks` (Plasma 6 기본 -
      #       아이콘 전용 작업 관리자) 를 생성한다. 텍스트 라벨이 있는 클래식 작업 관리자
      #       (`org.kde.plasma.taskmanager`) 가 필요하면 `iconsOnly = false` 로 바꿀 것.
      # NOTE: 런처 URI 형식은 `applications:<id>.desktop` — KDE 의 표준 .desktop 참조.
      #       id 는 실제 설치된 .desktop 파일명과 정확히 일치해야 한다.
      #         - Konsole: org.kde.konsole.desktop  (plasma6 데스크탑 매니저에 포함)
      #         - VS Code: code.desktop             (pkgs.vscode 가 제공)
      #         - Zed:     dev.zed.Zed.desktop      (pkgs.zed-editor 가 제공)
      panels = [
        {
          location = "bottom";
          widgets = [
            "org.kde.plasma.kickoff"
            "org.kde.plasma.pager"
            {
              iconTasks = {
                launchers = [
                  "applications:org.kde.konsole.desktop"
                  "applications:code.desktop"
                  "applications:dev.zed.Zed.desktop"
                ];
              };
            }
            "org.kde.plasma.marginsseparator"
            "org.kde.plasma.systemtray"
            "org.kde.plasma.digitalclock"
            "org.kde.plasma.showdesktop"
          ];
        }
      ];

      # 패널 레이아웃을 매 Plasma 세션 시작마다 강제 재적용
      # NOTE: plasma-manager 는 `panels` 선언을 기반으로 KWin 시작 시 한 번 실행되는
      #       desktop script 를 생성한다. 기본값(`runAlways = false`)에서는 최초 1회만
      #       실행되므로, 사용자가 GUI 에서 위젯을 옮기거나 핀을 제거하면 그 변경이
      #       다음 부팅까지 그대로 남는다. `runAlways = true` 는 매 세션 시작마다
      #       해당 desktop script 를 재실행하여 panels = [ ... ] 선언을 권위 있는
      #       상태로 되돌린다 — 즉 위에서 핀한 Konsole / VS Code / Zed 가 항상 복귀한다.
      #       (참고: nix-community/plasma-manager modules/startup.nix runAlways 옵션)
      # NOTE: 이 토글은 패널에만 영향을 준다. Plasma 의 다른 설정 (테마, 단축키, KWin rule)
      #       을 매 home-manager activation 마다 통째로 덮어쓰고 싶다면 별도로
      #       `programs.plasma.overrideConfig = true;` 를 추가해야 한다 — 단,
      #       그 옵션은 GUI 로 만진 설정 파일들을 광범위하게 삭제하므로 신중히 사용.
      startup.desktopScript."panels".runAlways = true;

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

        # 세션 복원 비활성화: 로그인 시 빈 세션으로 시작
        # NOTE: ksmserverrc 의 [General] loginMode 가 세션 시작 정책을 결정한다.
        #       - "default"             : 이전 세션 복원 (Plasma 기본값)
        #       - "restoreSavedSession" : 수동 저장 세션 복원
        #       - "emptySession"        : 항상 빈 세션으로 시작 (← 우리가 원하는 값)
        #       (참고: KDE/plasma-workspace ksmserver/server.cpp, kcms/session)
        "ksmserverrc"."General" = {
          loginMode = "emptySession";
        };
      };
    };
  };
}
