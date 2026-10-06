{ pkgs, ... }:
{
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      pretendard
      jetbrains-mono
      nerd-fonts.jetbrains-mono
      nerd-fonts.d2coding
      # CBDT build. twemoji-color-font is OpenType-SVG, which only Firefox
      # draws in color.
      twitter-color-emoji
    ];
    fontconfig = {
      enable = true;
      # Twemoji follows each primary font so emoji in plain text reach it
      # before DejaVu Sans's monochrome glyphs. It also covers space, digits,
      # `#`, and `*`, so it must never come before a primary font.
      defaultFonts = {
        sansSerif = [
          "Pretendard"
          "Twitter Color Emoji"
        ];
        serif = [
          "Noto Serif"
          "Twitter Color Emoji"
        ];
        monospace = [
          "JetBrainsMono Nerd Font"
          "D2CodingLigature Nerd Font"
          "D2KodingLigature Nerd Font"
          "Twitter Color Emoji"
        ];
        emoji = [
          "Twitter Color Emoji"
          "Noto Color Emoji"
        ];
      };
    };
  };
}
