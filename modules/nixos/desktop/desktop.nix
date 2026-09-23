{ pkgs, ... }:
{
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;

  programs._1password.enable = true;

  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "h82" ];
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-hangul
        fcitx5-gtk
        kdePackages.fcitx5-qt
      ];
      settings = {
        inputMethod = {
          "Groups/0" = {
            Name = "기본값";
            "Default Layout" = "us";
            DefaultIM = "hangul";
          };
          "Groups/0/Items/0" = {
            Name = "keyboard-us";
            Layout = "";
          };
          "Groups/0/Items/1" = {
            Name = "hangul";
            Layout = "";
          };
          GroupOrder = {
            "0" = "기본값";
          };
        };
        globalOptions = {
          "Hotkey/TriggerKeys" = {
            "0" = "Hangul";
          };
          "Hotkey/EnumerateGroupForwardKeys" = {
            "0" = "Super+space";
          };
        };
        addons = {
          hangul = {
            globalSection = {
              Keyboard = "Dubeolsik";
            };
            sections = {
              HanjaModeToggleKey = {
                "0" = "Hangul_Hanja";
                "1" = "F9";
              };
            };
          };
        };
      };
    };
  };

  environment.etc."xdg/fcitx5/conf/classicui.conf".text = ''
    Vertical Candidate List=False
    WheelForPaging=True
    Font="Pretendard 10"
    MenuFont="Pretendard 10"
    TrayFont="Pretendard Bold 10"
    TrayOutlineColor=#000000
    TrayTextColor=#ffffff
    PreferTextIcon=False
    ShowLayoutNameInIcon=True
    UseInputMethodLanguageToDisplayText=True
    Theme=default
    DarkTheme=default-dark
    UseDarkTheme=True
    UseAccentColor=True
    PerScreenDPI=True
    ForceWaylandDPI=0
    EnableFractionalScale=True
  '';

  environment.etc."xdg/fcitx5/conf/hangul.conf".text = ''
    # 자판 배열
    Keyboard=Dubeolsik
    # 자동 재배열
    AutoReorder=False
    # 같은 글쇠 두 번 입력 시 결합
    CombiOnDoubleStroke=False
    # 초성이 아닌 자모 결합
    NonChoseongCombi=False
    # 단어 단위 확정
    WordCommit=False
    # 한자 모드
    HanjaMode=False

    [HanjaModeToggleKey]
    0=Hangul_Hanja
    1=F9

    [PrevPage]
    0=Up

    [NextPage]
    0=Down

    [PrevCandidate]
    0=Shift+Tab

    [NextCandidate]
    0=Tab
  '';

  environment.etc."xdg/fcitx5/conf/kimpanel.conf".text = ''
    # 텍스트 아이콘 선호
    PreferTextIcon=False
  '';

  environment.etc."xdg/kwinrc".text = ''
    [Wayland]
    InputMethod=/run/current-system/sw/share/applications/fcitx5-wayland-launcher.desktop

    [ElectricBorders]
    Bottom=None
    BottomLeft=None
    BottomRight=None
    Left=None
    Right=None
    Top=None
    TopLeft=None
    TopRight=None

    [EdgeBarrier]
    CornerBarrier=false
    EdgeBarrier=0
  '';

  environment.etc."xdg/ksmserverrc".text = ''
    [General]
    loginMode=emptySession
  '';

  environment.etc."xdg/powerdevilrc".text = ''
    [AC/Display]
    DimDisplayIdleTimeoutSec=-1
    DimDisplayWhenIdle=false

    [Battery/Display]
    DimDisplayIdleTimeoutSec=120
    DimDisplayWhenIdle=true

    [LowBattery/Display]
    DimDisplayIdleTimeoutSec=60
    DimDisplayWhenIdle=true
  '';

  environment.etc."xdg/dolphinrc".text = ''
    [General]
    HomeUrl=/home/h82
    RememberOpenedTabs=false
  '';

  environment.etc."xdg/krunnerrc".text = ''
    [General]
    FreeFloating=true
    historyBehavior=ImmediateCompletion

    [Runners/krunner_kill]
    sorting=1
    triggerWord=kill
    useTriggerWord=true
  '';

  environment.etc."xdg/spectaclerc".text = ''
    [General]
    rememberSelectionRect=Never
  '';

  environment.etc."xdg/plasma-localerc".text = ''
    [Translations]
    LANGUAGE=ko:en_US
  '';

  environment.etc."xdg/kdeglobals".text = ''
    [General]
    TerminalApplication=ghostty

    [Locale]
    Language=ko:en_US
  '';
}
