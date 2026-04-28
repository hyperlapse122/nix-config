{ pkgs, ... }:
{
  imports = [
    ./modules
  ];

  home.username = "h82";
  home.homeDirectory = "/home/h82";
  home.stateVersion = "25.11";

  # 폰트
  home.packages = with pkgs; [
    pretendard
    jetbrains-mono
    nerd-fonts.jetbrains-mono
    d2coding
  ];

  programs.home-manager.enable = true;

  # 모듈 활성화
  my.shell.enable = true;
  my.git.enable = true;
  my.gpg.enable = true;
  my.desktop.plasma.enable = true;
  my.editors.vscode.enable = true;
  my.editors.zed.enable = true;
  my.i18n.fcitx5.enable = true;
}
