{ pkgs, ... }:
let
  # fontconfig silently skips a family name it cannot match, so a typo here
  # would quietly break the fallback order.
  emojiFont = "Twitter Color Emoji";
in
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
          emojiFont
        ];
        serif = [
          "Noto Serif"
          emojiFont
        ];
        monospace = [
          "JetBrainsMono Nerd Font"
          "D2CodingLigature Nerd Font"
          "D2KodingLigature Nerd Font"
          emojiFont
        ];
        emoji = [
          emojiFont
          "Noto Color Emoji"
        ];
      };
    };
  };
}
