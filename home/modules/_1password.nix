{ config, lib, pkgs, ... }:
let
  cfg = config.my._1password;
in {
  options.my._1password = {
    enable = lib.mkEnableOption "1Password 런처 .desktop 오버라이드 (Quick Access 전역 단축키 Ctrl+Shift+Space 활성화)";
  };

  config = lib.mkIf cfg.enable {
    # 시스템 레벨 (hosts/common/programs/_1password.nix) 에서 programs._1password-gui 가 깐
    # 원본 1password.desktop 을 사용자 영역에서 덮어쓴다.
    # XDG 검색 우선순위: $XDG_DATA_HOME/applications (~/.local/share/applications) >
    #   $XDG_DATA_DIRS/applications (NixOS 시스템/사용자 프로파일).
    # 따라서 이 파일이 패키지 원본을 가리고, KDE 메뉴 / KRunner / Plasma 패널 런처 모두 이 정의를 본다.
    #
    # 핵심 변경: [Desktop Action QuickAccess] 섹션 + X-KDE-Shortcuts=Ctrl+Shift+Space.
    # KDE 의 KGlobalAccel 이 .desktop 의 Action 메타데이터를 읽어 전역 단축키로 등록하므로
    # 별도 kglobalshortcutsrc / plasma-manager 설정이 필요 없다.
    #
    # NOTE: Exec= 는 절대경로 (예: /opt/1Password/1password — Linux native install 형태) 가 아니라
    #       PATH-based `1password` 다. NixOS 는 setuid wrapper 를 /run/wrappers/bin/1password 에 두고,
    #       브라우저 통합 / 시스템 키링 / SSH agent 가 이 wrapper 를 통해서만 동작한다.
    #       Nix store path 나 /opt 경로를 직접 박으면 wrapper 를 우회해서 깨짐.
    #       (동일 주석: hosts/common/programs/_1password.nix 의 autostart .desktop)
    xdg.dataFile."applications/1password.desktop".text = ''
      [Desktop Entry]
      Name=1Password
      Actions=QuickAccess;
      Exec=1password %U
      Terminal=false
      Type=Application
      Icon=1password
      StartupWMClass=1Password
      Comment=Password manager and secure wallet
      MimeType=x-scheme-handler/onepassword;
      Categories=Office;

      [Desktop Action QuickAccess]
      Name=Open Quick Access
      Icon=tab-new
      Exec=1password --quick-access %U
      X-KDE-Shortcuts=Ctrl+Shift+Space
    '';
  };
}
