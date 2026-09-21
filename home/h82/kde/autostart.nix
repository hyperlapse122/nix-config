{
  pkgs,
  lib,
  osConfig,
  ...
}:

let
  # programs._1password-gui.package carries apply = pkg.override { polkitPolicyOwners },
  # so pkgs._1password-gui is a different derivation that ships no polkit policy.
  onePassword = osConfig.programs._1password-gui.package;
in
lib.mkIf (!osConfig.my.bootstrap) {
  # force = true rather than home-manager.backupFileExtension: both apps rewrite
  # these paths from their own "start at login" settings, and a backup extension
  # only clears the first collision.
  xdg.configFile."autostart/1password.desktop" = {
    force = true;
    text = ''
      [Desktop Entry]
      Type=Application
      Name=1Password
      Exec=${onePassword}/bin/1password --silent
      Hidden=false
      NoDisplay=true
      X-KDE-autostart-phase=2
    '';
  };

  xdg.configFile."autostart/kleopatra.desktop" = {
    force = true;
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Kleopatra
      Exec=${pkgs.kdePackages.kleopatra}/bin/kleopatra --daemon
      Hidden=false
      NoDisplay=true
      X-KDE-autostart-phase=2
    '';
  };
}
