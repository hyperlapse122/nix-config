{ pkgs, ... }:
{
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      pretendard
      jetbrains-mono
      nerd-fonts.jetbrains-mono
      nerd-fonts.d2coding
      # The CBDT Twemoji build. The OpenType-SVG build draws in color only in
      # Firefox; Chromium, Qt, and GTK fall back to its monochrome glyphs.
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
