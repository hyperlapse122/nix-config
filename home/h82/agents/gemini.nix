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

  # The Antigravity ACP runtime asks for a Google sign-in only when its
  # settings name the personal OAuth flow; Compound Engineering's Antigravity
  # route writes the same value into each run home. The runtime rewrites the
  # file, so activation assigns the key and keeps everything else it wrote.
  acpDeclared = pkgs.writeText "antigravity-acp-declared-settings.json" (
    builtins.toJSON {
      setPaths = [
        {
          path = [
            "auth"
            "type"
          ];
          value = "oauth-personal";
        }
      ];
    }
  );
in
{
  # Disable cross-session, implicit memory for the Gemini CLI
  # to preserve declarative environment determinism.
  home.file.".gemini/settings.json".text = builtins.toJSON {
    experimental = {
      autoMemory = false;
    };
  };

  # No executable-existence guard and no swallowed status, as in claude.nix:
  # the merger is a store path built from this module, and ordering after
  # installPackages keeps a refusal from stranding linkGeneration.
  home.activation.antigravityAcpSettings = lib.hm.dag.entryAfter [ "installPackages" ] ''
    if [[ ! -v DRY_RUN ]]; then
      ${merger} \
        --label 'Antigravity ACP' \
        --settings ${config.home.homeDirectory}/.gemini/antigravity-acp/settings.json \
        --declared ${acpDeclared}
    fi
  '';
}
