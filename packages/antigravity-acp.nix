/*
  An Antigravity ACP runtime on this system, as T3 Code's own installer would
  unpack it. home/h82/t3code.nix links the two binaries into T3 Code's managed
  runtime directory, so the provider is installed without a download.

  `pins` is required and has no default, so a caller that forgets it fails
  evaluation instead of building another runtime. It maps each system to its
  release; T3 Code's callers pass the antigravity entry of
  packages/t3code-release.json, which scripts/t3code-release reads from the
  T3 Code source at the pinned tag. The archive hash is the sha256 T3 Code
  verifies and names the version directory after.
*/
{ pkgs, pins }:

let
  system = pkgs.stdenv.hostPlatform.system;
  pin = pins.${system} or (throw "the Antigravity ACP pins name no runtime for ${system}");
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

    # Moved rather than copied: the binaries are about 1 GB unpacked on Linux.
    mkdir -p $out/libexec/antigravity-acp
    mv ${pin.executable.name} ${pin.harness.name} $out/libexec/antigravity-acp/
    chmod 555 $out/libexec/antigravity-acp/*

    runHook postInstall
  '';

  passthru = { inherit pin; };

  meta = {
    description = "Google Antigravity ACP server for T3 Code";
    homepage = "https://antigravity.google";
    license = pkgs.lib.licenses.unfree;
    platforms = builtins.attrNames pins;
    sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
  };
}
