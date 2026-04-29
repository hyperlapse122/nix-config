{ config, lib, pkgs, ... }:
let
  cfg = config.my.shell;
in {
  options.my.shell = {
    enable = lib.mkEnableOption "Shell environment";
  };

  config = lib.mkIf cfg.enable {
    programs.zsh = {
      enable = true;
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
          "utility"
          "completion"
          "git"
          "archive"
          "ssh"
          "prompt"
        ];
      };
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

    # mise shims — programs.mise 의 zsh 통합은 인터랙티브 셸에만 활성화되므로,
    # systemd user 유닛 / GUI 앱 / 비인터랙티브 스크립트에서도 mise 가 관리하는
    # 툴체인 (node, python, go 등) 을 찾을 수 있도록 shims 경로를 PATH 에 추가.
    home.sessionPath = [
      "${config.home.homeDirectory}/.local/share/mise/shims"
    ];

    # 셸 유틸리티
    home.packages = with pkgs; [
      ripgrep
      fd
      bat
      eza
      jq
      fzf
      btop
      lsof
      curl
    ];
  };
}
