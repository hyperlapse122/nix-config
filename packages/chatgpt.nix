{ pkgs }:

let
  source = builtins.fromJSON (builtins.readFile ./chatgpt-version.json);
in
pkgs.stdenv.mkDerivation {
  pname = "chatgpt";
  inherit (source) version;

  src = pkgs.fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/${source.filename}";
    inherit (source) hash;
  };

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
    pkgs.gdk-pixbuf
    pkgs.glib
    pkgs.gtk3
    pkgs.libGL
    pkgs.libdrm
    pkgs.libnotify
    pkgs.libpulseaudio
    pkgs.libsecret
    pkgs.libusb1
    pkgs.libuuid
    pkgs.libxcb
    pkgs.libxkbcommon
    pkgs.libgbm
    pkgs.nspr
    pkgs.nss
    pkgs.openssl
    pkgs.pango
    pkgs.systemdLibs
    pkgs.tpm2-tss
    pkgs.vulkan-loader
    pkgs.libx11
    pkgs.libxcomposite
    pkgs.libxdamage
    pkgs.libxext
    pkgs.libxfixes
    pkgs.libxrandr
    pkgs.libxrender
    pkgs.libxtst
    pkgs.libxshmfence
  ];

  appendRunpaths = pkgs.lib.makeLibraryPath [
    pkgs.libGL
    pkgs.libpulseaudio
  ];

  # Chromium loads the Qt shims only under a Qt platform theme; their Qt
  # libraries stay unresolved rather than pulling Qt into the closure.
  autoPatchelfIgnoreMissingDeps = [
    "libQt5Core.so.5"
    "libQt5Gui.so.5"
    "libQt5Widgets.so.5"
    "libQt6Core.so.6"
    "libQt6Gui.so.6"
    "libQt6Widgets.so.6"
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile $src | tar --extract
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,share,lib}
    cp -r usr/share/* $out/share/
    cp -r usr/lib/chatgpt $out/lib/

    # Native module prebuilds ship for every platform; keep only glibc x86_64.
    find $out/lib/chatgpt -type d -path '*/prebuilds/*' -prune ! -name '*linux-x64' -exec rm -rf {} +
    find $out/lib/chatgpt -path '*/prebuilds/*' -name '*musl*' -exec rm -rf {} +

    # Upstream's display backend is kept: no ozone flags (R6).
    makeWrapper $out/lib/chatgpt/ChatGPT $out/bin/chatgpt \
      --prefix XDG_DATA_DIRS : "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}" \
      --prefix XDG_DATA_DIRS : "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}" \
      --suffix PATH : "${pkgs.lib.makeBinPath [ pkgs.xdg-utils ]}"

    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "ChatGPT for Linux";
    homepage = "https://chatgpt.com";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "chatgpt";
  };
}
