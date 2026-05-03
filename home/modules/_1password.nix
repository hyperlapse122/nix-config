{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my._1password;
in
{
  options.my._1password = {
    enable = lib.mkEnableOption "1Password launcher .desktop override (enables the Quick Access global shortcut Ctrl+Shift+Space)";
  };

  config = lib.mkIf cfg.enable {
    # Override the original 1password.desktop installed at the system level by
    # programs._1password-gui (hosts/common/programs/_1password.nix) with a user-level copy.
    # XDG search precedence: $XDG_DATA_HOME/applications (~/.local/share/applications) >
    #   $XDG_DATA_DIRS/applications (NixOS system / user profile).
    # So this file shadows the package's original, and the KDE menu / KRunner / Plasma panel launchers all see this definition.
    #
    # Key change: the [Desktop Action QuickAccess] section + X-KDE-Shortcuts=Ctrl+Shift+Space.
    # KDE's KGlobalAccel reads .desktop Action metadata and registers it as a global shortcut,
    # so no separate kglobalshortcutsrc / plasma-manager configuration is needed.
    #
    # NOTE: Exec= is the PATH-based `1password`, not an absolute path
    #       (e.g. /opt/1Password/1password — the Linux native install layout).
    #       NixOS places its setuid wrapper at /run/wrappers/bin/1password, and only via that wrapper
    #       do browser integration / system keyring / SSH agent work properly. Pinning a Nix-store
    #       path or /opt path bypasses the wrapper and breaks integration.
    #       (Same comment as the autostart .desktop in hosts/common/programs/_1password.nix)
    xdg.configFile."1Password/ssh/agent.toml".text = ''
      # This is the 1Password SSH agent config file, which allows you to customize the
      # behavior of the SSH agent running on this machine.
      #
      # You can use it to:
      # * Enable keys from other vaults than the Private vault
      # * Control the order in which keys are offered to SSH servers
      #
      # EXAMPLE
      #
      # By default, all keys in your Private vault(s) are enabled:
      #
      #  [[ssh-keys]]
      #  vault = "Private"
      #
      # You can enable more keys by adding more `[[ssh-keys]]` entries.
      # For example, to first enable item "My SSH Key" from "My Custom Vault":
      #
      #  [[ssh-keys]]
      #  item = "My SSH Key"
      #  vault = "My Custom Vault"
      #
      #  [[ssh-keys]]
      #  vault = "Private"
      #
      # You can test the result by running:
      #
      #  SSH_AUTH_SOCK=~/.1password/agent.sock ssh-add -l
      #
      # More examples can be found here:
      #  https://developer.1password.com/docs/ssh/agent/config
      [[ssh-keys]]
      item = "cwgsuvmyhwtnwiir3sqcdeaglm"

      [[ssh-keys]]
      item = "5rocflo3i7h7yyich4e4k4zqgi"
    '';

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
