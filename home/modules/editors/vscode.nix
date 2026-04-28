{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.my.editors.vscode;
in {
  options.my.editors.vscode = {
    enable = lib.mkEnableOption "Visual Studio Code";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.vscode;
      defaultText = "pkgs.vscode";
      description = "VSCode 패키지 (vscode, vscodium, vscode-insiders 중 선택)";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      package = cfg.package;

      # 확장은 nix-vscode-extensions(VS Code Marketplace)에서 관리
      profiles.default = {
        extensions = let
          marketplace = inputs.nix-vscode-extensions.extensions.${pkgs.system};
        in [
          marketplace.vscode-marketplace.arktypeio.arkdark
          marketplace.vscode-marketplace.biomejs.biome
          marketplace.vscode-marketplace.bradlc.vscode-tailwindcss
          marketplace.vscode-marketplace.bufbuild.vscode-buf
          marketplace.vscode-marketplace.christian-kohler.npm-intellisense
          marketplace.vscode-marketplace.davidanson.vscode-markdownlint
          marketplace.vscode-marketplace.dbaeumer.vscode-eslint
          marketplace.vscode-marketplace.dnicolson.binary-plist
          marketplace.vscode-marketplace.docker.docker
          marketplace.vscode-marketplace.donjayamanne.githistory
          marketplace.vscode-marketplace.dotjoshjohnson.xml
          marketplace.vscode-marketplace.editorconfig.editorconfig
          marketplace.vscode-marketplace.esbenp.prettier-vscode
          marketplace.vscode-marketplace.github.codespaces
          marketplace.vscode-marketplace.github.copilot-chat
          marketplace.vscode-marketplace.github.vscode-github-actions
          marketplace.vscode-marketplace.github.vscode-pull-request-github
          marketplace.vscode-marketplace.inlang.vs-code-extension
          marketplace.vscode-marketplace.ms-vscode.powershell
          marketplace.vscode-marketplace.redhat.java
          marketplace.vscode-marketplace.redhat.vscode-yaml
          marketplace.vscode-marketplace.repreng.csv
          marketplace.vscode-marketplace.rust-lang.rust-analyzer
          marketplace.vscode-marketplace.sst-dev.opencode
          marketplace.vscode-marketplace.tauri-apps.tauri-vscode
          marketplace.vscode-marketplace.tombi-toml.tombi
          marketplace.vscode-marketplace.typescriptteam.native-preview
          marketplace.vscode-marketplace.usernamehw.errorlens
          marketplace.vscode-marketplace.vitest.explorer
          marketplace.vscode-marketplace.vscjava.vscode-gradle
          marketplace.vscode-marketplace.vscjava.vscode-java-debug
          marketplace.vscode-marketplace.vscjava.vscode-java-dependency
          marketplace.vscode-marketplace.vscjava.vscode-java-pack
          marketplace.vscode-marketplace.vscjava.vscode-java-test
          marketplace.vscode-marketplace.vscjava.vscode-maven
          marketplace.vscode-marketplace.wakatime.vscode-wakatime
          marketplace.vscode-marketplace.yoavbls.pretty-ts-errors
        ];

        # settings.json 내용을 그대로 Nix로
        userSettings = {
          # 외관
          "workbench.colorTheme" = "Catppuccin Mocha";
          "workbench.iconTheme" = "material-icon-theme";
          "editor.fontFamily" = "'JetBrainsMono Nerd Font', 'D2Coding', monospace";
          "editor.fontSize" = 14;
          "editor.fontLigatures" = true;
          "editor.lineNumbers" = "relative";
          "editor.minimap.enabled" = false;
          "editor.renderWhitespace" = "boundary";
          "editor.bracketPairColorization.enabled" = true;
          "editor.guides.bracketPairs" = "active";

          # 에디터 동작
          "editor.formatOnSave" = true;
          "editor.tabSize" = 2;
          "editor.rulers" = [ 80 120 ];
          "files.trimTrailingWhitespace" = true;
          "files.insertFinalNewline" = true;
          "files.eol" = "\n";

          # 터미널
          "terminal.integrated.fontFamily" = "'JetBrainsMono Nerd Font'";
          "terminal.integrated.defaultProfile.linux" = "zsh";

          # Nix
          "nix.enableLanguageServer" = true;
          "nix.serverPath" = "${pkgs.nixd}/bin/nixd";
          "[nix]"."editor.tabSize" = 2;

          # direnv 통합
          "direnv.restart.automatic" = true;

          # Git
          "git.confirmSync" = false;
          "git.autofetch" = true;
          "gitlens.codeLens.enabled" = false;

          # Telemetry 끄기
          "telemetry.telemetryLevel" = "off";
          "redhat.telemetry.enabled" = false;

          # 업데이트 끄기 (Nix가 관리하니까)
          "update.mode" = "none";
          "extensions.autoCheckUpdates" = false;
          "extensions.autoUpdate" = false;
        };

        # 키바인딩
        keybindings = [
          {
            key = "ctrl+shift+/";
            command = "editor.action.blockComment";
            when = "editorTextFocus && !editorReadonly";
          }
          {
            key = "alt+up";
            command = "editor.action.moveLinesUpAction";
            when = "editorTextFocus && !editorReadonly";
          }
          {
            key = "alt+down";
            command = "editor.action.moveLinesDownAction";
            when = "editorTextFocus && !editorReadonly";
          }
        ];
      };
    };

    # nixd가 Nix LSP로 동작하도록 패키지도 같이 설치
    home.packages = [ pkgs.nixd ];
  };
}