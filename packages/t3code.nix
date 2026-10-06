{ pkgs }:

let
  inherit (pkgs) lib;
  source = builtins.fromJSON (builtins.readFile ./t3code-release.json);
  system = pkgs.stdenv.hostPlatform.system;
  # Missing on a system the pin does not cover; meta.platforms then refuses
  # the package by name rather than failing on a missing attribute.
  pin = (source.platforms.${system} or source.platforms.x86_64-linux).desktop;

  pname = "t3code-desktop";
  inherit (source) version;

  src = pkgs.fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/${source.tag}/${pin.asset}";
    inherit (pin) hash;
  };

  appimageContents = pkgs.appimageTools.extract {
    inherit pname version src;
  };
in
pkgs.appimageTools.wrapType2 {
  inherit pname version src;

  # The AppImage updater runs whenever APPIMAGE is set, and the wrapper's exec
  # script exports any APPIMAGE the environment passes in, so the updater is
  # turned off explicitly; the version changes only through the flake.
  #
  # Agent sessions the bundled server starts inherit this bubblewrap sandbox:
  # its /etc lacks containers/, subuid, and subgid, and no_new_privs disables
  # the setuid newuidmap. A local rootless Podman started here builds its pause
  # process from that view, and the host's Podman service then joins it and
  # fails image pulls. Remote mode sends every podman and docker call to the
  # host service instead, as packages/orca.nix does.
  #
  # The Antigravity ACP server that T3 downloads embeds an OpenSSL whose
  # default CA path, /opt/pyca/cryptography/openssl/cert.pem, does not exist
  # on NixOS. Without SSL_CERT_FILE every model request fails certificate
  # verification and the session hangs after session/prompt with no output.
  extraBwrapArgs = [
    "--setenv T3CODE_DISABLE_AUTO_UPDATE 1"
    ''--setenv CONTAINER_HOST "unix://$XDG_RUNTIME_DIR/podman/podman.sock"''
    "--setenv SSL_CERT_FILE /etc/ssl/certs/ca-certificates.crt"
  ];

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/t3code.desktop $out/share/applications/t3code.desktop
    substituteInPlace $out/share/applications/t3code.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'
    mkdir -p $out/share/icons
    cp -r ${appimageContents}/usr/share/icons/* $out/share/icons/
  '';

  meta = {
    description = "Desktop GUI for coding agents like Codex and Claude (nightly)";
    homepage = "https://github.com/pingdotgg/t3code";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.attrNames source.platforms;
    mainProgram = pname;
  };
}
