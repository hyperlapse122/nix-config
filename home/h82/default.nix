{ pkgs, lib, ... }:
{
  imports = [
    ./git.nix
    ./gpg.nix
    ./shell.nix
    ./ssh.nix
    ./terminal.nix
  ];

  home.username = "h82";
  home.homeDirectory = "/home/h82";
  home.stateVersion = "26.05";

  home.sessionVariables.DISABLE_AUTOUPDATER = "1";

  home.packages = with pkgs; [
    antigravity-cli
    bun
    claude-code
    codex
    gh
    glab
    google-chrome
    nodejs
    omp
  ];

  home.sessionVariables.LANGUAGE = "ko_KR:ko:en_US:en";

  home.activation.configureKdeDesktop = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -x "${pkgs.kdePackages.kconfig}/bin/kwriteconfig6" ]; then
      ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kwinrc --group Wayland --key InputMethod --type path /run/current-system/sw/share/applications/fcitx5-wayland-launcher.desktop
      ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file plasma-localerc --group Translations --key LANGUAGE ko:en_US
      ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kdeglobals --group Locale --key Language ko:en_US
    fi
  '';
}
