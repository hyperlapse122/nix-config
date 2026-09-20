{ pkgs }:

let
  pinentryCard = pkgs.stdenvNoCC.mkDerivation {
    pname = "pinentry-card-wrapper";
    version = "1";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.python3 ];
    installPhase = ''
      install -Dm755 ${../scripts/pinentry-card} $out/bin/pinentry-card
      ln -s pinentry-card $out/bin/pinentry
      substituteInPlace $out/bin/pinentry-card \
        --replace-fail '@PINENTRY_QT@' '${pkgs.pinentry-qt}/bin/pinentry-qt' \
        --replace-fail '@PINENTRY_CURSES@' '${pkgs.pinentry-curses}/bin/pinentry-curses' \
        --replace-fail '@SECRET_TOOL@' '${pkgs.libsecret}/bin/secret-tool'
      patchShebangs $out/bin/pinentry-card
    '';
    meta.mainProgram = "pinentry-card";
  };

  restoreAgeIdentity = pkgs.stdenvNoCC.mkDerivation {
    pname = "restore-age-identity";
    version = "1";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.python3 ];
    installPhase = ''
      install -Dm755 ${../scripts/restore-age-identity} $out/bin/restore-age-identity
      substituteInPlace $out/bin/restore-age-identity \
        --replace-fail '@AGE_KEYGEN@' '${pkgs.age}/bin/age-keygen'
      patchShebangs $out/bin/restore-age-identity
    '';
    meta.mainProgram = "restore-age-identity";
  };
in
{
  inherit pinentryCard restoreAgeIdentity;
}
