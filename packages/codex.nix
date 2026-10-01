{ pkgs }:

let
  inherit (pkgs) lib;
  source = builtins.fromJSON (builtins.readFile ./codex-release.json);
  system = pkgs.stdenv.hostPlatform.system;
  # Missing on a system the pin does not cover; meta.platforms then refuses
  # the package by name rather than failing on a missing attribute.
  platform = source.platforms.${system} or source.platforms.x86_64-linux;
  fetchAsset =
    version: pin:
    pkgs.fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/${pin.asset}";
      inherit (pin) hash;
    };
  binaryOf = pin: lib.removeSuffix ".tar.gz" pin.asset;
in
pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "codex";
  inherit (source) version;

  # The musl builds are statically linked, so they run on NixOS and other
  # distributions unpatched.
  srcs = [
    (fetchAsset finalAttrs.version platform.codex)
    (fetchAsset finalAttrs.version platform.codeModeHost)
  ];

  # Each tarball holds one bare binary with no top-level directory.
  sourceRoot = ".";

  nativeBuildInputs = [
    pkgs.makeWrapper
    pkgs.writableTmpDirAsHomeHook
  ];

  # The update flags hold under any CODEX_HOME, including the one Orca sets in
  # its terminals, whose config.toml never receives the declared settings.
  # daemon_auto_start would install and update a background copy of Codex
  # outside the store; nixpkgs patches it off, which a prebuilt pin cannot.
  # Codex spawns codex-code-mode-host from beside its own executable, never
  # from PATH, so the host sits next to the real binary, not in bin/.
  installPhase = ''
    runHook preInstall

    install -Dm755 ${binaryOf platform.codex} $out/libexec/codex/codex
    install -Dm755 ${binaryOf platform.codeModeHost} $out/libexec/codex/codex-code-mode-host
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
  # versionCheckHook runs only the CLI; run the host too, on every system the
  # package builds for, so a broken host fails the build rather than Code Mode.
  postInstallCheck = ''
    $out/libexec/codex/codex-code-mode-host --help > /dev/null
  '';

  meta = {
    description = "Lightweight coding agent that runs in your terminal";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.attrNames source.platforms;
    mainProgram = "codex";
  };
})
