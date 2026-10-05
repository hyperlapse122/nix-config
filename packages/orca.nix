{ pkgs }:

let
  pname = "orca-ide";
  version = "1.4.206";

  src = pkgs.fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
    sha256 = "547c60825ce6c8cedd94a02b3c445fbf2d88173576164b1b66444113ff225550";
  };

  appimageContents = pkgs.appimageTools.extract {
    inherit pname version src;
  };
in
pkgs.appimageTools.wrapType2 {
  inherit pname version src;

  # Agent terminals inherit this bubblewrap sandbox: its /etc lacks containers/,
  # subuid, and subgid, and no_new_privs disables the setuid newuidmap. A local
  # rootless Podman started here builds its pause process from that view, and
  # the host's Podman service then joins it and fails image pulls. Remote mode
  # sends every podman and docker call to the host service instead.
  extraBwrapArgs = [
    ''--setenv CONTAINER_HOST "unix://$XDG_RUNTIME_DIR/podman/podman.sock"''
  ];

  # `cli` is the extracted AppImage's Node-mode entry point, the file Orca's
  # own linux-orca-cli-shim runs. The wrapper's bin/orca-ide launches the GUI.
  # It runs the unwrapped Electron binary outside the FHS sandbox, so it relies
  # on the host's nix-ld (modules/nixos/system/nix-ld.nix).
  passthru.cli = "${appimageContents}/resources/bin/orca-ide";

  extraInstallCommands = ''
    for desktop in "${appimageContents}/orca.desktop" "${appimageContents}/orca-ide.desktop"; do
      if [ -f "$desktop" ]; then
        install -m 444 -D "$desktop" $out/share/applications/orca.desktop
        substituteInPlace $out/share/applications/orca.desktop \
          --replace-fail 'Exec=AppRun' 'Exec=orca-ide'
        break
      fi
    done

    if [ -d "${appimageContents}/usr/share/icons" ]; then
      mkdir -p $out/share/icons
      cp -r ${appimageContents}/usr/share/icons/* $out/share/icons/
    elif [ -f "${appimageContents}/orca.png" ]; then
      install -m 444 -D ${appimageContents}/orca.png $out/share/icons/hicolor/512x512/apps/orca.png
    fi

    ln -sf orca-ide $out/bin/orca
  '';

  meta = with pkgs.lib; {
    description = "Next-gen IDE for parallel agentic development";
    homepage = "https://github.com/stablyai/orca";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "orca-ide";
  };
}
