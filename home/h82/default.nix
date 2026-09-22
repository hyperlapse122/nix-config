{ pkgs, lib, ... }:
{
  imports = [
    ./claude.nix
    ./fcitx5.nix
    ./gemini.nix
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

  home.packages =
    (with pkgs; [
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
      yubioath-flutter
    ])
    ++ [ (import ../../packages/nix-tools.nix { inherit pkgs; }).nr ];

  home.sessionVariables.LANGUAGE = "ko_KR:ko:en_US:en";
}
