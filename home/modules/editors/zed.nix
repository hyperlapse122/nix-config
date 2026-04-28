{ config, lib, pkgs, ... }:
let
  cfg = config.my.editors.zed;
in {
  options.my.editors.zed = {
    enable = lib.mkEnableOption "Zed editor";
  };

  config = lib.mkIf cfg.enable {
    programs.zed-editor = {
      enable = true;

      # nixpkgs에 있는 일부 확장
      extensions = [
        "nix"
        "toml"
        "dockerfile"
        "html"
        "make"
        "git-firefly"
        "catppuccin"
      ];

      # ~/.config/zed/settings.json 의 내용
      userSettings = {
        # 외관
        theme = {
          mode = "dark";
          light = "Catppuccin Latte";
          dark = "Catppuccin Mocha";
        };
        ui_font_size = 15;
        buffer_font_size = 14;
        buffer_font_family = "JetBrainsMono Nerd Font";

        # 에디터 동작
        format_on_save = "on";
        tab_size = 2;
        soft_wrap = "editor_width";
        relative_line_numbers = true;
        cursor_blink = false;

        # 터미널
        terminal = {
          shell = {
            program = "zsh";
          };
          font_family = "JetBrainsMono Nerd Font";
          font_size = 13;
        };

        # Vim 모드 (선호 시)
        # vim_mode = true;

        # AI / Assistant (필요 시 활성화)
        features = {
          # edit_prediction_provider = "zed";
        };

        # 자동 업데이트 끄기 (Nix가 관리)
        auto_update = false;

        # Telemetry
        telemetry = {
          diagnostics = false;
          metrics = false;
        };

        # 언어별 설정
        languages = {
          "Nix" = {
            language_servers = [ "nixd" ];
            formatter = {
              external = {
                command = "nixfmt";
              };
            };
          };
          "Rust" = {
            tab_size = 4;
          };
          "Python" = {
            tab_size = 4;
          };
        };

        # LSP 설정
        lsp = {
          nixd = {
            settings = {
              # nixd 자체 설정
            };
          };
        };
      };

      # ~/.config/zed/keymap.json
      userKeymaps = [
        {
          context = "Editor";
          bindings = {
            "ctrl-shift-k" = "editor::DeleteLine";
          };
        }
      ];
    };

    # 외부 도구들 (Zed가 호출)
    home.packages = with pkgs; [
      nixd
      nixfmt-rfc-style
    ];
  };
}