{ config, lib, pkgs, pkgs-unstable, ... }:
let
  cfg = config.my.system.desktop.plasma;
in {
  options.my.system.desktop.plasma = {
    enable = lib.mkEnableOption "KDE Plasma 6 데스크톱 (SDDM Wayland + KWallet PAM 통합)";
  };

  config = lib.mkIf cfg.enable {
    # KDE Plasma 6 패키지 셋을 nixos-unstable 에서 가져온다.
    # NOTE: services.desktopManager.plasma6 는 내부적으로 pkgs.kdePackages.* 를 광범위하게
    #       참조하므로 (kwin, plasma-workspace, plasma-desktop, systemsettings, ...) 셋 전체를
    #       오버레이로 갈아끼우는 것이 가장 깔끔하다 — KDE 패키지 간 ABI/스키마 일관성 유지.
    # NOTE: 이 모듈을 enable 한 호스트에만 적용된다 (mkIf cfg.enable). plasma 안 쓰는 호스트는
    #       stable kdePackages 그대로 둠.
    nixpkgs.overlays = [
      (final: prev: { kdePackages = pkgs-unstable.kdePackages; })
    ];

    # KDE Plasma 6
    services.xserver.enable = true;
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };
    services.desktopManager.plasma6.enable = true;
    services.displayManager.defaultSession = "plasma";

    # KDE Wallet — git-credential-manager (home/modules/git.nix) 가 secretservice 로 KWallet 사용.
    security.pam.services.login.kwallet.enable = true;
    security.pam.services.kde.kwallet.enable = true;
  };
}
