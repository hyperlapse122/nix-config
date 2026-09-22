{ pkgs, lib, ... }:
{
  imports = [
    ./claude.nix
    ./containers.nix
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
      discord
      gh
      glab
      google-chrome
      kdePackages.kleopatra
      kdePackages.ksshaskpass
      nodejs
      python3
      telegram-desktop
      uv
      yubioath-flutter
    ])
    ++ [
      (import ../../packages/nix-tools.nix { inherit pkgs; }).nr
      (import ../../packages/orca.nix { inherit pkgs; })
    ];

  home.sessionVariables.LANGUAGE = "ko_KR:ko:en_US:en";
}
