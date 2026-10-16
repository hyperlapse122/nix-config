/*
  T3 Code nightly, one artifact per trait: my.t3.cli.enable installs the
  headless `t3` CLI and my.t3.desktop.enable the desktop app. Its Codex and
  Claude sessions run the flake's own codex and claude with their user-level
  settings, so nothing here adds a copy of either. The T3 Code settings that
  differ from the pinned nightly's defaults are merged into its own settings
  files on activation, and the Antigravity runtime it requires is installed
  where T3 Code looks for it.

  The desktop app runs on NixOS and macOS. A non-NixOS Linux host that enables
  it fails the assertion below rather than a build.
*/
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.t3;
  nixos = config.my.kind == "nixos";
  darwin = config.my.kind == "darwin";
  desktopSupported = nixos || darwin;

  agentTools = import ../../packages/agent-tools.nix { inherit pkgs; };
  merger = "${agentTools.agentSettings}/bin/agent-settings";
  installer = "${agentTools.t3codeAntigravityInstall}/bin/t3code-antigravity-install";
  linker = "${agentTools.t3codeAntigravityLink}/bin/t3code-antigravity-link";
  t3 = cfg.cli.enable || cfg.desktop.enable;

  # The T3 Code part of the agent instructions reaches only sessions T3 Code
  # starts, through each instance's launch arguments; a terminal session never
  # reads it. Claude Code loads CLAUDE.md from a directory passed with
  # --add-dir when CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD is set, which
  # the instance environment sets. --append-system-prompt-file would not work:
  # T3 Code's own appended prompt, sent at initialize, replaces it. Codex
  # takes developer_instructions as a -c override, which replaces the
  # config.toml value codex.nix declares, so it carries the system part too.
  instructions = import ./agents/instructions/render.nix { inherit pkgs lib; };
  claudeInstructionsDir = ".t3/instructions/claude-code";

  # The Antigravity instances this file selects a model on. Each gets its home
  # prepared on activation, so the plugins and instructions are there before
  # T3 Code first starts it.
  antigravityInstances = [ textGenerationInstance ];
  # The instance T3 Code generates commit messages and titles with.
  textGenerationInstance = "antigravity";

  # The Antigravity runtime the pinned T3 Code requires, preinstalled so the
  # provider needs only a sign-in.
  antigravity = import ../../packages/antigravity-acp.nix { inherit pkgs; };
  antigravityPin = pkgs.writeText "antigravity-acp-pin.json" (builtins.toJSON antigravity.pin);

  # The settings that differ from the pinned T3 Code's schema defaults; a
  # value left at its default follows T3 Code when that default changes. App
  # state (onboarding marks, folded panels, favorites, and every provider
  # instance field not declared here) stays the app's. T3 Code leaves its
  # built-in Antigravity and OpenCode instances off until they are enabled,
  # so neither shows up on its own.
  settings = {
    addProjectBaseDirectory = "~/src";
    autoResumeLimitedThreads = true;
    branchNamingMode = "semantic";
    defaultAutoPull = true;
    enableAgentDeviceAccess = true;
    enableDeviceSupport = true;
    providerInstances = {
      antigravity = {
        driver = "antigravity";
        enabled = true;
      };
      # --add-dir also makes the directory a working directory of every T3
      # Code Claude session; it holds only the T3 Code part, so that is
      # harmless.
      claudeAgent = {
        driver = "claudeAgent";
        config.launchArgs = "--add-dir ${config.home.homeDirectory}/${claudeInstructionsDir}";
      };
      codex.driver = "codex";
      # Off in T3 Code until enabled. The opencode on PATH is the wrapper
      # that carries the API key, so no binaryPath is needed and the key never
      # reaches this file.
      opencode = {
        driver = "opencode";
        enabled = true;
      };
    };
    snoozeLimitedThreads = true;
    sourceControlWritingStyle.mode = "conventional_commits";
    storageCleanup = {
      browserArtifactsAfterDays = 8;
      logsAfterDays = 8;
      worktreeAfterDays = 8;
      worktreeOnDelete = true;
      worktreeOnMerge = true;
      worktreeUnchanged = true;
    };
  };

  # Keys that used to be declared. agent-settings removes these: the merge only
  # assigns, so dropping a key from settings alone would leave its last
  # written value on every machine forever. Move it here instead, and delete
  # the entry once every host has rebuilt past it. defaultThreadEnvMode is left
  # to each repository's t3.json, which a value in settings.json outranks.
  retiredKeys = [ "defaultThreadEnvMode" ];

  # providers is the retired per-kind block T3 Code moves into
  # providerInstances on load, but only into an instance that does not exist
  # yet. The instances declared above would make it skip theirs and drop the
  # user's fields, so the merge moves those kinds first, the same way, and
  # leaves the others for T3 Code.
  instanceMigration = {
    from = "providers";
    to = "providerInstances";
    kinds = lib.attrNames settings.providerInstances;
  };

  # The instance environment is a list the app also edits, so the one entry
  # is upserted by name and the user's other entries stay. `sensitive` is the
  # value the app writes back, so a later activation finds nothing to change.
  upserts = [
    {
      path = [
        "providerInstances"
        "claudeAgent"
        "environment"
      ];
      key = "name";
      value = {
        name = "CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD";
        value = "1";
        sensitive = false;
      };
    }
  ];

  # T3 Code writes a model selection whole, with options that belong to the
  # chosen model, so a selection is owned rather than merged leaf by leaf:
  # a leaf merge would keep a previous model's options.
  modelSelections = {
    defaultModelSelection = {
      instanceId = "claudeAgent";
      model = "claude-opus-5-5";
    };
    textGenerationModelSelection = {
      instanceId = textGenerationInstance;
      model = "gemini-3.8-flash-low";
    };
  };

  clientSettings.fontFamilyCode = "JetBrains Mono";

  # The app and the CLI rewrite both files at runtime, so the keys are merged
  # in rather than owned by a store symlink. An object T3 Code may extend is
  # declared leaf by leaf, as home/h82/dev/vscodium.nix does.
  leaves =
    path: value:
    if lib.isAttrs value then
      lib.concatLists (lib.mapAttrsToList (key: leaves (path ++ [ key ])) value)
    else
      [ { inherit path value; } ];

  declaration =
    {
      values,
      owned ? { },
      remove ? [ ],
      upsertPaths ? [ ],
      migrateInstances ? null,
    }:
    {
      inherit remove upsertPaths;
      set = lib.filterAttrs (_: value: !lib.isAttrs value) values;
      setPaths = leaves [ ] (lib.filterAttrs (_: lib.isAttrs) values);
      own = owned;
    }
    // lib.optionalAttrs (migrateInstances != null) { inherit migrateInstances; };

  merges = {
    t3codeSettings = {
      file = "settings.json";
      declared = instructions.declare {
        name = "t3code-declared-settings.json";
        base = declaration {
          values = settings;
          owned = modelSelections;
          remove = retiredKeys;
          upsertPaths = upserts;
          migrateInstances = instanceMigration;
        };
        leaves = [
          {
            path = [
              "providerInstances"
              "codex"
              "config"
              "launchArgs"
            ];
            encoding = "codex-launch";
            source = instructions.render {
              harness = "codex";
              parts = [
                "system"
                "t3code"
              ];
            };
          }
        ];
      };
    };
    t3codeClientSettings = {
      file = "client-settings.json";
      declared = pkgs.writeText "t3code-declared-client-settings.json" (
        builtins.toJSON (declaration {
          values = clientSettings;
        })
      );
    };
  };
in
{
  assertions = [
    {
      assertion = cfg.desktop.enable -> desktopSupported;
      message = "${config.my.hostName}: my.t3.desktop.enable: the T3 Code desktop app runs on NixOS and macOS only; enable my.t3.cli.enable on a non-NixOS Linux host.";
    }
  ];

  home.packages =
    lib.optionals cfg.cli.enable [ (import ../../packages/t3code-cli.nix { inherit pkgs; }) ]
    ++ lib.optionals (cfg.desktop.enable && desktopSupported) [
      (import ../../packages/t3code.nix { inherit pkgs; })
    ];

  # Home Manager copies the macOS app bundle into ~/Applications writable, so
  # the app's own updater could move it off the nightly pin. The Linux wrapper
  # turns the updater off with this variable; on macOS a login agent sets it
  # for every app launched from Finder or the Dock.
  launchd.agents.t3code-disable-auto-update = lib.mkIf (cfg.desktop.enable && darwin) {
    enable = true;
    config = {
      ProgramArguments = [
        "/bin/launchctl"
        "setenv"
        "T3CODE_DISABLE_AUTO_UPDATE"
        "1"
      ];
      RunAtLoad = true;
    };
  };

  home.file.t3code-claude-instructions = lib.mkIf t3 {
    target = "${claudeInstructionsDir}/CLAUDE.md";
    source = instructions.render {
      harness = "claude-code";
      parts = [ "t3code" ];
    };
  };

  # The desktop app and the CLI share ~/.t3. One settings entry per file, so a
  # refusal on one does not hide the other. Ordered after installPackages, as
  # the Claude Code merge in agents/claude.nix is, so a refusal cannot strand
  # linkGeneration. `run` leaves the files alone on a dry run.

  home.activation = lib.mkIf t3 (
    lib.mapAttrs (
      _: merge:
      lib.hm.dag.entryAfter [ "installPackages" ] ''
        run ${merger} \
          --label 'T3 Code' \
          --settings ${config.home.homeDirectory}/.t3/userdata/${merge.file} \
          --declared ${merge.declared}
      ''
    ) merges
    // {
      # The script references the package, so this generation keeps the
      # linked runtime from garbage collection; a later generation relinks.
      t3codeAntigravity = lib.hm.dag.entryAfter [ "installPackages" ] ''
        run ${installer} \
          --base-dir ${config.home.homeDirectory}/.t3 \
          --runtime ${antigravity}/libexec/antigravity-acp \
          --pin ${antigravityPin}
      '';
      # T3 Code runs each Antigravity instance under its own GEMINI_HOME,
      # whose ACP runtime loads skills but no plugins, so each plugin skill is
      # linked into ~/.gemini/antigravity-cli/skills, which T3 Code links into
      # every instance home, and the CLI's global instructions into each home.
      # It runs after agentPlugins so a sync's new or retired skills are seen.
      # An instance added in the app gets its links on the next activation,
      # which on NixOS runs only when a rebuild produces a new Home Manager
      # generation.
      t3codeAntigravityLinks = lib.hm.dag.entryAfter [ "installPackages" "agentPlugins" ] ''
        run ${linker} \
          --base-dir ${config.home.homeDirectory}/.t3 \
          --gemini-config ${config.home.homeDirectory}/.gemini/config \
          ${lib.concatMapStringsSep " " (id: "--instance ${lib.escapeShellArg id}") antigravityInstances}
      '';
    }
  );
}
