{ pkgs }:

let
  orcaSettingsReconcile = pkgs.stdenvNoCC.mkDerivation {
    pname = "orca-settings-reconcile";
    version = "1";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.python3 ];
    installPhase = ''
      install -Dm755 ${../scripts/orca-settings-reconcile} $out/bin/orca-settings-reconcile
      patchShebangs $out/bin/orca-settings-reconcile
    '';
    meta.mainProgram = "orca-settings-reconcile";
  };
in
{
  inherit orcaSettingsReconcile;
}
