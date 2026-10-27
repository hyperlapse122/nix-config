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
  # so they also hold under any other CODEX_HOME, which never sees this file,
  # such as a home a T3 Code instance gets when it declares one.
  declaredPaths = [
    {
      path = [ "model" ];
      value = "gpt-6-astra";
    }
    {
      path = [ "model_reasoning_effort" ];
      value = "medium";
    }
    {
      path = [ "service_tier" ];
      value = "default";
    }
    {
      path = [
        "agents"
        "default_subagent_model"
      ];
      value = "gpt-6.1-sol";
    }
    {
      path = [
        "agents"
        "default_subagent_reasoning_effort"
      ];
      value = "low";
    }
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
  #
  # developer_instructions carried the system part of the agent instructions
  # before Codex was removed. ~/.codex/AGENTS.md carries the whole text now,
  # so a stale copy would hand Codex the old rules beside the current ones.
  retiredKeys = [ "developer_instructions" ];

  declared = pkgs.writeText "codex-declared-settings.json" (
    builtins.toJSON {
      setPaths = declaredPaths;
      remove = retiredKeys;
    }
  );
in
{
  # Codex is a Compound Engineering review route, so its token joins
  # CROSS_MODEL_PEERS on every host that installs it.
  my.agents.crossModelPeers = [ "codex" ];

  # No executable-existence guard; ordered after installPackages as on
  # claudeSettings in claude.nix: a refusal must fail the rebuild loudly
  # without stranding linkGeneration or installPackages behind it.
  home.activation.codexSettings = lib.hm.dag.entryAfter [ "installPackages" ] ''
    if [[ ! -v DRY_RUN ]]; then
      ${merger} \
        --format toml \
        --label Codex \
        --settings ${config.home.homeDirectory}/.codex/config.toml \
        --declared ${declared}
    fi
  '';
}
