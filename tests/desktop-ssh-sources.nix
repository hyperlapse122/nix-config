{ pkgs, self }:
let
  python = pkgs.python3.withPackages (ps: [
    ps.cryptography
    ps.pyyaml
  ]);
in
pkgs.runCommand "desktop-ssh-sources-tests" { nativeBuildInputs = [ python ]; } ''
  python ${./check_desktop_ssh_config.py} --root ${self}
  touch $out
''
