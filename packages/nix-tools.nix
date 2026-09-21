{ pkgs }:

let
  nr = pkgs.stdenvNoCC.mkDerivation {
    pname = "nr";
    version = "1";
    dontUnpack = true;
    installPhase = ''
      install -Dm755 ${../scripts/nr} $out/bin/nr
      substituteInPlace $out/bin/nr \
        --replace-fail '@NVD@' '${pkgs.nvd}/bin/nvd' \
        --replace-fail '@GIT@' '${pkgs.git}/bin/git'
      patchShebangs $out/bin/nr
    '';
    meta.mainProgram = "nr";
  };
in
{
  inherit nr;
}
