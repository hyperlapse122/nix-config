{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./agents
    ./desktop
    ./dev
    ./security
    ./shell
  ];

  home.username = config.my.user.name;
  home.homeDirectory = config.my.user.home;
  home.stateVersion = "26.05";

  home.packages =
    (with pkgs; [
      antigravity-cli
      bun
      discord
      gh
      glab
      google-chrome
      kdePackages.kleopatra
      kdePackages.ksshaskpass
      kdePackages.okular
      libreoffice-qt
      nodejs
      python3
      telegram-desktop
      uv
      yubioath-flutter
    ])
    ++ [
      (import ../../packages/claude-desktop.nix { inherit pkgs; })
      (import ../../packages/claude-code.nix { inherit pkgs; })
      (import ../../packages/nix-tools.nix { inherit pkgs; }).nr
      (import ../../packages/orca.nix { inherit pkgs; })
    ];

  home.sessionVariables.LANGUAGE = "ko_KR:ko:en_US:en";
}
