{ config, lib, pkgs, ... }:
let
  cfg = config.my.env;

  # 사용자 세션 전역 환경 변수.
  # 원래 ~/.config/environment.d/*.conf 로 흩어져 있던 값들을 한 군데로 모은 것.
  # 호스트별로 분기되지 않으므로 home/modules/ 의 단일 토글로 둔다.
  sessionVars = {
    # ── mise / rustup ────────────────────────────────────────────────
    # rustup-init 이 PATH 에 다른 cargo 바이너리가 보여도 경고 없이 진행하도록.
    # mise 가 toolchain 을 권위 있게 관리하므로 rustup 의 PATH 충돌 검사는 불필요.
    RUSTUP_INIT_SKIP_PATH_CHECK = "yes";

    # ── pinentry / gpg-agent ─────────────────────────────────────────
    # pinentry-qt 가 패스프레이즈를 KDE Wallet 에 캐시하도록.
    # gpg-agent 는 사용자 systemd 유닛이라 systemd.user.sessionVariables 경로로
    # 변수가 전달되어야 한다 (아래 두 옵션 모두에 동일하게 설정).
    PINENTRY_KDE_USE_WALLET = "1";

    # ── PowerShell ───────────────────────────────────────────────────
    # 텔레메트리 / 자동 업데이트 체크 끔.
    POWERSHELL_TELEMETRY_OPTOUT = "1";
    POWERSHELL_CLI_TELEMETRY_OPTOUT = "1";
    POWERSHELL_UPDATECHECK = "Off";
    POWERSHELL_UPDATECHECK_OPTOUT = "1";

    # ── .NET ─────────────────────────────────────────────────────────
    # CLI / SDK 텔레메트리 + CoreCLR 진단 끔.
    # COMPlus_EnableDiagnostics 는 .NET 5+ 에서 DOTNET_EnableDiagnostics 로 이름이
    # 바뀌었으나 레거시 이름도 여전히 인식되므로 원본 dotfile 값 그대로 보존.
    DOTNET_CLI_TELEMETRY_OPTOUT = "1";
    DOTNET_TELEMETRY_OPTOUT = "1";
    COMPlus_EnableDiagnostics = "0";

    # ── Firefox ──────────────────────────────────────────────────────
    # FIREFOX_PATH 는 표준 Firefox 변수가 아니라 사용자 스크립트가 참조하는 커스텀 값.
    # MOZ_USE_XINPUT2 는 X11 백엔드 전용이라 Wayland 세션에서는 무시되지만 안전망으로 유지.
    FIREFOX_PATH = "firefox";
    MOZ_USE_XINPUT2 = "1";

    # ── Electron ─────────────────────────────────────────────────────
    # Electron 앱이 Wayland 가능하면 Ozone Wayland 백엔드를, 아니면 X11 을 자동 선택.
    # KDE Plasma 6 Wayland 세션에서 VS Code / Slack 등 Electron 앱이 네이티브 Wayland 로 뜬다.
    ELECTRON_OZONE_PLATFORM_HINT = "auto";

    # NOTE: 입력기 변수 (XMODIFIERS / GTK_IM_MODULE / QT_IM_MODULE / SDL_IM_MODULE) 는
    #       의도적으로 비워둔다. 이 시스템은 fcitx5 + waylandFrontend = true 구성이라
    #       home-manager 의 i18n.inputMethod 가 알아서 처리한다 — 자세한 사유는
    #       home/modules/i18n/fcitx5.nix 의 NOTE 참고. 구 dotfile 의 kime XMODIFIERS 는
    #       마이그레이션 시점에 의도적으로 폐기됨.
  };
in {
  options.my.env = {
    enable = lib.mkEnableOption "사용자 세션 환경 변수 (구 ~/.config/environment.d 대체)";
  };

  config = lib.mkIf cfg.enable {
    # 로그인 셸 (~/.profile, ~/.zshenv) 에 export.
    # TTY 로그인 / SSH / 터미널이 직접 spawn 한 자식 프로세스가 여기서 변수를 받는다.
    home.sessionVariables = sessionVars;

    # systemd --user 가 관리하는 모든 유닛에 주입.
    # 구체적으로 ~/.config/environment.d/10hm-session-vars.conf 가 생성되며,
    # gpg-agent (PINENTRY_KDE_USE_WALLET) 와 KDE Plasma Wayland 세션이 띄우는
    # 모든 GUI 앱 (Electron / Firefox 등) 이 이 경로로 변수를 받는다.
    # home.sessionVariables 만으로는 systemd user 유닛까지 전파되지 않으므로
    # 동일한 attrset 을 양쪽에 명시적으로 설정해서 셸/세션 양쪽 다 커버.
    systemd.user.sessionVariables = sessionVars;
  };
}
