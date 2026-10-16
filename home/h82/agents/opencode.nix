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

  # `opencode mcp add` and `opencode plugin -g` rewrite this file, so
  # activation assigns these keys and leaves everything else as OpenCode wrote
  # it. autoupdate is deprecated in the published schema; the wrapper's
  # OPENCODE_DISABLE_AUTOUPDATE is what holds under every config T3 Code
  # supplies. share = "disabled" keeps a session from being published by
  # link.
  declared = pkgs.writeText "opencode-declared-settings.json" (
    builtins.toJSON {
      set = {
        "$schema" = "https://opencode.ai/config.json";
        model = import ./opencode-model.nix;
        autoupdate = false;
        share = "disabled";
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
}
