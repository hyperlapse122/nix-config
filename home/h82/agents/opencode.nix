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

  # The wrapper reads /run/secrets/cli-auth/opencode_api_key at run time.
  # Bootstrap generations have no such file, and OpenCode then runs on the
  # free tier's anonymous limits.
  wrapper = import ../../../packages/opencode.nix (
    {
      inherit pkgs;
    }
    # A non-NixOS host, Linux or macOS, keeps its decrypted tokens in the
    # user's state directory instead (home/h82/security/non-nixos-secrets.nix).
    // lib.optionalAttrs (config.my.kind != "nixos") {
      tokenFile = "${config.my.secrets.stateDir}/opencode_api_key";
    }
  );

  # `opencode mcp add` and `opencode plugin add` rewrite this file, so
  # activation assigns these keys and leaves everything else as OpenCode wrote
  # it. update replaces autoupdate in OpenCode v2, so the merge deletes the
  # legacy key; the wrapper's OPENCODE_DISABLE_AUTOUPDATE stays as the
  # backstop under every config T3 Code supplies. share = "disabled" keeps a
  # session from being published by link.
  declared = pkgs.writeText "opencode-declared-settings.json" (
    builtins.toJSON {
      set = {
        "$schema" = "https://opencode.ai/config.json";
        model = import ./opencode-model.nix;
        update = "disable";
        share = "disabled";
      };
      remove = [ "autoupdate" ];
    }
  );

  # OpenCode v2 clients share one detached background server, spawned with the
  # first client's environment, so it would keep that run's API key, switches
  # and version. Disabled, every run owns its server and the wrapper's
  # exported key and switches apply. The password, port and env OpenCode
  # writes beside this key stay as they are.
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

  # Unguarded and after installPackages for the reasons given on
  # claudeSettings in claude.nix: a refusal must fail the rebuild loudly
  # without stranding linkGeneration or installPackages behind it.
  home.activation.opencodeSettings = lib.hm.dag.entryAfter [ "installPackages" ] ''
    ${merger} \
      --label OpenCode \
      --settings ${config.home.homeDirectory}/.config/opencode/opencode.json \
      --declared ${declared}
  '';

  home.activation.opencodeService = lib.hm.dag.entryAfter [ "installPackages" ] ''
    ${merger} \
      --label "OpenCode service" \
      --settings ${config.home.homeDirectory}/.config/opencode/service.json \
      --declared ${declaredService}
  '';
}
