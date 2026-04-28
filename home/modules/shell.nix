{ config, lib, pkgs, ... }:
let
  cfg = config.my.shell;
in {
  options.my.shell = {
    enable = lib.mkEnableOption "Shell environment (zsh, direnv, mise, CLI utilities)";
  };

  config = lib.mkIf cfg.enable {
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
          sudo nixos-rebuild switch --flake ~/nix-config "$@"
        }

        rebuild-test() {
          sudo nixos-rebuild test --flake ~/nix-config "$@"
        }

        rebuild-boot() {
          sudo nixos-rebuild boot --flake ~/nix-config "$@"
        }
      '';
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

    # 셸 유틸리티
    home.packages = with pkgs; [
      ripgrep
      fd
      bat
      eza
      jq
      fzf
    ];
  };
}
