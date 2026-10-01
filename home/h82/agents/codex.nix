{
  config,
  pkgs,
  lib,
  ...
}:
let
  merger = "${
    (import ../../../packages/agent-tools.nix { inherit pkgs; }).agentSettings
  }/bin/agent-settings";

  # Codex owns ~/.codex/config.toml and rewrites it at runtime -- trusting a
  # project, `codex plugin add`, and its own settings all write there -- so a
  # read-only store symlink cannot live there. Activation assigns these keys
  # and leaves everything else as Codex wrote it.
  #
  # Every update key, not only the startup check: `daemon_auto_start`
  # installs and updates a background daemon copy of Codex, which nixpkgs
  # disables with a source patch that this prebuilt pin cannot carry. The
  # wrapper in packages/codex.nix passes the same update overrides as flags,
  # so they also hold under Orca's CODEX_HOME, which never sees this file.
  declaredPaths = [
    {
      path = [ "check_for_update_on_startup" ];
      value = false;
    }
    {
      path = [
        "features"
        "in_app_updates"
      ];
      value = false;
    }
    {
      path = [
        "features"
        "daemon_auto_start"
      ];
      value = false;
    }
    {
      path = [
        "features"
        "memories"
      ];
      value = false;
    }
  ];

  # Keys this repository used to declare and has since retired. The merge only
  # assigns, so dropping a key from declaredPaths alone would leave its last
  # written value on every machine forever. Move it here instead, and delete
  # the entry once every host has rebuilt past it.
  retiredKeys = [ ];

  declared = pkgs.writeText "codex-declared-settings.json" (
    builtins.toJSON {
      setPaths = declaredPaths;
      remove = retiredKeys;
    }
  );
in
{
  # Unguarded and after installPackages for the reasons given on
  # claudeSettings in claude.nix: a refusal must fail the rebuild loudly
  # without stranding linkGeneration or installPackages behind it.
  home.activation.codexSettings = lib.hm.dag.entryAfter [ "installPackages" ] ''
    ${merger} \
      --format toml \
      --label Codex \
      --settings ${config.home.homeDirectory}/.codex/config.toml \
      --declared ${declared}
  '';
}
