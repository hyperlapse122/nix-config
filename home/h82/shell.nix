{ ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

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
