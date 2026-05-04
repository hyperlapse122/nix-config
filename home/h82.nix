{ inputs, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [
    ./modules
  ];

  home.username = "h82";
  home.homeDirectory = "/home/h82";
  home.stateVersion = "25.11";

  # User packages
  home.packages =
    with pkgs;
    [
      pretendard
      pretendard-jp
      jetbrains-mono
      nerd-fonts.jetbrains-mono
      d2coding
      nerd-fonts.d2coding
    ]
    ++ [
      inputs.codex-cli-nix.packages.${system}.default
    ];

  programs.home-manager.enable = true;

  # Module enables
  my.shell.enable = true;
  my.git.enable = true;
  my.gpg.enable = true;
  my.ssh.enable = true;
  my.env.enable = true;
  my.chrome.enable = true;
  my.obsidian.enable = true;
  my._1password.enable = true;
  my.desktop.plasma.enable = true;
  my.editors.vscode.enable = true;
  my.editors.zed.enable = true;
  my.i18n.fcitx5.enable = true;
  my.dev.agents.enable = true;
  my.dev.docker.enable = true;
  my.dev.native-build.enable = true;
  my.dev.nodejs.enable = true;
  my.dev.opencode.enable = true;
  my.dev.playwright.enable = true;
  my.dev.python.enable = true;
  my.dev.tokscale.enable = true;
}
