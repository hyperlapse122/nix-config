/*
  Check interface:

    import ./tests/desktop-autostart.nix { inherit pkgs self; }

  Asserts that the 1Password CLI module is enabled on both ThinkPad
  configurations and that the login autostart entries are declared on the
  production configuration only.

  Verifies:
  - programs._1password.enable is true on ThinkPad-X1-Carbon-Gen-11.
  - programs._1password.enable is true on ThinkPad-X1-Carbon-Gen-11-bootstrap.
  - The production Home Manager configuration declares an enabled, forced
    autostart entry targeting autostart/1password.desktop, whose Exec line runs
    the configured programs._1password-gui.package with --silent.
  - The same for autostart/kleopatra.desktop with --daemon.
  - Both entries declare Type=Application and X-KDE-autostart-phase=2.
  - The bootstrap configuration declares neither entry.

  The entries are located by their resolved target rather than by attribute
  name, and their enable and force flags are read beside their text, because an
  entry can be disabled or retargeted while its text still evaluates. Every
  store-path interpolation sits inside an optionalString guard so a removal
  mutation fails inside the builder rather than aborting evaluation.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  host = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11;
  bootstrapHost = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap;

  hostCli = host.config.programs._1password.enable;
  bootstrapCli = bootstrapHost.config.programs._1password.enable;

  onePasswordPackage = host.config.programs._1password-gui.package;
  kleopatraPackage = lib.lists.findFirst (p: (p.pname or "") == "kleopatra") null (
    host.config.home-manager.users.h82.home.packages
  );

  # Resolve by target, not by attribute name: target merely defaults to the name.
  # Home Manager's target apply expands a relative path against xdg.configHome
  # and then strips the home prefix, so derive the resolved form the same way
  # rather than hardcoding it.
  resolvedTarget =
    cfg: name:
    let
      user = cfg.home-manager.users.h82;
    in
    lib.strings.removePrefix "${user.home.homeDirectory}/" "${user.xdg.configHome}/${name}";

  entryFor =
    cfg: name:
    lib.lists.findFirst (f: (f.target or "") == resolvedTarget cfg name) null (
      lib.attrValues cfg.home-manager.users.h82.xdg.configFile
    );

  onePasswordEntry = entryFor host.config "autostart/1password.desktop";
  kleopatraEntryProd = entryFor host.config "autostart/kleopatra.desktop";
  bootstrapOnePassword = entryFor bootstrapHost.config "autostart/1password.desktop";
  bootstrapKleopatra = entryFor bootstrapHost.config "autostart/kleopatra.desktop";

  missing = name: ''
    echo 'no Home Manager autostart entry targets ${name} on the production host' >&2
    exit 1
  '';

  present =
    name: entry: execSuffix:
    lib.optionalString (entry != null) ''
      if [ "${builtins.toJSON (entry.enable or false)}" != "true" ]; then
        echo 'the autostart entry for ${name} is declared but not enabled' >&2
        exit 1
      fi
      if [ "${builtins.toJSON (entry.force or false)}" != "true" ]; then
        echo 'the autostart entry for ${name} does not set force, so activation would abort on the app-written file' >&2
        exit 1
      fi
      if ! grep -Fxq 'Type=Application' ${entry.source}; then
        echo 'the autostart entry for ${name} is missing Type=Application' >&2
        exit 1
      fi
      if ! grep -Fxq 'X-KDE-autostart-phase=2' ${entry.source}; then
        echo 'the autostart entry for ${name} is missing X-KDE-autostart-phase=2, so it would race the Plasma tray' >&2
        exit 1
      fi
      if ! grep -Fxq '${execSuffix}' ${entry.source}; then
        echo 'the autostart entry for ${name} does not run the expected command' >&2
        exit 1
      fi
    '';

  onePasswordExec = lib.optionalString (onePasswordEntry != null) (
    "Exec=${onePasswordPackage}/bin/1password --silent"
  );

  kleopatraExec = lib.optionalString (kleopatraEntryProd != null && kleopatraPackage != null) (
    "Exec=${kleopatraPackage}/bin/kleopatra --daemon"
  );

  kleopatraAbsent = lib.optionalString (kleopatraPackage == null) ''
    echo 'kleopatra is missing from the user package list, so its autostart command cannot be checked' >&2
    exit 1
  '';
in
pkgs.runCommand "desktop-autostart-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
  set -x

  # 1. The CLI module is enabled on both hosts.
  if [ "${builtins.toJSON hostCli}" != "true" ]; then
    echo 'programs._1password.enable is not true on ThinkPad-X1-Carbon-Gen-11' >&2
    exit 1
  fi
  if [ "${builtins.toJSON bootstrapCli}" != "true" ]; then
    echo 'programs._1password.enable is not true on ThinkPad-X1-Carbon-Gen-11-bootstrap' >&2
    exit 1
  fi

  # 2. The production host declares both autostart entries.
  ${lib.optionalString (onePasswordEntry == null) (missing "autostart/1password.desktop")}
  ${present "1Password" onePasswordEntry onePasswordExec}

  ${kleopatraAbsent}
  ${lib.optionalString (kleopatraEntryProd == null) (missing "autostart/kleopatra.desktop")}
  ${present "Kleopatra" kleopatraEntryProd kleopatraExec}

  # 3. The bootstrap host declares neither, so first-boot key recovery is not
  #    competing with a card-touching UI server.
  ${lib.optionalString (bootstrapOnePassword != null) ''
    echo 'the 1Password autostart entry leaked onto the bootstrap configuration' >&2
    exit 1
  ''}
  ${lib.optionalString (bootstrapKleopatra != null) ''
    echo 'the Kleopatra autostart entry leaked onto the bootstrap configuration' >&2
    exit 1
  ''}

  touch $out
''
