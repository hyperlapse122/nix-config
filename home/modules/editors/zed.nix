{ config, lib, pkgs, ... }:
let
  cfg = config.my.editors.zed;
in {
  options.my.editors.zed = {
    enable = lib.mkEnableOption "Zed Editor configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.zed-editor = {
      enable = true;
      package = pkgs.zed-editor;

      # Contents of ~/.config/zed/settings.json (synced from dotfiles)
      userSettings = {
        # Panels (right dock)
        project_panel = { dock = "right"; };
        outline_panel = { dock = "right"; };
        collaboration_panel = { dock = "right"; };
        git_panel = { dock = "right"; };

        # Prettier
        prettier = {};

        # AI Agent
        agent = {
          play_sound_when_agent_done = "when_hidden";
          new_thread_location = "new_worktree";
          dock = "left";
          default_model = {
            provider = "copilot_chat";
            model = "gpt-5-mini";
            enable_thinking = false;
            effort = "high";
          };
          favorite_models = [];
          model_parameters = [];
        };

        # Edit Predictions
        edit_predictions = {
          provider = "copilot";
        };

        # Telemetry
        telemetry = {
          diagnostics = false;
          metrics = false;
        };

        # Keymap
        base_keymap = "JetBrains";

        # Fonts
        ui_font_size = 16;
        ui_font_family = "Pretendard";
        ui_font_fallbacks = [ "Pretendard JP" ];
        buffer_font_size = 12;
        buffer_font_family = "JetBrainsMono Nerd Font";
        buffer_font_fallbacks = [ "D2CodingLigature Nerd Font" ];
        buffer_font_features = {
          calt = true;
        };

        # Theme
        theme = {
          mode = "system";
          light = "One Light";
          dark = "One Dark";
        };

        # Extensions to auto-install
        auto_install_extensions = {
          biome = true;
          graphql = true;
          html = true;
          dockerfile = true;
          git-firefly = true;
          toml = true;
          wakatime = true;
          # NixOS overlay: Nix language support
          nix = true;
        };

        # LSP
        lsp = {
          biome = {
            settings = {
              require_config_file = true;
            };
          };
          vtsls = {
            settings = {
              # For TypeScript:
              typescript = { tsserver = { maxTsServerMemory = 16184; }; };
              # For JavaScript:
              javascript = { tsserver = { maxTsServerMemory = 16184; }; };
            };
          };
          # NixOS overlay: nixd
          nixd = {};
        };

        # Misc
        autosave = "on_window_change";
        restore_on_startup = "launchpad";
        minimap = {
          show = "auto";
        };

        # Agent Servers (ACP)
        agent_servers = {
          gemini = { type = "registry"; };
          codex-acp = { type = "registry"; };
          claude-acp = { type = "registry"; };
          OpenCode = {
            type = "custom";
            command = "opencode";
            args = [ "acp" ];
          };
        };

        # ─── NixOS overlay (kill-switches & Nix language config, not in dotfiles) ───
        # Disable auto-updates (Nix is the source of truth)
        auto_update = false;

        # Nix language configuration (nixd LSP + nixfmt formatter)
        languages = {
          "Nix" = {
            language_servers = [ "nixd" ];
            formatter = {
              external = {
                command = "nixfmt";
              };
            };
          };
        };
      };

      # Contents of ~/.config/zed/keymap.json (synced from dotfiles)
      userKeymaps = [
        {
          context = "Workspace";
          bindings = {};
        }
        {
          context = "Editor && vim_mode == insert";
          bindings = {};
        }
        {
          bindings = {
            "cmd-alt-o" = [
              "agent::NewExternalAgentThread"
              {
                agent = {
                  custom = {
                    name = "OpenCode";
                    command = {
                      command = "opencode";
                      args = [ "acp" ];
                    };
                  };
                };
              }
            ];
          };
        }
      ];
    };

    # External tools (invoked by Zed)
    home.packages = with pkgs; [
      nixd
      nixfmt
    ];
  };
}
