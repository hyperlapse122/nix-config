{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.system.desktop.plasma;
in
{
  options.my.system.desktop.plasma = {
    enable = lib.mkEnableOption "KDE Plasma 6 desktop (SDDM Wayland + KWallet PAM integration)";
  };

  config = lib.mkIf cfg.enable {
    # KDE Plasma 6
    services.xserver.enable = true;
    fonts.packages = [ pkgs.pretendard ];

    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      settings.Theme.Font = "Pretendard";
    };
    services.desktopManager.plasma6.enable = true;
    services.displayManager.defaultSession = "plasma";

    # Registers the native messaging host used by the KDE Plasma Browser Integration
    # extension for Chrome and Chromium.
    programs.chromium = {
      enable = true;
      enablePlasmaBrowserIntegration = true;
    };

    # KDE Wallet — git-credential-manager (home/modules/git.nix) uses KWallet via secretservice.
    security.pam.services.login.kwallet.enable = true;
    security.pam.services.kde.kwallet.enable = true;
  };
}
