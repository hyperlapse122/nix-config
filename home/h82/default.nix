{ pkgs, ... }:
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
}
