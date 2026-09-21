{ pkgs, ... }:
{
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      pretendard
      jetbrains-mono
      nerd-fonts.jetbrains-mono
      twemoji-color-font
    ];
    fontconfig = {
      enable = true;
      defaultFonts = {
        sansSerif = [ "Pretendard" ];
        monospace = [ "JetBrainsMono Nerd Font" ];
        emoji = [
          "Twitter Color Emoji"
          "Noto Color Emoji"
        ];
      };
    };
  };
}
