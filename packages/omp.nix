{ pkgs }:

let
  inherit (pkgs) lib stdenv;
  source = builtins.fromJSON (builtins.readFile ./omp-release.json);
  system = stdenv.hostPlatform.system;
  pin = source.platforms.${system} or (throw "omp: no native release pinned for ${system}");
in
stdenv.mkDerivation {
  pname = "omp";
  inherit (source) version;

  src = pkgs.fetchurl { inherit (pin) url hash; };
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  # These are single Bun executables, not archives. Stripping loses the
  # appended application; Darwin fixups would invalidate its signature.
  dontStrip = true;
  dontFixup = stdenv.hostPlatform.isDarwin;
  nativeBuildInputs = [
    pkgs.writableTmpDirAsHomeHook
  ]
  ++ lib.optional stdenv.hostPlatform.isLinux pkgs.autoPatchelfHook;
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/libexec/omp/omp
    install -Dm755 ${../scripts/omp} $out/bin/omp
    substituteInPlace $out/bin/omp --replace-fail '@OMP@' "$out/libexec/omp/omp"
    patchShebangs $out/bin/omp
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ pkgs.versionCheckHook ];
  versionCheckKeepEnvironment = [ "HOME" ];

  meta = {
    description = "Oh My Pi terminal coding agent";
    homepage = "https://github.com/can1357/oh-my-pi";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.attrNames source.platforms;
    mainProgram = "omp";
  };
}
