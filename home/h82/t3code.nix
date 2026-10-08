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

  # The Antigravity runtime the pinned T3 Code requires, preinstalled so the
  # provider needs only a sign-in.
  antigravity = import ../../packages/antigravity-acp.nix { inherit pkgs; };
  antigravityPin = pkgs.writeText "antigravity-acp-pin.json" (builtins.toJSON antigravity.pin);

  # The settings that differ from the pinned T3 Code's schema defaults; a
  # value left at its default follows T3 Code when that default changes. App
  # state (onboarding marks, folded panels, favorites, the provider instances
  # the app writes during setup) stays the app's. T3 Code leaves its built-in
  # Antigravity provider off until providers.antigravity.enabled is set, so it
  # never shows up on its own.
  settings = {
    addProjectBaseDirectory = "~/src";
    autoResumeLimitedThreads = true;
    branchNamingMode = "semantic";
    defaultAutoPull = true;
    defaultThreadEnvMode = "worktree";
    enableAgentDeviceAccess = true;
    enableDeviceSupport = true;
    providers.antigravity.enabled = true;
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

  # T3 Code writes a model selection whole, with options that belong to the
  # chosen model, so a selection is owned rather than merged leaf by leaf:
  # a leaf merge would keep a previous model's options.
  modelSelections = {
    defaultModelSelection = {
      instanceId = "claudeAgent";
      model = "claude-opus-5-5";
    };
    textGenerationModelSelection = {
      instanceId = "antigravity";
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

  render =
    name: values: owned:
    pkgs.writeText name (
      builtins.toJSON {
        set = lib.filterAttrs (_: value: !lib.isAttrs value) values;
        setPaths = leaves [ ] (lib.filterAttrs (_: lib.isAttrs) values);
        own = owned;
      }
    );

  merges = {
    t3codeSettings = {
      file = "settings.json";
      declared = render "t3code-declared-settings.json" settings modelSelections;
    };
    t3codeClientSettings = {
      file = "client-settings.json";
      declared = render "t3code-declared-client-settings.json" clientSettings { };
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
  home.activation = lib.mkIf (cfg.cli.enable || cfg.desktop.enable) (
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
    }
  );
}
