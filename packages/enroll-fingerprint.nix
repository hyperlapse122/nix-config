{ pkgs }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "enroll-fingerprint";
  version = "1";
  dontUnpack = true;
  nativeBuildInputs = [ pkgs.bash ];
  installPhase = ''
    install -Dm755 ${../scripts/enroll-fingerprint} $out/bin/enroll-fingerprint
    substituteInPlace $out/bin/enroll-fingerprint \
      --replace-fail '@PAMTESTER@' '${pkgs.pamtester}/bin/pamtester' \
      --replace-fail '@FPRINTD_ENROLL@' '${pkgs.fprintd}/bin/fprintd-enroll' \
      --replace-fail '@FPRINTD_LIST@' '${pkgs.fprintd}/bin/fprintd-list' \
      --replace-fail '@SUDO@' '/run/wrappers/bin/sudo'
    patchShebangs $out/bin/enroll-fingerprint
  '';
  meta.mainProgram = "enroll-fingerprint";
}
