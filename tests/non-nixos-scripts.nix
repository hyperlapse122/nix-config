/*
  Check interface:

    import ./tests/non-nixos-scripts.nix { inherit pkgs; }
    -> { install-user-age-identity, nr-linux, nr-darwin }

  The unit tests of the non-NixOS helper scripts, each run against a copy of
  the script outside the store: tests/test_install_user_age_identity.py for
  scripts/install-user-age-identity, tests/nr-linux.sh for
  scripts/nr-linux, and tests/nr-darwin.sh for scripts/nr-darwin.
*/
{ pkgs }:
{
  install-user-age-identity =
    pkgs.runCommand "install-user-age-identity-tests" { nativeBuildInputs = [ pkgs.python3 ]; }
      ''
        export PYTHONDONTWRITEBYTECODE=1
        mkdir -p scripts tests
        cp ${../scripts/install-user-age-identity} scripts/install-user-age-identity
        cp ${./test_install_user_age_identity.py} tests/test_install_user_age_identity.py
        python tests/test_install_user_age_identity.py
        touch $out
      '';

  nr-linux = pkgs.runCommand "nr-linux-tests" { nativeBuildInputs = [ pkgs.git ]; } ''
    mkdir -p scripts tests
    cp ${../scripts/nr-linux} scripts/nr-linux
    cp ${./nr-linux.sh} tests/nr-linux.sh
    chmod +x scripts/nr-linux
    patchShebangs scripts/nr-linux
    bash tests/nr-linux.sh scripts/nr-linux
    touch $out
  '';

  nr-darwin = pkgs.runCommand "nr-darwin-tests" { nativeBuildInputs = [ pkgs.git ]; } ''
    mkdir -p scripts tests
    cp ${../scripts/nr-darwin} scripts/nr-darwin
    cp ${./nr-darwin.sh} tests/nr-darwin.sh
    chmod +x scripts/nr-darwin
    patchShebangs scripts/nr-darwin
    bash tests/nr-darwin.sh scripts/nr-darwin
    touch $out
  '';
}
