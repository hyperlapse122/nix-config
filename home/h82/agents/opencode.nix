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

  # The wrapper reads /run/secrets/cli-auth/synthetic_api_key at run time.
  # Bootstrap generations have no such file, and Synthetic then serves
  # nothing.
  wrapper = import ../../../packages/opencode.nix (
    {
      inherit pkgs;
    }
    # A non-NixOS host, Linux or macOS, keeps its decrypted tokens in the
    # user's state directory instead (home/h82/security/non-nixos-secrets.nix).
    // lib.optionalAttrs (config.my.kind != "nixos") {
      tokenFile = "${config.my.secrets.stateDir}/synthetic_api_key";
    }
  );

  models = import ./synthetic-models.nix;
  small = models.${models.small};
  # A second entry for the same upstream model, so small_model, which
  # OpenCode 2.x uses only for title generation, runs at effort low while
  # the main entry keeps its own. The suffix keeps the key under the
  # model's org, which the shared instructions map to its family.
  smallKey = "${small.id}@low";
  syntheticModels =
    lib.mapAttrs' (
      _: entry: lib.nameValuePair entry.id { options.reasoningEffort = entry.opencodeEffort; }
    ) (lib.filterAttrs (_: builtins.isAttrs) models)
    // {
      ${smallKey} = {
        inherit (small) id;
        options.reasoningEffort = "low";
      };
    };

  # `opencode mcp add` and `opencode plugin add` rewrite this file, so
  # activation assigns these keys and leaves everything else as OpenCode wrote
  # it. update replaces autoupdate in OpenCode v2, so the merge deletes the
  # legacy key; the wrapper's OPENCODE_DISABLE_AUTOUPDATE stays as the
  # backstop under every config T3 Code supplies. share = "disabled" keeps a
  # session from being published by link. enabled_providers allowlists the
  # synthetic provider, so no other provider loads even when its credentials
  # are present.
  #
  # OpenCode 2.0.32 drops a variant given in the config file (`model#max`, a
  # model object, or agent.build.variant) and honours one only from
  # `--model`, which the wrapper cannot add without overriding a caller's own
  # choice. A model's options reach the provider request, so each model's
  # effort is pinned there: every session on it, through `opencode run`,
  # `opencode acp`, or `opencode serve`, sends that reasoning_effort unless
  # the caller selects another variant. OpenCode passes the value through
  # unchecked.
  declared = pkgs.writeText "opencode-declared-settings.json" (
    builtins.toJSON {
      set = {
        "$schema" = "https://opencode.ai/config.json";
        model = "synthetic/" + models.${models.opencodeDefault}.id;
        small_model = "synthetic/" + smallKey;
        update = "disable";
        share = "disabled";
      };
      remove = [ "autoupdate" ];
      # enabled_providers is an array, which set refuses; nothing else writes
      # the key, so owning it whole is the right tier.
      own.enabled_providers = [ "synthetic" ];
      # The model map holds exactly the source's entries, so one an earlier
      # source declared, such as the retired syn:large:text alias, leaves on
      # the next apply. The provider's options and other providers stay.
      ownPaths = [
        {
          path = [
            "provider"
            "synthetic"
            "models"
          ];
          value = syntheticModels;
        }
      ];
    }
  );

  # OpenCode v2 clients share one detached background server, spawned with the
  # first client's environment, so it would keep that run's API key, switches
  # and version. Disabled, every run owns its server and the wrapper's
  # exported key and switches apply. The password, port and env OpenCode
  # writes beside this key stay as they are. A caller that sets
  # OPENCODE_CONFIG_DIR reads service.json from there instead; T3 Code sets
  # none and runs `opencode serve`, which never uses the shared server.
  declaredService = pkgs.writeText "opencode-declared-service.json" (
    builtins.toJSON {
      set = {
        disabled = true;
      };
    }
  );

  mergeInto =
    label: file: document:
    lib.hm.dag.entryAfter [ "installPackages" ] ''
      ${merger} \
        --label ${lib.escapeShellArg label} \
        --settings ${config.home.homeDirectory}/.config/opencode/${file} \
        --declared ${document}
    '';
in
{
  my.agents.crossModelPeers = [ "opencode" ];

  home.packages = [ wrapper ];

  # OpenCode autoloads every directory under ~/.config/opencode/plugins, so
  # the plugin needs no plugins entry in opencode.json.
  home.file.".config/opencode/plugins/session-info".source =
    import ../../../packages/opencode-session-info.nix
      { inherit pkgs; };

  # Unguarded and after installPackages for the reasons given on
  # claudeSettings in claude.nix: a refusal must fail the rebuild loudly
  # without stranding linkGeneration or installPackages behind it.
  home.activation.opencodeSettings = mergeInto "OpenCode" "opencode.json" declared;
  home.activation.opencodeService = mergeInto "OpenCode service" "service.json" declaredService;

  # Writing disabled = true leaves a server already running, with its old key
  # and binary, until it is stopped; `opencode service set disabled true`
  # stops it too, so activation does the same. A server that will not stop
  # does not undo the declared settings, so it warns instead of failing.
  home.activation.opencodeServiceStop = lib.hm.dag.entryAfter [ "opencodeService" ] ''
    ${wrapper}/bin/opencode service stop \
      || echo "OpenCode: could not stop the background server; run 'opencode service stop'" >&2
  '';
}
