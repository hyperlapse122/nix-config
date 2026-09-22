{ pkgs }:

let
  agentSettings = pkgs.stdenvNoCC.mkDerivation {
    pname = "agent-settings";
    version = "1";
    dontUnpack = true;
    # patchShebangs resolves the interpreter from the build PATH, so python3
    # has to be here for the `#!/usr/bin/env python3` line to be rewritten
    # into a store path rather than left dangling.
    nativeBuildInputs = [ pkgs.python3 ];
    installPhase = ''
      install -Dm755 ${../scripts/agent-settings} $out/bin/agent-settings
      patchShebangs $out/bin/agent-settings
    '';
    meta.mainProgram = "agent-settings";
  };
in
{
  inherit agentSettings;
}
