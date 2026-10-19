{ pkgs }:

let
  inherit (pkgs) lib;
  source = builtins.fromJSON (builtins.readFile ./grok-bot-release.json);
  system = pkgs.stdenv.hostPlatform.system;
  platform =
    source.platforms.${system}
      or (throw "packages/grok-bot-release.json pins no grok bot release for ${system}");
in
pkgs.stdenv.mkDerivation {
  pname = "grok-bot";
  inherit (source) version;

  src = pkgs.fetchurl { inherit (platform) url hash; };

  nativeBuildInputs = [
    pkgs.dpkg
    pkgs.autoPatchelfHook
    pkgs.makeWrapper
  ];

  buildInputs = [
    pkgs.alsa-lib
    pkgs.at-spi2-atk
    pkgs.at-spi2-core
    pkgs.atk
    pkgs.cairo
    pkgs.cups
    pkgs.dbus
    pkgs.expat
    pkgs.glib
    pkgs.gtk3
    pkgs.libGL
    pkgs.libdrm
    pkgs.libnotify
    pkgs.libsecret
    pkgs.libuuid
    pkgs.libxcb
    pkgs.libxkbcommon
    pkgs.libgbm
    pkgs.nspr
    pkgs.nss
    pkgs.pango
    pkgs.systemdLibs
    pkgs.libx11
    pkgs.libxcomposite
    pkgs.libxdamage
    pkgs.libxext
    pkgs.libxfixes
    pkgs.libxrandr
    pkgs.libxscrnsaver
    pkgs.libxtst
  ];

  # Chromium loads these with dlopen, so autoPatchelfHook cannot see them.
  appendRunpaths = lib.makeLibraryPath [ pkgs.libGL ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile $src | tar --extract
    runHook postUnpack
  '';

  # The .deb installs the app under "/opt/Grok Bot". The app's self-replacing
  # updater runs only when APPIMAGE is set, so the wrapper unsets it and the
  # pin stays the only updater.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib,share}
    cp -r "opt/Grok Bot" $out/lib/grok-bot
    cp -r usr/share/icons $out/share/icons
    install -Dm644 usr/share/applications/grok-bot.desktop \
      $out/share/applications/grok-bot.desktop
    substituteInPlace $out/share/applications/grok-bot.desktop \
      --replace-fail 'Exec=grok-bot ' "Exec=$out/bin/grok-bot "

    makeWrapper $out/lib/grok-bot/grok-bot $out/bin/grok-bot \
      --unset APPIMAGE \
      --prefix XDG_DATA_DIRS : "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}" \
      --prefix XDG_DATA_DIRS : "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}" \
      --suffix PATH : "${lib.makeBinPath [ pkgs.xdg-utils ]}"

    runHook postInstall
  '';

  meta = {
    description = "Grok Bot desktop app by xAI";
    homepage = "https://x.ai";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.attrNames source.platforms;
    mainProgram = "grok-bot";
  };
}
