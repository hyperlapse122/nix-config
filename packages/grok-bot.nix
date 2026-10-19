{ pkgs }:

let
  inherit (pkgs) lib;
  source = builtins.fromJSON (builtins.readFile ./grok-bot-release.json);
  system = pkgs.stdenv.hostPlatform.system;
  debArch =
    {
      x86_64-linux = "amd64";
      aarch64-linux = "arm64";
    }
    .${system} or null;
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
    pkgs.file
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
    # The bundled native Node addons need libstdc++.so.6.
    pkgs.stdenv.cc.cc.lib
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

  # The release feed names the .deb, so a feed that points one architecture
  # at another's package or version fails here instead of on that host.
  unpackPhase = ''
    runHook preUnpack
    if [ "$(dpkg-deb --field $src Version)" != ${lib.escapeShellArg source.version} ] \
      || [ "$(dpkg-deb --field $src Architecture)" != ${lib.escapeShellArg debArch} ]; then
      echo "$src is not grok-bot ${source.version} for ${debArch}" >&2
      exit 1
    fi
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
    # autoPatchelf skips only ET_EXEC static binaries, and the runpath it
    # appends would leave a static-pie one segfaulting. None ships in this
    # release; any later one is set aside here and restored in postFixup.
    mkdir -p "$TMPDIR/static-pie"
    (cd $out/lib/grok-bot && find . -type f -exec file -0 -- {} + | while IFS= read -r -d "" path && IFS= read -r type; do
      case $type in
        *'static-pie linked'*) install -Dm755 "$path" "$TMPDIR/static-pie/$path" ;;
      esac
    done)
    cp -r usr/share/icons $out/share/icons
    install -Dm644 usr/share/applications/grok-bot.desktop \
      $out/share/applications/grok-bot.desktop
    substituteInPlace $out/share/applications/grok-bot.desktop \
      --replace-fail 'Exec=grok-bot ' "Exec=$out/bin/grok-bot "

    makeWrapper $out/lib/grok-bot/grok-bot $out/bin/grok-bot \
      --unset APPIMAGE \
      --prefix XDG_DATA_DIRS : "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}" \
      --prefix XDG_DATA_DIRS : "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}" \
      --suffix PATH : "${lib.makeBinPath [ pkgs.xdg-utils ]}" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"

    runHook postInstall
  '';

  # postFixup runs before the postFixupHooks array the hook registers itself
  # in, so restoring there would precede the patching. The hook is disabled
  # and run here instead, ahead of the restore.
  dontAutoPatchelf = true;
  postFixup = ''
    autoPatchelf -- "$out"
    (cd "$TMPDIR/static-pie" && find . -type f -print0 | while IFS= read -r -d "" file; do
      install -Dm755 "$file" "$out/lib/grok-bot/$file"
    done)
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
