/*
  T3 Code nightly, one artifact per trait: my.t3.cli.enable installs the
  headless `t3` CLI and my.t3.desktop.enable the desktop app. Its Claude
  and Codex sessions run the flake's own claude and codex with their
  user-level settings, so nothing here adds a copy of either. The T3 Code
  settings that differ from the pinned nightly's defaults are merged into its
  own settings files on activation, and the Antigravity runtime it requires is
  installed where T3 Code looks for it.

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

  antigravityInstances = [ "antigravity" ];

  # The Antigravity runtime the pinned T3 Code requires, preinstalled so the
  # provider needs only a sign-in.
  antigravity = import ../../packages/antigravity-acp.nix {
    inherit pkgs;
    pins = (builtins.fromJSON (builtins.readFile ../../packages/t3code-release.json)).antigravity;
  };
  antigravityPin = pkgs.writeText "antigravity-acp-pin.json" (builtins.toJSON antigravity.pin);
  # A check evaluates this module without home/h82/agents/skills.nix; the
  # wrapper's default skill list applies there.
  antigravityPath = import ../../packages/antigravity-acp-path.nix (
    {
      inherit pkgs;
    }
    // lib.optionalAttrs (config.my ? agentSkills) {
      skills = lib.attrNames config.my.agentSkills;
    }
  );

  # The settings that differ from the pinned T3 Code's schema defaults; a
  # value left at its default follows T3 Code when that default changes. Each
  # declared provider instance states `enabled`, even where it equals the
  # default: claudeAgent's and codex's do, since T3 Code turns those instances
  # on. A cleanup that drops default-valued settings must keep it, or the instance
  # would go back to following T3 Code's default. App state (onboarding marks,
  # folded panels, favorites, and every provider instance field not declared
  # here) stays the app's. T3 Code leaves its built-in Antigravity and Pi
  # instances off until they are enabled, so none shows up on its own.
  settings = {
    addProjectBaseDirectory = "~/src";
    autoResumeLimitedThreads = true;
    branchNamingMode = "semantic";
    defaultAutoPull = true;
    # New threads start in a new worktree. A value here outranks every
    # repository's t3.json; only a per-project override in the app wins.
    defaultThreadEnvMode = "worktree";
    enableAgentDeviceAccess = true;
    enableDeviceSupport = true;
    providerInstances = {
      antigravity = {
        config.binaryPath = "${antigravityPath}/bin/agy_acp_server.par";
        driver = "antigravity";
        enabled = true;
      };
      claudeAgent = {
        driver = "claudeAgent";
        enabled = true;
        config.launchArgs = "";
      };
      # The codex on PATH is the packaged wrapper, so no binaryPath is needed.
      # Codex reads the instructions from ~/.codex/AGENTS.md, so the launch
      # arguments an earlier generation wrote, which carried the old
      # instructions, are overwritten with nothing.
      #
      # T3 Code gives a Codex instance its own home only when its config names
      # one: a homePath, a shadowHomePath, or the "managed" setupMode. The
      # merge keeps every field not declared here, so one set in the app would
      # survive every apply. An empty homePath would still let a CODEX_HOME in
      # the instance's own environment, which the merge also keeps, choose the
      # home, because T3 Code sets CODEX_HOME only for a nonempty homePath.
      # Declaring homePath as ~/.codex, which T3 Code expands, and the
      # non-managed "existing" setupMode keeps the sessions on ~/.codex, where
      # the plugin sync and home/h82/agents/skills.nix install. shadowHomePath stays
      # undeclared: a shadow home shares skills and plugins with ~/.codex.
      codex = {
        driver = "codex";
        enabled = true;
        config = {
          homePath = "~/.codex";
          launchArgs = "";
          setupMode = "existing";
        };
      };
      # T3 Code enables its built-in Grok instance unless one is declared.
      grok = {
        driver = "grok";
        enabled = false;
      };
      # OpenCode is gone, but the merge keeps undeclared fields, so this stays
      # declared to turn off the instance an earlier generation enabled.
      opencode = {
        driver = "opencode";
        enabled = false;
      };
      # The pi on PATH is the packaged wrapper, whose Synthetic provider reads
      # the key file per request, so no binaryPath is needed and no key reaches
      # this file. No launch arguments.
      pi = {
        driver = "pi";
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
      worktreeSettledAfterDays = 1;
      worktreeUnchanged = true;
    };
  };

  # Keys that used to be declared. agent-settings removes these: the merge only
  # assigns, so dropping a key from settings alone would leave its last
  # written value on every machine forever. Move it here instead, and delete
  # the entry once every host has rebuilt past it.
  retiredKeys = [ ];

  # Nested entries that used to be declared, retired the same way. An earlier
  # generation hid OpenCode's text-generation alias here; prune drops the
  # object once that leaves it empty.
  retiredPaths = [
    {
      path = [ "providerModelPreferences" ];
      key = "opencode";
      prune = true;
    }
  ];

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

  # T3 Code writes a model selection whole, with options that belong to the
  # chosen model, so a selection is owned rather than merged leaf by leaf:
  # a leaf merge would keep a previous model's options.
  modelSelections = {
    defaultModelSelection = {
      instanceId = "codex";
      model = "gpt-6-astra";
      options = [
        {
          id = "reasoningEffort";
          value = "low";
        }
        {
          id = "serviceTier";
          value = "default";
        }
      ];
    };
    textGenerationModelSelection = {
      instanceId = "claudeAgent";
      model = "claude-haiku-5-5";
      options = [ ];
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
      removePaths ? [ ],
      migrateInstances ? null,
    }:
    {
      inherit remove;
      set = lib.filterAttrs (_: value: !lib.isAttrs value) values;
      setPaths = leaves [ ] (lib.filterAttrs (_: lib.isAttrs) values);
      own = owned;
    }
    // lib.optionalAttrs (removePaths != [ ]) { inherit removePaths; }
    // lib.optionalAttrs (migrateInstances != null) { inherit migrateInstances; };

  merges = {
    t3codeSettings = {
      file = "settings.json";
      declared = pkgs.writeText "t3code-declared-settings.json" (
        builtins.toJSON (declaration {
          values = settings;
          owned = modelSelections;
          remove = retiredKeys;
          removePaths = retiredPaths;
          migrateInstances = instanceMigration;
        })
      );
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
      # every instance home; the linker also removes the config links an earlier
      # version made in each home.
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
