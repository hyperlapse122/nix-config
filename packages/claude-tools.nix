{ pkgs }:

let
  claudeSettings = pkgs.stdenvNoCC.mkDerivation {
    pname = "claude-settings";
    version = "1";
    dontUnpack = true;
    # patchShebangs resolves the interpreter from the build PATH, so python3
    # has to be here for the `#!/usr/bin/env python3` line to be rewritten
    # into a store path rather than left dangling.
    nativeBuildInputs = [ pkgs.python3 ];
    installPhase = ''
      install -Dm755 ${../scripts/claude-settings} $out/bin/claude-settings
      patchShebangs $out/bin/claude-settings
    '';
    meta.mainProgram = "claude-settings";
  };
in
{
  inherit claudeSettings;
}
