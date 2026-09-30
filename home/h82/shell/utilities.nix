{ pkgs, ... }:
{
  # Command-line tools for scripts and pipelines. They are plain commands: no
  # shell integration, so zsh and prezto keep their key bindings and aliases.
  home.packages = with pkgs; [
    bat
    fd
    file
    fzf
    jq
    lsof
    moreutils
    procps
    ripgrep
    shellcheck
    shfmt
    tree
    unzip
    wget
    wl-clipboard
    yq-go
    zip
  ];
}
