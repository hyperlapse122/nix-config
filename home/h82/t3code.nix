/*
  T3 Code nightly, one artifact per trait: my.t3.cli.enable installs the
  headless `t3` CLI and my.t3.desktop.enable the desktop app. Its Claude
  sessions run the flake's own claude with its user-level settings, so nothing
  here adds a copy of it. The T3 Code settings that
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

  syntheticModels = import ./agents/synthetic-models.nix;

  antigravityInstances = [ "antigravity" ];

  # The Antigravity runtime the pinned T3 Code requires, preinstalled so the
  # provider needs only a sign-in.
  antigravity = import ../../packages/antigravity-acp.nix {
    inherit pkgs;
    pins = (builtins.fromJSON (builtins.readFile ../../packages/t3code-release.json)).antigravity;
  };
  antigravityPin = pkgs.writeText "antigravity-acp-pin.json" (builtins.toJSON antigravity.pin);
  antigravityPath = import ../../packages/antigravity-acp-path.nix { inherit pkgs; };

  # The settings that differ from the pinned T3 Code's schema defaults; a
  # value left at its default follows T3 Code when that default changes. Each
  # declared provider instance states `enabled`, even where it equals the
  # default: claudeAgent's does, since T3 Code turns that instance on. A
  # cleanup that drops default-valued settings must keep it, or the instance
  # would go back to following T3 Code's default. App state (onboarding marks,
  # folded panels, favorites, and every provider instance field not declared
  # here) stays the app's. T3 Code leaves its built-in Antigravity and OpenCode
  # instances off until they are enabled, so neither shows up on its own.
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
      # T3 Code enables its built-in Codex instance unless one is declared.
      # The merge can retire only top-level keys, so the launch arguments an
      # earlier generation wrote, which carried the old instructions, are
      # overwritten with nothing.
      codex = {
        driver = "codex";
        enabled = false;
        config.launchArgs = "";
      };
      # T3 Code enables its built-in Grok instance unless one is declared.
      grok = {
        driver = "grok";
        enabled = false;
      };
      # The opencode on PATH is the wrapper that carries the API key, so no
      # binaryPath is needed and the key never reaches this file.
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
  # the entry once every host has rebuilt past it.
  retiredKeys = [ ];

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
  #
  # Text generation selects the second entry home/h82/agents/opencode.nix
  # declares for the text-generation model, keyed by the role's effort and
  # pinned to it in OpenCode's settings, with no variant: T3 Code sends none
  # then, so the effort does not depend on a variant reaching the request.
  textGeneration = syntheticModels.${syntheticModels.textGeneration};
  modelSelections = {
    defaultModelSelection = {
      instanceId = "claudeAgent";
      model = "claude-opus-5-5";
      options = [
        {
          id = "effort";
          value = "medium";
        }
      ];
    };
    textGenerationModelSelection = {
      instanceId = "opencode";
      model = "synthetic/${textGeneration.id}@${textGeneration.roles.text-generation}";
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
      migrateInstances ? null,
    }:
    {
      inherit remove;
      set = lib.filterAttrs (_: value: !lib.isAttrs value) values;
      setPaths = leaves [ ] (lib.filterAttrs (_: lib.isAttrs) values);
      own = owned;
    }
    // lib.optionalAttrs (migrateInstances != null) { inherit migrateInstances; };

  merges = {
    t3codeSettings = {
      file = "settings.json";
      declared = pkgs.writeText "t3code-declared-settings.json" (
        builtins.toJSON (declaration {
          values = settings;
          owned = modelSelections;
          remove = retiredKeys;
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
