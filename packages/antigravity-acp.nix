/*
  The Antigravity ACP runtime the pinned T3 Code requires on this system, as
  T3 Code's own installer would unpack it. home/h82/t3code.nix links the two
  binaries into T3 Code's managed runtime directory, so the provider is
  installed without a download.

  The pin comes from packages/t3code-release.json, which scripts/t3code-release
  reads from the T3 Code source at the pinned tag. The archive hash is the
  sha256 T3 Code verifies and names the version directory after.
*/
{ pkgs }:

let
  source = builtins.fromJSON (builtins.readFile ./t3code-release.json);
  system = pkgs.stdenv.hostPlatform.system;
  pin =
    source.antigravity.${system}
      or (throw "packages/t3code-release.json pins no Antigravity runtime for ${system}");
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "antigravity-acp";
  inherit (pin) version;

  src = pkgs.fetchurl {
    inherit (pin) url hash;
  };

  nativeBuildInputs = [ pkgs.unzip ];
  sourceRoot = ".";

  # T3 Code checks each binary's exact byte size, and the .par executable
  # carries an appended archive, so fixup's stripping and patching would
  # break both. NixOS runs the unpatched binaries through nix-ld, as it does
  # the runtime T3 Code downloads.
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    install -Dm555 ${pin.executable.name} -t $out/libexec/antigravity-acp
    install -Dm555 ${pin.harness.name} -t $out/libexec/antigravity-acp

    runHook postInstall
  '';

  passthru = { inherit pin; };

  meta = {
    description = "Google Antigravity ACP server for T3 Code";
    homepage = "https://antigravity.google";
    license = pkgs.lib.licenses.unfree;
    platforms = builtins.attrNames source.antigravity;
    sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
  };
}
