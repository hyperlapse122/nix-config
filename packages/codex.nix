{ pkgs }:

let
  inherit (pkgs) lib;
  source = builtins.fromJSON (builtins.readFile ./codex-release.json);
in
pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "codex";
  inherit (source) version;

  # The musl build is statically linked, so it runs on NixOS unpatched.
  src = pkgs.fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${finalAttrs.version}/codex-x86_64-unknown-linux-musl.tar.gz";
    inherit (source) hash;
  };

  # The tarball holds the bare binary with no top-level directory.
  sourceRoot = ".";

  nativeBuildInputs = [
    pkgs.makeWrapper
    pkgs.writableTmpDirAsHomeHook
  ];

  # The update flags hold under any CODEX_HOME, including the one Orca sets in
  # its terminals, whose config.toml never receives the declared settings.
  # daemon_auto_start would install and update a background copy of Codex
  # outside the store; nixpkgs patches it off, which a prebuilt pin cannot.
  installPhase = ''
    runHook preInstall

    install -Dm755 codex-x86_64-unknown-linux-musl $out/libexec/codex/codex
    makeWrapper $out/libexec/codex/codex $out/bin/codex \
      --prefix PATH : ${
        lib.makeBinPath [
          pkgs.ripgrep
          pkgs.bubblewrap
        ]
      } \
      --add-flags "-c check_for_update_on_startup=false --disable in_app_updates --disable daemon_auto_start"

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ pkgs.versionCheckHook ];
  versionCheckKeepEnvironment = [ "HOME" ];

  meta = {
    description = "Lightweight coding agent that runs in your terminal";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "codex";
  };
})
