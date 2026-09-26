{
  pkgs,
  lib,
  osConfig,
  ...
}:

let
  # Plasma hands ~/.config/autostart to systemd-xdg-autostart-generator, which
  # names each unit app-<desktop file id>@autostart.service and sets Restart=no.
  # A drop-in is the only way to change that: a full unit under
  # systemd.user.services would shadow the generated one, ExecStart included.
  restartOnFailure = ''
    [Service]
    Restart=on-failure
    RestartSec=5s
  '';

  # programs._1password-gui.package carries apply = pkg.override { polkitPolicyOwners },
  # so pkgs._1password-gui is a different derivation that ships no polkit policy.
  onePassword = osConfig.programs._1password-gui.package;
in
lib.mkIf (!osConfig.my.bootstrap) {
  # force = true rather than home-manager.backupFileExtension: these apps rewrite
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

  xdg.configFile."autostart/discord.desktop" = {
    force = true;
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Discord
      Exec=${pkgs.discord}/bin/discord --start-minimized
      Hidden=false
      NoDisplay=true
      X-KDE-autostart-phase=2
    '';
  };

  xdg.configFile."autostart/telegram.desktop" = {
    force = true;
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Telegram
      Exec=${pkgs.telegram-desktop}/bin/Telegram -startintray
      Hidden=false
      NoDisplay=true
      X-KDE-autostart-phase=2
    '';
  };

  xdg.configFile."systemd/user/app-discord@autostart.service.d/restart.conf".text = restartOnFailure;
  xdg.configFile."systemd/user/app-telegram@autostart.service.d/restart.conf".text = restartOnFailure;
}
