{ pkgs }:

let
  python = pkgs.python3.withPackages (ps: [
    ps.cryptography
    ps.bcrypt
    ps.dbus-python
  ]);
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "desktop-ssh";
  version = "1";
  src = ../scripts/desktop-ssh;
  dontUnpack = true;
  nativeBuildInputs = [ python ];
  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/desktop-ssh"
    substituteInPlace "$out/bin/desktop-ssh" \
      --replace-fail '#!/usr/bin/env python3' '#!${python}/bin/python3'
    runHook postInstall
  '';
}
