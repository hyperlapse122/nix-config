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

  # The agent skills are published only in the source tree; the AppImage
  # carries their manifests, not the SKILL.md files. The tag follows `version`
  # so the stubs match the CLI they drive. The version-bearing name matters: a
  # fixed-output fetch keeps its store path when only `rev` changes, so under
  # the default `source` name a bump that forgot this hash would silently reuse
  # the previous release's skills instead of failing.
  skills = pkgs.fetchFromGitHub {
    name = "orca-skills-${version}";
    owner = "stablyai";
    repo = "orca";
    tag = "v${version}";
    hash = "sha256-TTcHOf2SB8LYNCtA4A488k6aKW1HXjxcoWy5VlXn+FQ=";
  };
in
pkgs.appimageTools.wrapType2 {
  inherit pname version src;

  passthru = { inherit skills; };

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
