{ ... }:
{
  programs.ghostty = {
    enable = true;
    settings = {
      # Ghostty picks emoji from this list before fontconfig, and falls back to
      # Noto Color Emoji rather than the fontconfig emoji alias, so Twemoji
      # has to be listed here. It comes last so ASCII stays in JetBrainsMono.
      font-family = [
        "JetBrainsMono Nerd Font"
        "D2CodingLigature Nerd Font"
        "D2KodingLigature Nerd Font"
        "Twitter Color Emoji"
      ];
    };
  };
}
