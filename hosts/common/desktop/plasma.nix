{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.desktop.plasma;
in {
  options.my.system.desktop.plasma = {
    enable = lib.mkEnableOption "KDE Plasma 6 데스크톱 (SDDM Wayland + KWallet PAM 통합)";
  };

  config = lib.mkIf cfg.enable {
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
