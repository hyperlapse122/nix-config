{ pkgs, lib, ... }:
{
  imports = [
    ./fcitx5.nix
    ./git.nix
    ./gpg.nix
    ./kde
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
    gh
    glab
    google-chrome
    kdePackages.kleopatra
    nodejs
    omp
    python3
    uv
  ];

  home.sessionVariables.LANGUAGE = "ko_KR:ko:en_US:en";
}
