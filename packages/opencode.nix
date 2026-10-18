{
  pkgs,
  tokenFile ? "/run/secrets/cli-auth/synthetic_api_key",
}:

let
  inherit (pkgs) lib stdenv;
  source = builtins.fromJSON (builtins.readFile ./opencode-release.json);
  system = stdenv.hostPlatform.system;
  pin =
    source.platforms.${system}
      or (throw "packages/opencode-release.json pins no opencode asset for ${system}");
  # The path lands inside single quotes in the wrapper.
  safeTokenFile = builtins.match "/[A-Za-z0-9._/+-]+" tokenFile != null;

  # The system and user parts of the agent instructions, which a standalone
  # session loads through this added config file. OpenCode v2 always loads
  # ~/.config/opencode/AGENTS.md, so the file goes here instead, where the
  # wrapper can leave it out of a reviewer run.
  instructions = (import ../home/h82/agents/instructions/render.nix { inherit pkgs lib; }).render {
    harness = "opencode";
    parts = [
      "system"
      "user"
    ];
  };
  instructionsConfig = pkgs.writeText "opencode-instructions-config.json" (
    builtins.toJSON { instructions = [ "${instructions}" ]; }
  );
in
assert lib.assertMsg safeTokenFile
  "opencode: tokenFile '${tokenFile}' is not a plain absolute path";
stdenv.mkDerivation {
  pname = "opencode";
  inherit (source) version;

  src = pkgs.fetchurl { inherit (pin) url hash; };

  # Each npm tarball holds package.json and one executable, bin/opencode.
  sourceRoot = "package";

  # OpenCode is a Bun-compiled executable whose JavaScript payload rides at
  # the end of the file; stripping it leaves the bare Bun runtime. The -musl
  # builds load the musl loader dynamically, so the glibc builds are the ones
  # patched to the store's loader, as nixpkgs' claude-code is.
  dontStrip = true;
  nativeBuildInputs = [
    pkgs.writableTmpDirAsHomeHook
  ]
  ++ lib.optional stdenv.hostPlatform.isLinux pkgs.autoPatchelfHook;
  buildInputs = lib.optional stdenv.hostPlatform.isLinux stdenv.cc.cc.lib;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/opencode $out/libexec/opencode/opencode
    install -Dm755 ${../scripts/opencode} $out/bin/opencode
    substituteInPlace $out/bin/opencode \
      --replace-fail '@TOKEN_FILE@' '${tokenFile}' \
      --replace-fail '@INSTRUCTIONS_CONFIG@' '${instructionsConfig}' \
      --replace-fail '@OPENCODE@' "$out/libexec/opencode/opencode" \
      --replace-fail '@RIPGREP_BIN@' '${lib.getBin pkgs.ripgrep}/bin'
    patchShebangs $out/bin/opencode

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ pkgs.versionCheckHook ];
  versionCheckKeepEnvironment = [ "HOME" ];

  passthru = { inherit instructions instructionsConfig; };

  meta = {
    description = "AI coding agent built for the terminal";
    homepage = "https://github.com/anomalyco/opencode";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.attrNames source.platforms;
    mainProgram = "opencode";
  };
}
