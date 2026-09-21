{ config, ... }:
{
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    prezto = {
      enable = true;
      pmodules = [
        "environment"
        "terminal"
        "editor"
        "history"
        "directory"
        "spectrum"
        "git"
        "utility"
        "completion"
        "syntax-highlighting"
        "history-substring-search"
        "autosuggestions"
        "prompt"
      ];
    };

    history = {
      size = 10000;
      save = 10000;
      path = "$HOME/.local/state/zsh/history";
      extended = true;
      ignoreDups = true;
      share = true;
    };

    initContent = ''
      # Keep the user's local completion functions ahead of system functions.
      fpath=($HOME/.local/share/zsh/site-functions(N) $fpath)
    '';
  };

  programs.mise = {
    enable = true;
    enableZshIntegration = true;
  };
}
