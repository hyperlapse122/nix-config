{
  config,
  pkgs,
  lib,
  hostKind,
  ...
}:
let
  # Desktop parts are gated where they stand rather than moved to a separate
  # module, so the NixOS package list keeps its order and its store path. The
  # gate is the hostKind special argument: an import conditional on `config`
  # would recurse.
  nixos = hostKind == "nixos";
  gui = lib.optionals nixos;
in
{
  imports = [
    ./agents
  ]
  ++ gui [ ./desktop ]
  ++ [
    ./dev
    ./security
    ./shell
    ./t3code.nix
  ];

  home.username = config.my.user.name;
  home.homeDirectory = config.my.user.home;
  home.stateVersion = "26.05";

  home.packages =
    (
      with pkgs;
      [
        antigravity-cli
        bun
      ]
      ++ gui [ discord ]
      ++ [
        gh
        glab
      ]
      ++ gui [
        google-chrome
        kdePackages.kleopatra
        kdePackages.ksshaskpass
        kdePackages.okular
        libreoffice-qt
      ]
      ++ [
        nodejs
        python3
      ]
      ++ gui [ telegram-desktop ]
      ++ [ uv ]
      ++ gui [ yubioath-flutter ]
    )
    ++ gui [
      (import ../../packages/claude-desktop.nix { inherit pkgs; })
      (import ../../packages/chatgpt.nix { inherit pkgs; })
    ]
    ++ [
      (import ../../packages/claude-code.nix { inherit pkgs; })
      (import ../../packages/codex.nix { inherit pkgs; })
      (
        let
          nixTools = import ../../packages/nix-tools.nix { inherit pkgs; };
        in
        if nixos then nixTools.nr else nixTools.nrLinux
      )
    ]
    ++ gui [ (import ../../packages/orca.nix { inherit pkgs; }) ];

  home.sessionVariables.LANGUAGE = "ko_KR:ko:en_US:en";
}
