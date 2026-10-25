{
  config,
  lib,
  pkgs,
  ...
}:
let
  tools = import ../../../packages/agent-tools.nix { inherit pkgs; };
  syntheticModels = import ./synthetic-models.nix;
  defaultModel = syntheticModels.${syntheticModels.defaultModel};
  keyDirectory =
    if config.my.kind != "nixos" then config.my.secrets.stateDir else "/run/secrets/cli-auth";
  omp = import ../../../packages/omp.nix {
    inherit pkgs;
    syntheticKeyFile = "${keyDirectory}/synthetic_api_key";
    openrouterKeyFile = "${keyDirectory}/openrouter_api_key";
  };
  documents = config.my.omp.documents;
  declared = pkgs.writeText "omp-common-documents.json" (
    builtins.toJSON (lib.mapAttrs (_: path: toString path) documents)
  );
in
{
  options.my.omp = {
    documents = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      description = "Complete common OMP documents restored on apply; state stays writable and separate.";
    };
    declaration = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      description = "Manifest shared by Home Manager and NixOS activation.";
    };
  };

  config = {
    my.omp.declaration = declared;
    my.omp.documents = {
      "config.yml" = lib.mkDefault (
        pkgs.writeText "omp-config.json" (
          builtins.toJSON {
            memory.backend = "off";
            autolearn.enabled = false;
            disabledProviders = [ "omp-managed" ];
            startup.checkUpdate = false;
            marketplace.autoUpdate = "off";
            modelRoles.default = "synthetic/${defaultModel.id}";
            defaultThinkingLevel = defaultModel.defaultEffort;
          }
        )
      );
      "models.yml" = lib.mkDefault (import ./omp-declarations.nix { inherit pkgs omp; });
      "mcp.json" = lib.mkDefault (pkgs.writeText "omp-mcp.json" ''{"mcpServers":{}}'');
    };

    home.packages = [ omp ];
    # These documents stay regular writable files: OMP's settings UI can edit
    # them between applies. Direct activation runs on every non-NixOS apply;
    # the system hook covers NixOS even when its home generation is unchanged.
    home.activation.ompSettings = lib.hm.dag.entryAfter [ "installPackages" ] ''
      ${tools.ompConfigReconcile}/bin/omp-config-reconcile \
        --agent-dir ${lib.escapeShellArg "${config.home.homeDirectory}/.omp/agent"} \
        --declared ${declared} ''${DRY_RUN+--dry-run}
    '';
  };
}
