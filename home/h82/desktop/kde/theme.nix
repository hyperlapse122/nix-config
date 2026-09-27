{ pkgs, lib, ... }:
let
  kwrite = "${pkgs.kdePackages.kconfig}/bin/kwriteconfig6";
  applyColorScheme = "${pkgs.kdePackages.plasma-workspace}/bin/plasma-apply-colorscheme";
in
{
  # ~/.config/kdeglobals already carries light color groups that override the
  # Breeze Dark defaults in /etc/xdg/kdeglobals, so rewrite them here. This runs
  # only when the Home Manager generation changes, not on every rebuild.
  home.activation.kdeTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -x "${kwrite}" ]; then
      ${kwrite} --file kdeglobals --group KDE --key LookAndFeelPackage org.kde.breezedark.desktop
      ${kwrite} --file kdeglobals --group Icons --key Theme breeze-dark
    fi

    # plasma-apply-colorscheme owns ColorScheme: it writes nothing when that key
    # already names the scheme. It aborts without a display, hence offscreen.
    if [ -x "${applyColorScheme}" ]; then
      QT_QPA_PLATFORM=offscreen ${applyColorScheme} BreezeDark || true
    fi
  '';
}
