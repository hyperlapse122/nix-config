{ pkgs }:

let
  inherit (pkgs) lib;

  agentTools = import ./agent-tools.nix { inherit pkgs; };
  contextPackage = agentTools.orcaOrchestrationContext;
  context = lib.getExe contextPackage;
  guard = lib.getExe agentTools.orcaSubagentGuard;

  name = "orca-orchestration";

  # Claude Code caps each hook's output, so the guide arrives as parts and
  # each handler prints one, as many as the script was built for. `startup`
  # alone: resume, clear, compact, and fork keep the context they already
  # have. The hook names the script by store path because
  # ${CLAUDE_PLUGIN_ROOT} points at Claude Code's cache copy, not this tree.
  parts = contextPackage.claudeParts;
  hooks = {
    description = "Inject Orca's orchestration guide and refuse harness subagents in sessions inside Orca";
    hooks.SessionStart = [
      {
        matcher = "startup";
        hooks = map (part: {
          type = "command";
          command = "${context} --harness claude --part ${toString part}";
          timeout = 10;
        }) (lib.range 1 parts);
      }
    ];
    # Refuses the harness's own subagents inside Orca. The matcher is anchored
    # so Workflow and every other tool never reach the guard, and the guard
    # checks the tool name again itself.
    hooks.PreToolUse = [
      {
        matcher = "^(Agent|Task)$";
        hooks = [
          {
            type = "command";
            command = "${guard} --harness claude";
            timeout = 10;
          }
        ];
      }
    ];
  };
  hooksJson = builtins.toJSON hooks;

  # Claude Code keys its plugin cache on plugin.json's version, and
  # agent-plugin-sync keys its link on the same value, so both follow the hook
  # file: a new script store path is a new version and a fresh install. The
  # hash leaves the manifests out, since they carry the version themselves.
  version = "0.0.0-${builtins.substring 0 12 (builtins.hashString "sha256" hooksJson)}";

  plugin = {
    inherit name version;
    description = "Injects Orca's version-matched orchestration guide at session start and refuses harness subagents inside Orca";
  };

  # No command, commands, or headersHelper: agent-plugin-sync refuses a
  # marketplace that would need --accept-command.
  marketplace = {
    inherit name;
    owner.name = "h82";
    plugins = [
      {
        inherit name;
        inherit (plugin) description;
        source = "./";
      }
    ];
  };
in
pkgs.runCommand "${name}-plugin-${version}"
  {
    passthru = { inherit name version; };
  }
  ''
    mkdir -p $out/.claude-plugin $out/hooks
    cp ${pkgs.writeText "plugin.json" (builtins.toJSON plugin)} $out/.claude-plugin/plugin.json
    cp ${pkgs.writeText "marketplace.json" (builtins.toJSON marketplace)} $out/.claude-plugin/marketplace.json
    cp ${pkgs.writeText "hooks.json" hooksJson} $out/hooks/hooks.json
  ''
