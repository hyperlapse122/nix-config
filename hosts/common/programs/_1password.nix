{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.system.programs._1password;
in
{
  options.my.system.programs._1password = {
    enable = lib.mkEnableOption "1Password (CLI + GUI, including browser integration)";
    autostart = lib.mkEnableOption "1Password autostart (--silent, runs in the system tray)";
  };

  config = lib.mkIf cfg.enable {
    # 1Password (GUI + CLI)
    # Must be enabled at the NixOS level because it requires a setuid wrapper for browser integration.
    # If installed only as an environment package, code-signature verification with the browser extension does not work.
    programs._1password = {
      enable = true;
      package = pkgs._1password-cli;
    };
    programs._1password-gui = {
      enable = true;
      package = pkgs._1password-gui;
      # Single-user (h82) assumption — same hard-coded policy as git.nix's git identity.
      # Parameterize when a second user is added.
      polkitPolicyOwners = [ "h82" ];
    };

    # Autostart — XDG-compliant desktop environments (including KDE Plasma) automatically run
    # /etc/xdg/autostart/*.desktop entries at login.
    # `--silent` keeps the window hidden and runs only in the system tray.
    # `Exec=1password ...` is resolved through PATH to /run/wrappers/bin/1password (the setuid wrapper),
    # so browser integration / code-signature verification still works correctly. Pinning a Nix-store
    # path or an /opt path bypasses the wrapper and breaks integration.
    # Per the single-user (h82) assumption, install system-wide under /etc/xdg/autostart
    # (~/.config/autostart is not used because this module is the system layer, not home-manager).
    # See dotfiles/dotconfig/autostart/1password-autostart.desktop for the original desktop entry.
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
