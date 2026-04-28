{ config, lib, pkgs, pkgs-unstable, ... }:
let
  cfg = config.my.system.programs._1password;
in {
  options.my.system.programs._1password = {
    enable = lib.mkEnableOption "1Password (CLI + GUI, 브라우저 통합 포함)";
    autostart = lib.mkEnableOption "1Password 자동 시작 (--silent, 시스템 트레이 상주)";
  };

  config = lib.mkIf cfg.enable {
    # 1Password (GUI + CLI)
    # 브라우저 통합용 setuid wrapper 가 필요해서 NixOS 레벨에서 활성화해야 한다.
    # 단순히 환경 패키지로 깔면 브라우저 확장과의 코드 서명 검증이 동작하지 않음.
    # 패키지는 nixos-unstable 에서 가져옴 — 1Password 는 잦은 보안/기능 업데이트가 필요.
    programs._1password = {
      enable = true;
      package = pkgs-unstable._1password-cli;
    };
    programs._1password-gui = {
      enable = true;
      package = pkgs-unstable._1password-gui;
      # 단일 사용자 (h82) 가정 — git.nix 의 git identity 와 동일한 hard-code 정책.
      # 두 번째 사용자가 추가될 때 parameterize.
      polkitPolicyOwners = [ "h82" ];
    };

    # 자동 시작 — XDG 호환 데스크톱 환경 (KDE Plasma 포함) 이 로그인 시
    # /etc/xdg/autostart/*.desktop 을 자동 실행한다.
    # `--silent` 로 띄우면 창은 숨기고 시스템 트레이에만 상주.
    # `Exec=1password ...` 는 PATH 를 통해 /run/wrappers/bin/1password (setuid wrapper) 로 해석되므로
    # 브라우저 통합용 코드 서명 검증이 그대로 동작 — Nix store path 를 직접 박으면 wrapper 를 우회해서 깨짐.
    # 단일 사용자 (h82) 가정에 따라 /etc/xdg/autostart 에 시스템 전역으로 설치
    # (~/.config/autostart 가 아닌 이유: home-manager 가 아니라 이 모듈이 system 레이어이기 때문).
    # 원본 데스크톱 항목은 dotfiles/dotconfig/autostart/1password-autostart.desktop 참고.
    environment.etc."xdg/autostart/1password.desktop" = lib.mkIf cfg.autostart {
      text = ''
        [Desktop Entry]
        Name=1Password
        Exec=1password --silent %U
        Terminal=false
        Type=Application
        Icon=1password
        StartupWMClass=1Password
        Comment=Password manager and secure wallet
        MimeType=x-scheme-handler/onepassword;
        Categories=Office;
      '';
    };
  };
}
