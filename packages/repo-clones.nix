{ pkgs }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "repo-clones";
  version = "1";
  dontUnpack = true;
  installPhase = ''
    install -Dm755 ${../scripts/repo-clones} $out/bin/repo-clones
    substituteInPlace $out/bin/repo-clones \
      --replace-fail '@GIT@' '${pkgs.git}/bin/git' \
      --replace-fail '@GHQ@' '${pkgs.ghq}/bin/ghq'
    patchShebangs $out/bin/repo-clones
  '';
  meta.mainProgram = "repo-clones";
}
