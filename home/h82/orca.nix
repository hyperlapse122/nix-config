{
  config,
  pkgs,
  lib,
  ...
}:
let
  orcaPkg = import ../../packages/orca.nix { inherit pkgs; };
  reconciler = "${
    (import ../../packages/orca-tools.nix { inherit pkgs; }).orcaSettingsReconcile
  }/bin/orca-settings-reconcile";

  # Orca ADE application settings this repository declares.
  #
  # The live file is ~/.config/orca/profiles/<activeProfileId>/orca-data.json,
  # which mingles declared settings with worktree metadata, workspace session state,
  # and telemetry that only the application may write.
  #
  # Orca rewrites orca-data.json from memory roughly every 9 seconds while running,
  # ignoring disk modifications. The reconciler asserts declared leaves before the
  # graphical session starts and during rebuilds when Orca is not running.
  orcaSettingsTier = {
    "settings.workspaceDir" = "${config.home.homeDirectory}/.local/share/worktrees";
    "settings.appFontFamily" = "Pretendard";
    "settings.editorFontFamily" = "JetBrainsMono NF";
    "settings.terminalFontFamily" = "JetBrainsMono NF";
    "settings.defaultTuiAgent" = "claude";
    "settings.agentDefaultArgs.codex" =
      "--dangerously-bypass-approvals-and-sandbox --dangerously-bypass-hook-trust";
    "settings.voice.enabled" = true;
    "settings.voice.sttModel" = "zipformer-streaming-korean";
    "settings.refreshLocalBaseRefOnWorktreeCreate" = true;
    "settings.keepComputerAwakeWhileAgentsRun" = true;
    "settings.notifications.enabled" = false;
  };

  declared = pkgs.writeText "orca-declared-settings.json" (builtins.toJSON orcaSettingsTier);
in
{
  home.packages = [ orcaPkg ];

  # Systemd user service to assert declared settings before graphical session
  systemd.user.services.orca-settings-reconcile = {
    Unit = {
      Description = "Reconcile declared Orca IDE settings";
      PartOf = [ "graphical-session.target" ];
      Before = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${reconciler} --mode assert --declared ${declared}";
      RemainAfterExit = true;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Activation merge runs during rebuilds. If Orca is running, it logs drift and skips writing.
  home.activation.orcaSettings = lib.hm.dag.entryAfter [ "installPackages" ] ''
    ${reconciler} --mode assert --declared ${declared}
  '';
}
