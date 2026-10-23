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
  openrouterKeyFile = "${keyDirectory}/openrouter_api_key";

  pi = import ../../../packages/pi.nix {
    inherit
      pkgs
      syntheticKeyFile
      exaKeyFile
      openrouterKeyFile
      ;
  };

  piAcp = import ../../../packages/pi-acp.nix { inherit pkgs pi; };
  acpx = import ../../../packages/acpx.nix { inherit pkgs piAcp; };

  sourceModels = import ./synthetic-models.nix;

  # The four Synthetic models earlier generations wrote before the ledger
  # existed, with the startup thinking levels those generations set. Defined
  # once here so the one-time settings.json cleanup and the models.json
  # preLedgerIds seed name the same IDs.
  legacyStartupLevels = {
    "hf:zai-org/GLM-5.3" = [ "max" ];
    "hf:zai-org/GLM-5.3-Flash" = [ "high" ];
    "hf:deepseek-ai/DeepSeek-V4.1-Flash-1017" = [
      "low"
      "high"
    ];
    "hf:moonshotai/Kimi-K3" = [ "max" ];
  };

  # Every model of both committed catalog snapshots, built by a derivation
  # (pi-declarations.nix). The merger owns each provider's models through its
  # ledger, so a model a newer snapshot drops leaves models.json on the next
  # apply. Each apiKey is a `!` command naming a packaged helper, so no key
  # reaches the file.
  declaredModels = import ./pi-declarations.nix {
    inherit pkgs pi;
    preLedgerIds = lib.attrNames legacyStartupLevels;
  };

  # defaultProjectTrust never: a checkout Pi works in must not be able to supply
  # extensions or packages that run code. No model gets a startup thinking
  # level, so Pi picks its own. The startup levels earlier generations wrote
  # are removed once, and only while they hold the value written, so a level
  # the user chose stays.
  declaredSettings = pkgs.writeText "pi-declared-settings.json" (
    builtins.toJSON {
      set = {
        defaultProvider = "synthetic";
        defaultModel = sourceModels.${sourceModels.defaultModel}.id;
        defaultProjectTrust = "never";
      };
      removePaths = lib.mapAttrsToList (id: values: {
        path = [ "modelThinkingLevels" ];
        key = "synthetic/${id}";
        inherit values;
        migration = "pi-startup-levels-2026-10";
      }) legacyStartupLevels;
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
    inherit
      pkgs
      syntheticKeyFile
      exaKeyFile
      openrouterKeyFile
      ;
  };

  # Unguarded and after installPackages for the reasons given on
  # claudeSettings in claude.nix: a refusal must fail the rebuild loudly
  # without stranding linkGeneration or installPackages behind it. Pi rewrites
  # both files itself, so Home Manager never owns them.
  home.activation.piModels = mergeInto "Pi models" "models.json" declaredModels;
  home.activation.piSettings = mergeInto "Pi settings" "settings.json" declaredSettings;
}
