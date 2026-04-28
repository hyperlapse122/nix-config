{ config, lib, pkgs, pkgs-unstable, ... }:
let
  cfg = config.my.editors.vscode;
in {
  options.my.editors.vscode = {
    enable = lib.mkEnableOption "Visual Studio Code";

    # 기본값은 nixos-unstable 의 vscode (stable 채널보다 빠른 업데이트 주기 필요).
    # 확장은 여전히 stable 의 nix-vscode-extensions 오버레이(pkgs.vscode-marketplace)
    # 에서 가져온다 — VS Code 마켓플레이스 .vsix 는 버전 호환성이 넓어 문제없음.
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs-unstable.vscode;
      defaultText = "pkgs-unstable.vscode";
      description = "VSCode Package (defaults to nixos-unstable)";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      package = cfg.package;

      # 확장은 nix-vscode-extensions(VS Code Marketplace)에서 관리
      # 호스트 pkgs에 overlay가 적용되어 있어 pkgs.vscode-marketplace로 접근 (allowUnfree 전파됨)
      profiles.default = {
        extensions = with pkgs.vscode-marketplace; [
          arktypeio.arkdark
          biomejs.biome
          bradlc.vscode-tailwindcss
          bufbuild.vscode-buf
          christian-kohler.npm-intellisense
          davidanson.vscode-markdownlint
          dbaeumer.vscode-eslint
          dnicolson.binary-plist
          docker.docker
          donjayamanne.githistory
          dotjoshjohnson.xml
          editorconfig.editorconfig
          esbenp.prettier-vscode
          github.codespaces
          github.copilot-chat
          github.vscode-github-actions
          github.vscode-pull-request-github
          inlang.vs-code-extension
          ms-vscode.powershell
          redhat.java
          redhat.vscode-yaml
          repreng.csv
          rust-lang.rust-analyzer
          sst-dev.opencode
          tauri-apps.tauri-vscode
          tombi-toml.tombi
          typescriptteam.native-preview
          usernamehw.errorlens
          vitest.explorer
          vscjava.vscode-gradle
          vscjava.vscode-java-debug
          vscjava.vscode-java-dependency
          vscjava.vscode-java-pack
          vscjava.vscode-java-test
          vscjava.vscode-maven
          wakatime.vscode-wakatime
          yoavbls.pretty-ts-errors
          bbenoist.nix
        ];

        # ~/.config/Code/User/settings.json 의 내용 (dotfiles에서 동기화)
        userSettings = {
          # 언어별 포매터
          "[json]" = {
            "editor.defaultFormatter" = "vscode.json-language-features";
          };
          "[jsonc]" = {
            "editor.defaultFormatter" = "biomejs.biome";
          };
          "[typescript]" = {
            "editor.defaultFormatter" = "biomejs.biome";
          };
          "[typescriptreact]" = {
            "editor.defaultFormatter" = "biomejs.biome";
          };
          "[yaml]" = {
            "editor.defaultFormatter" = "biomejs.biome";
          };

          # AG Cockpit
          "agCockpit.groupingEnabled" = true;
          "agCockpit.notificationEnabled" = true;

          # Biome
          "biome.requireConfiguration" = true;
          "biome.suggestInstallingGlobally" = false;

          # Chat / MCP
          "chat.agent.maxRequests" = 1000;
          "chat.instructionsFilesLocations" = {
            ".github/instructions" = true;
          };
          "chat.mcp.gallery.enabled" = true;
          "chat.tools.terminal.autoApprove" = {
            "/.*/" = true;
          };

          # Claude Code
          "claudeCode.allowDangerouslySkipPermissions" = true;
          "claudeCode.preferredLocation" = "panel";

          # C#
          "csharp.experimental.debug.hotReload" = true;

          # Docker
          "docker.extension.enableComposeLanguageServer" = false;

          # Editor
          "editor.accessibilitySupport" = "off";
          "editor.aiStats.enabled" = true;
          "editor.codeActionsOnSave" = {
            "source.fixAll.biome" = "explicit";
            "source.organizeImports.biome" = "explicit";
          };
          "editor.fontFamily" = "'JetBrainsMono Nerd Font', 'JetBrains Mono', 'D2Coding Nerd Font', 'D2Coding', 'Droid Sans Mono', 'monospace', monospace";
          "editor.fontLigatures" = true;
          "editor.formatOnSave" = true;
          "editor.quickSuggestions" = {
            strings = "on";
          };
          "editor.smoothScrolling" = true;
          "editor.tabSize" = 2;

          # Emmet
          "emmet.preferences" = {};
          "emmet.showAbbreviationSuggestions" = false;

          # Explorer
          "explorer.autoReveal" = false;
          "explorer.incrementalNaming" = "smart";

          # Files
          "files.autoSave" = "onFocusChange";
          "files.enableTrash" = false;

          # Git
          "git.autofetch" = true;
          "git.blame.editorDecoration.enabled" = false;
          "git.confirmSync" = false;
          "git.enableCommitSigning" = true;
          "git.enableSmartCommit" = true;
          "git.followTagsWhenSync" = true;
          "git.replaceTagsWhenPull" = true;

          # GitHub Copilot
          "github.copilot.chat.agent.thinkingTool" = true;
          "github.copilot.chat.codesearch.enabled" = true;
          "github.copilot.chat.commitMessageGeneration.instructions" = [
            {
              text = "Use multi-line conventional commit message format. First line should be a short summary (max 72 characters), followed by a blank line, and then a detailed description if necessary.";
            }
          ];
          "github.copilot.chat.languageContext.fix.typescript.enabled" = true;
          "github.copilot.chat.languageContext.inline.typescript.enabled" = true;
          "github.copilot.chat.languageContext.typescript.enabled" = true;
          "github.copilot.chat.localeOverride" = "ko";
          "github.copilot.enable" = {
            "*" = true;
            plaintext = false;
            markdown = false;
            scminput = false;
            json = true;
          };
          "github.copilot.nextEditSuggestions.enabled" = true;
          "github.gitProtocol" = "https";
          "githubPullRequests.codingAgent.promptForConfirmation" = false;

          # GitLab
          "gitlab.authentication.oauthClientIds" = {
            "https://git.jpi.app" = "c173cf3eb02fabd54c93401cadce5a4a1f8c034e2d85e1f95e9d33dc5e5243e5";
          };
          "gitlab.duoAgentPlatform.enabled" = false;
          "gitlab.duoChat.enabled" = false;
          "gitlab.duoCodeSuggestions.enabled" = false;

          # GitLens
          "gitlens.ai.model" = "vscode";
          "gitlens.ai.vscode.model" = "copilot:gpt-4.1";
          "gitlens.gitkraken.mcp.autoEnabled" = false;

          # JS/TS
          "js/ts.experimental.useTsgo" = false;
          "js/ts.implicitProjectConfig.checkJs" = true;
          "js/ts.implicitProjectConfig.experimentalDecorators" = true;
          "js/ts.preferences.autoImportFileExcludePatterns" = [ "**/dist/**" ];
          "js/ts.preferences.autoImportSpecifierExcludeRegexes" = [
            "^(node:)?os$"
            "^node_modules.+$"
            "^type$"
          ];
          "js/ts.suggest.completeFunctionCalls" = true;
          "js/ts.updateImportsOnFileMove.enabled" = "never";

          # JSON Schemas
          "json.schemaDownload.trustedDomains" = {
            "https://biomejs.dev" = true;
            "https://developer.microsoft.com/json-schemas/" = true;
            "https://inlang.com" = true;
            "https://json-schema.org/" = true;
            "https://json.schemastore.org/" = true;
            "https://models.dev" = true;
            "https://opencode.ai" = true;
            "https://raw.githubusercontent.com/" = true;
            "https://raw.githubusercontent.com/devcontainers/spec/" = true;
            "https://raw.githubusercontent.com/microsoft/vscode/" = true;
            "https://schemastore.azurewebsites.net/" = true;
            "https://turbo.build" = true;
            "https://turborepo.dev" = true;
            "https://ui.shadcn.com" = true;
            "https://unpkg.com" = true;
            "https://www.schemastore.org/" = true;
          };

          # Kilo Code
          "kilo-code.allowedCommands" = [ "git log" "git diff" "git show" ];
          "kilo-code.deniedCommands" = [];
          "kilo-code.provider" = "openrouter";

          # Markdownlint
          "markdownlint.lintWorkspaceGlobs" = [
            "**/*.{md,mkd,mdwn,mdown,markdown,markdn,mdtxt,mdtext,workbook}"
            "!**/*.code-search"
            "!**/bower_components"
            "!**/node_modules"
            "!**/.git"
            "!**/vendor"
            "!**/.sisyphus"
          ];

          # Misc
          "prettier.enable" = false;
          "python.analysis.typeCheckingMode" = "basic";
          "redhat.telemetry.enabled" = false;
          "remote.SSH.remotePlatform" = {
            "deskmini.tetra-gecko.ts.net" = "linux";
          };

          # Sherlock
          "sherlock.previewLanguageTag" = "en";
          "sherlock.userId" = "f2117860-db4f-4634-9ddb-58c999457bce";

          # Terminal
          "terminal.integrated.enableImages" = true;
          "terminal.integrated.fontLigatures.enabled" = true;
          "terminal.integrated.stickyScroll.enabled" = false;

          # Todo Tree
          "todo-tree.general.tags" = [ "BUG" "HACK" "FIXME" "TODO" "XXX" ];

          # VSCode Edge DevTools
          "vscode-edge-devtools.webhintInstallNotification" = true;

          # Window
          "window.restoreWindows" = "none";

          # Disable workthrough
          "workbench.welcomePage.walkthroughs.openOnInstall" = false;

          # ─── NixOS overlay (kill-switches & Nix LSP, dotfiles에는 없음) ───
          # 자동 업데이트 끄기 (Nix가 관리)
          "update.mode" = "none";
          "extensions.autoCheckUpdates" = false;
          "extensions.autoUpdate" = false;

          # Nix LSP (bbenoist.Nix 확장이 사용)
          "nix.enableLanguageServer" = true;
          "nix.serverPath" = "${pkgs.nixd}/bin/nixd";
          "[nix]" = {
            "editor.tabSize" = 2;
          };
        };

        # ~/.config/Code/User/keybindings.json 의 내용 (dotfiles에서 동기화)
        keybindings = [
          {
            key = "shift+enter";
            command = "workbench.action.terminal.sendSequence";
            when = "terminalFocus";
            args = {
              text = "\\\r\n";
            };
          }
          {
            key = "ctrl+enter";
            command = "workbench.action.terminal.sendSequence";
            when = "terminalFocus";
            args = {
              text = "\\\r\n";
            };
          }
          {
            key = "backspace";
            command = "deleteFile";
            when = "filesExplorerFocus && foldersViewVisible && !inputFocus";
          }
          {
            key = "backspace";
            command = "deleteFile";
            when = "filesExplorerFocus && foldersViewVisible && !inputFocus";
          }
          {
            key = "delete";
            command = "deleteFile";
            when = "filesExplorerFocus && foldersViewVisible && !inputFocus";
          }
          {
            key = "shift+delete";
            command = "deleteFile";
            when = "filesExplorerFocus && foldersViewVisible && !explorerResourceMoveableToTrash && !inputFocus";
          }
          {
            key = "shift+delete";
            command = "-deleteFile";
            when = "filesExplorerFocus && foldersViewVisible && !inputFocus";
          }
          {
            key = "delete";
            command = "-deleteFile";
            when = "filesExplorerFocus && foldersViewVisible && !explorerResourceMoveableToTrash && !inputFocus";
          }
        ];
      };
    };

    # nixd가 Nix LSP로 동작하도록 패키지도 같이 설치
    home.packages = [ pkgs.nixd ];
  };
}
