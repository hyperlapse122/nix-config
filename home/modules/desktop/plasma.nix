{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.plasma;
in {
  options.my.desktop.plasma = {
    enable = lib.mkEnableOption "KDE Plasma desktop configuration (plasma-manager)";

    # 화면 자동 잠금 (idle 타이머 기반).
    # 기본 true 는 Plasma 의 표준 동작 (idle 시 화면 잠금) 을 그대로 둔다는 뜻.
    # 호스트 단위로 끄려면 그 호스트의 default.nix 에서:
    #   home-manager.users.h82.my.desktop.plasma.autoLock.enable = false;
    # NOTE: 이 토글은 idle 잠금 (kscreenlockerrc [Daemon] Autolock) 만 끈다.
    #       절전/재개 시 잠금 (LockOnResume) 은 별도 설정이며 보안상 기본값(true)을 유지한다.
    autoLock.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether KDE Screen Locker auto-locks the screen after the idle timeout.
        Default true preserves Plasma's stock behavior. Disable per host via
        `home-manager.users.h82.my.desktop.plasma.autoLock.enable = false;` in
        the host's `default.nix`. Lock-on-resume from suspend is governed by a
        separate setting and is intentionally left at Plasma's default (locked).
      '';
    };

    # 화면 자동 끄기 (DPMS — PowerDevil 의 turnOffDisplay).
    # 기본 true 는 Plasma 의 표준 DPMS 동작을 그대로 둔다는 뜻.
    # 호스트 단위로 끄려면 그 호스트의 default.nix 에서:
    #   home-manager.users.h82.my.desktop.plasma.screenOff.enable = false;
    # NOTE: false 일 때 AC / battery / lowBattery 모든 프로파일의 turnOffDisplay.idleTimeout
    #       을 "never" 로 설정 (powerdevilrc 내부적으로 -1 로 매핑).
    #       Display dimming (어두워짐) 은 별도이므로 영향받지 않는다 — 필요하면 따로 끌 것.
    screenOff.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether the display turns off when idle (DPMS via PowerDevil's
        `turnOffDisplay`). Default true preserves Plasma's stock behavior.
        Disable per host via
        `home-manager.users.h82.my.desktop.plasma.screenOff.enable = false;` in
        the host's `default.nix`. When disabled, sets the idle timeout to
        `"never"` for AC, battery, and lowBattery profiles. Display dimming is
        a separate setting and is not touched.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.plasma = {
      enable = true;

      # 화면 자동 잠금 — autoLock 토글이 꺼진 호스트에서만 false 를 명시.
      # plasma-manager 의 autoLock 옵션은 nullOr bool 이라서 null (= 옵션 미정의) 일 때
      # kscreenlockerrc 에 키를 쓰지 않으므로 Plasma 기본값 (idle 시 잠금) 이 그대로 적용된다.
      # 따라서 토글이 켜진 호스트에서는 lib.mkIf 가 옵션을 정의하지 않아 기본 동작이 보존됨.
      kscreenlocker.autoLock = lib.mkIf (!cfg.autoLock.enable) false;

      # 화면 자동 끄기 (DPMS) — screenOff 토글이 꺼진 호스트에서 모든 프로파일을 "never" 로.
      # plasma-manager 의 turnOffDisplay.idleTimeout 은 enum ["never"] | ints.between 30 600000
      # 이고, "never" 는 powerdevilrc 의 -1 로 매핑된다 (modules/powerdevil.nix 의 apply).
      # NOTE: VMware guest 같은 데스크탑/VM 에는 battery / lowBattery 가 없지만 plasma-manager 가
      #       세 프로파일을 무조건 powerdevilrc 에 기록하므로 셋 다 적어둔다 — 실제 PowerDevil 은
      #       해당 상태로 진입하지 않으므로 무해. 노트북 호스트에서도 "never" 일관성이 자연스럽다.
      # NOTE: idleTimeoutWhenLocked 는 함께 설정하면 안 된다 — plasma-manager 가 "never" 와의
      #       조합에 대해 assertion 실패시킴 (modules/powerdevil.nix 의 createAssertions). null 유지.
      powerdevil.AC.turnOffDisplay.idleTimeout = lib.mkIf (!cfg.screenOff.enable) "never";
      powerdevil.battery.turnOffDisplay.idleTimeout = lib.mkIf (!cfg.screenOff.enable) "never";
      powerdevil.lowBattery.turnOffDisplay.idleTimeout = lib.mkIf (!cfg.screenOff.enable) "never";

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

      # 하단 패널 (작업 표시줄): Plasma 6 표준 위젯 셋 + 자주 쓰는 앱 핀
      # NOTE: `programs.plasma.panels` 를 선언하면 Plasma 의 기본 패널 레이아웃을 통째로
      #       대체한다. 기본 패널을 그대로 두고 런처만 추가하는 방법은 없으므로,
      #       표준 위젯 (kickoff / pager / icontasks / systemtray / digitalclock / showdesktop)
      #       을 모두 명시해야 정상적인 작업 표시줄이 된다.
      #       (참고: nix-community/plasma-manager modules/panels.nix)
      # NOTE: `iconTasks` 헬퍼는 기본적으로 `org.kde.plasma.icontasks` (Plasma 6 기본 -
      #       아이콘 전용 작업 관리자) 를 생성한다. 텍스트 라벨이 있는 클래식 작업 관리자
      #       (`org.kde.plasma.taskmanager`) 가 필요하면 `iconsOnly = false` 로 바꿀 것.
      # NOTE: 런처 URI 형식은 `applications:<id>.desktop` — KDE 의 표준 .desktop 참조.
      #       id 는 실제 설치된 .desktop 파일명과 정확히 일치해야 한다. 핀 순서는
      #       파일 관리자 → 터미널 → 브라우저 → 에디터 (사용 빈도 / 카테고리 묶음).
      #         - Dolphin: org.kde.dolphin.desktop   (plasma6 데스크탑 매니저에 포함)
      #         - Konsole: org.kde.konsole.desktop   (plasma6 데스크탑 매니저에 포함)
      #         - Chrome:  google-chrome.desktop     (pkgs.google-chrome 가 제공)
      #         - VS Code: code.desktop              (pkgs.vscode 가 제공)
      #         - Zed:     dev.zed.Zed.desktop       (pkgs.zed-editor 가 제공)
      panels = [
        {
          location = "bottom";
          # 플로팅 패널 — Plasma 6 의 기본 스타일 (화면 가장자리에서 살짝 떨어진 마진을 두고 떠 있는 모습).
          # NOTE: plasma-manager 의 `floating` 은 bool 옵션 (modules/panels.nix). `location = "floating"`
          #       이라는 값도 enum 에 존재하지만 그건 위치 자체를 자유 배치로 만드는 별개 옵션이므로
          #       혼동하지 말 것 — 우리가 원하는 "하단에 있되 떠 있는" 동작은 이 플래그로만 켠다.
          # NOTE: lengthMode / alignment 등 관련 옵션은 모두 plasma-manager 기본값을 그대로 쓴다 —
          #       즉 Plasma 6 의 표준 플로팅 패널 동작 (fit 길이 / 중앙 정렬) 이 그대로 적용된다.
          floating = true;
          widgets = [
            "org.kde.plasma.kickoff"
            "org.kde.plasma.pager"
            {
              iconTasks = {
                launchers = [
                  "applications:google-chrome.desktop"
                  "applications:org.kde.dolphin.desktop"
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

        # 터치패드 자연 스크롤 — 모든 터치패드의 기본값
        # NOTE: Plasma 6 Wayland 에서 KWin libinput 백엔드는 kcminputrc 의
        #       [Libinput][Defaults][Touchpad] 그룹을 장치별 설정 fallback
        #       (= 기본값) 으로 사용한다. 따라서 이 한 줄로 호스트에 연결된 모든
        #       터치패드에 자연 스크롤이 적용된다 — vendor / product / device-name
        #       별로 키를 따로 적을 필요가 없다.
        #       (참고: KDE/kwin src/backends/libinput/device.{h,cpp} 의 m_defaultConfig)
        # NOTE: 레거시 ~/.config/touchpadrc ([libinput] naturalScroll=true) 는
        #       Plasma 5 → 6 마이그레이션 전용 파일이며 (KDE/plasma-desktop
        #       kcms/touchpad/kded/kded.cpp), Plasma 6 Wayland 의 KWin 은 이 파일을
        #       더 이상 읽지 않는다. 그래서 dotfiles 의 touchpadrc 를 그대로
        #       이식하지 않고 kcminputrc 의 Defaults 그룹에 쓴다.
        # NOTE: KConfig 의 중첩 그룹 [A][B][C] 는 plasma-manager configFile 에서
        #       단일 속성 키 "A/B/C" 로 표현한다 — write_config.py 가 / 를 그룹
        #       구분자로 분해해 [A][B][C] 형태로 직렬화하기 때문. configFile 스키마는
        #       attrsOf × 3 (file → group → key) 로 고정이라 깊은 attrset 중첩 (예:
        #       Libinput.Defaults.Touchpad.NaturalScroll) 은 타입 체크에서 거절된다.
        "kcminputrc"."Libinput/Defaults/Touchpad" = {
          NaturalScroll = true;
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
