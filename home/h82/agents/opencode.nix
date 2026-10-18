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
  # nothing, so a review skips its cross-model peer.
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

  model = import ./opencode-model.nix;

  # `opencode mcp add` and `opencode plugin add` rewrite this file, so
  # activation assigns these keys and leaves everything else as OpenCode wrote
  # it. update replaces autoupdate in OpenCode v2, so the merge deletes the
  # legacy key; the wrapper's OPENCODE_DISABLE_AUTOUPDATE stays as the
  # backstop under every config T3 Code supplies. share = "disabled" keeps a
  # session from being published by link. OpenCode's synthetic catalog lists
  # only hf: model ids, so the syn: alias is declared as a model of that
  # provider. It is declared by its scalar name leaf: the merge refuses an
  # object value, and the leaf leaves the user's other providers and models
  # alone.
  declared = pkgs.writeText "opencode-declared-settings.json" (
    builtins.toJSON {
      set = {
        "$schema" = "https://opencode.ai/config.json";
        inherit model;
        update = "disable";
        share = "disabled";
      };
      setPaths = [
        {
          path = [
            "provider"
            "synthetic"
            "models"
            (lib.removePrefix "synthetic/" model)
            "name"
          ];
          value = lib.removePrefix "synthetic/" model;
        }
      ];
      remove = [ "autoupdate" ];
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
  home.packages = [ wrapper ];

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
