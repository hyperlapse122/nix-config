{
  config,
  pkgs,
  lib,
  ...
}:
let
  mergeInto = import ./merge-into.nix { inherit config pkgs lib; } ".config/opencode";

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
  # A second entry for the same upstream model, so small_model, which
  # OpenCode 2.x uses only for title generation, runs at the text-generation
  # role's effort while the main entry keeps its own. The suffix keeps the key
  # under the model's org, which the shared instructions map to its family.
  textKey = entry: "${entry.id}@${entry.roles.text-generation}";
  textModels = lib.unique (
    map (name: models.${name}) [
      models.smallModel
      models.textGeneration
    ]
  );
  smallKey = textKey models.${models.smallModel};

  modelsPath = [
    "provider"
    "synthetic"
    "models"
  ];
  # Only the leaves the repository manages are assigned, so a model entry the
  # user adds under provider.synthetic.models, or a key they add inside one of
  # these entries, survives every rebuild.
  modelLeaves =
    lib.mapAttrsToList (_: entry: {
      path = modelsPath ++ [
        entry.id
        "options"
        "reasoningEffort"
      ];
      value = entry.defaultEffort;
    }) (lib.filterAttrs (_: builtins.isAttrs) models)
    ++ lib.concatMap (entry: [
      {
        path = modelsPath ++ [
          (textKey entry)
          "id"
        ];
        value = entry.id;
      }
      {
        path = modelsPath ++ [
          (textKey entry)
          "options"
          "reasoningEffort"
        ];
        value = entry.roles.text-generation;
      }
    ]) textModels;
  # Model keys an earlier generation of this file wrote and the source no
  # longer names. When a source `id` moves, or the text-generation role's
  # effort renames a textKey entry, add the previous key here, or its entry stays
  # behind with the effort last written. syn:large:text is the retired
  # cross-reviewer alias, declared through its `name`.
  retiredModels = [ "syn:large:text" ];

  # `opencode mcp add` and `opencode plugin add` rewrite this file, so
  # activation assigns these keys and leaves everything else as OpenCode wrote
  # it. update replaces autoupdate in OpenCode v2, so the merge deletes the
  # legacy key; the wrapper's OPENCODE_DISABLE_AUTOUPDATE stays as the
  # backstop under every config T3 Code supplies.
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
        model = "synthetic/" + models.${models.defaultModel}.id;
        small_model = "synthetic/" + smallKey;
        update = "disable";
        share = "disabled";
      };
      remove = [ "autoupdate" ];
      # enabled_providers is an array, which set refuses; nothing else writes
      # the key, so owning it whole is the right tier.
      own.enabled_providers = [ "synthetic" ];
      setPaths = modelLeaves;
      removePaths = map (key: {
        path = modelsPath;
        inherit key;
      }) retiredModels;
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
in
{
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
