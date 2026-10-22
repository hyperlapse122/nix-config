{
  config,
  pkgs,
  lib,
  ...
}:
let
  mergeInto = import ./merge-into.nix { inherit config pkgs lib; } ".pi/agent";

  keyDirectory =
    if config.my.kind != "nixos" then config.my.secrets.stateDir else "/run/secrets/cli-auth";
  syntheticKeyFile = "${keyDirectory}/synthetic_api_key";
  exaKeyFile = "${keyDirectory}/exa_api_key";

  pi = import ../../../packages/pi.nix { inherit pkgs syntheticKeyFile exaKeyFile; };

  piAcp = import ../../../packages/pi-acp.nix { inherit pkgs pi; };
  acpx = import ../../../packages/acpx.nix { inherit pkgs piAcp; };

  sourceModels = import ./synthetic-models.nix;
  entries = lib.filterAttrs (_: builtins.isAttrs) sourceModels;
  catalog = (builtins.fromJSON (builtins.readFile ./synthetic-catalog.json)).data;
  catalogEntry =
    entry:
    lib.findFirst (
      candidate: candidate.id == entry.id
    ) (throw "synthetic-catalog.json has no entry for ${entry.id}") catalog;

  # The catalog prices a token as "$0.0000014" and "0"; Pi takes USD per
  # million tokens.
  perMillion = price: (builtins.fromJSON (lib.removePrefix "$" price)) * 1000000;

  # Pi's levels, in order. Each one sends the same-named Synthetic effort when
  # the catalog lists it and is unsupported (null) otherwise; `off` sends
  # `none`, `minimal` has no Synthetic effort, and `xhigh` and `max` are left
  # out when unlisted because Pi treats an unmapped one as unsupported anyway.
  thinkingLevelMap =
    efforts:
    let
      listed = effort: lib.elem effort efforts;
      same = effort: if listed effort then effort else null;
    in
    {
      off = if listed "none" then "none" else null;
      minimal = null;
      low = same "low";
      medium = same "medium";
      high = same "high";
    }
    // lib.optionalAttrs (listed "xhigh") { xhigh = "xhigh"; }
    // lib.optionalAttrs (listed "max") { max = "max"; };

  modelEntry =
    entry:
    let
      remote = catalogEntry entry;
      efforts = remote.reasoning_parameters.efforts or [ ];
    in
    {
      inherit (entry) id;
      name = remote.display_name;
      reasoning = efforts != [ ];
      thinkingLevelMap = thinkingLevelMap efforts;
      input = lib.filter (
        modality:
        lib.elem modality [
          "text"
          "image"
        ]
      ) remote.input_modalities;
      cost = {
        input = perMillion remote.pricing.prompt;
        output = perMillion remote.pricing.completion;
        cacheRead = perMillion remote.pricing.input_cache_reads;
        cacheWrite = perMillion remote.pricing.input_cache_writes;
      };
      contextWindow = remote.context_length;
      maxTokens = remote.max_output_length;
    };

  providerPath = [
    "providers"
    "synthetic"
  ];

  # Model IDs an earlier generation of this file declared and the source no
  # longer names. When a source `id` moves to a newer build, add the previous
  # one here, or its models.json entry and its modelThinkingLevels key stay
  # behind with the values last written.
  retiredModels = [ "hf:moonshotai/Kimi-K3" ];

  # The apiKey is a `!` command: Pi runs the packaged helper for every
  # request, so no key reaches this file.
  declaredModels = pkgs.writeText "pi-declared-models.json" (
    builtins.toJSON {
      setPaths =
        lib.mapAttrsToList
          (leaf: value: {
            path = providerPath ++ [ leaf ];
            inherit value;
          })
          {
            name = "Synthetic";
            baseUrl = "https://api.synthetic.new/openai/v1";
            api = "openai-completions";
            apiKey = "!${pi}/bin/pi-synthetic-key";
          };
      upsertPaths = lib.mapAttrsToList (_: entry: {
        path = providerPath ++ [ "models" ];
        key = "id";
        value = modelEntry entry;
      }) entries;
      removeEntries = [
        {
          path = providerPath ++ [ "models" ];
          key = "id";
          values = retiredModels;
        }
      ];
    }
  );

  # Pi starts each model at its source effort. The text-generation model starts
  # at its text-generation role's effort instead, because a client that
  # switches to it with set_model sets no thinking level of its own.
  startupEffort =
    name: entry:
    if name == sourceModels.textGeneration then entry.roles.text-generation else entry.defaultEffort;

  # defaultProjectTrust never: a checkout Pi works in must not be able to supply
  # extensions or packages that run code.
  declaredSettings = pkgs.writeText "pi-declared-settings.json" (
    builtins.toJSON {
      set = {
        defaultProvider = "synthetic";
        defaultModel = sourceModels.${sourceModels.defaultModel}.id;
        defaultProjectTrust = "never";
      };
      setPaths = lib.mapAttrsToList (name: entry: {
        path = [
          "modelThinkingLevels"
          "synthetic/${entry.id}"
        ];
        value = startupEffort name entry;
      }) entries;
      removePaths = map (id: {
        path = [ "modelThinkingLevels" ];
        key = "synthetic/${id}";
      }) retiredModels;
    }
  );
in
{
  home.packages = [
    pi
    piAcp
    acpx
  ];

  # Pi loads every directory under ~/.pi/agent/extensions that holds an
  # index.js.
  home.file.".pi/agent/extensions/nix-config".source = import ../../../packages/pi-extension.nix {
    inherit pkgs syntheticKeyFile exaKeyFile;
  };

  # Unguarded and after installPackages for the reasons given on
  # claudeSettings in claude.nix: a refusal must fail the rebuild loudly
  # without stranding linkGeneration or installPackages behind it. Pi rewrites
  # both files itself, so Home Manager never owns them.
  home.activation.piModels = mergeInto "Pi models" "models.json" declaredModels;
  home.activation.piSettings = mergeInto "Pi settings" "settings.json" declaredSettings;
}
