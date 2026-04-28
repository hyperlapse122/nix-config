{ config, pkgs, ... }:
{
  home.username = "h82";
  home.homeDirectory = "/home/h82";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # 기본 패키지
  home.packages = with pkgs; [
    ripgrep
    fd
    bat
    eza
    jq
    fzf
    git-credential-manager
    libsecret
  ];

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ls = "eza";
      ll = "eza -l";
      cat = "bat";
    };
    initContent = ''
      rebuild() {
        local host=$(hostname)
        sudo nixos-rebuild switch --flake ~/nix-config#$host "$@"
      }

      rebuild-test() {
        local host=$(hostname)
        sudo nixos-rebuild test --flake ~/nix-config#$host "$@"
      }

      rebuild-boot() {
        local host=$(hostname)
        sudo nixos-rebuild boot --flake ~/nix-config#$host "$@"
      }
    '';
  };

  programs.git = {
    enable = true;
    settings = {
      # User Settings
      user.name = "Joosung Park";
      user.email = "iam@h82.dev";

      init.defaultBranch = "main";
      pull.rebase = true;

      # Git Credential Manager 사용 설정
      credential.helper = "${pkgs.git-credential-manager}/bin/git-credential-manager";
      credential.credentialStore = "secretservice";
      credential.guiPrompt = "true";
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
  };

  programs.mise = {
    enable = true;
    enableZshIntegration = true;
  };
}