{ pkgs, ... }:
{
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      pretendard
      jetbrains-mono
      nerd-fonts.jetbrains-mono
      nerd-fonts.d2coding
      twemoji-color-font
    ];
    fontconfig = {
      enable = true;
      defaultFonts = {
        sansSerif = [ "Pretendard" ];
        monospace = [
          "JetBrainsMono Nerd Font"
          "D2KodingLigature Nerd Font"
        ];
        emoji = [
          "Twitter Color Emoji"
          "Noto Color Emoji"
        ];
      };
    };
  };
}
