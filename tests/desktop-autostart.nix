/*
  Check interface:

    import ./tests/desktop-autostart.nix { inherit pkgs self; }

  Asserts that the 1Password CLI module is enabled on both ThinkPad
  configurations and that the login autostart entries, and the restart drop-ins
  for the chat clients, are declared on the production configuration only.

  Verifies:
  - programs._1password.enable is true on ThinkPad-X1-Carbon-Gen-11.
  - programs._1password.enable is true on ThinkPad-X1-Carbon-Gen-11-bootstrap.
  - The production Home Manager configuration declares an enabled, forced
    autostart entry targeting autostart/1password.desktop, whose Exec line runs
    the configured programs._1password-gui.package with --silent.
  - The same for autostart/kleopatra.desktop with --daemon,
    autostart/discord.desktop with --start-minimized, and
    autostart/telegram.desktop with -startintray, and
    autostart/proton-pass.desktop with no arguments, each running the package
    found in the user package list.
  - Every entry declares Type=Application and X-KDE-autostart-phase=2.
  - systemd/user/app-discord@autostart.service.d/restart.conf and the
    app-telegram equivalent are enabled and set Restart=on-failure and
    RestartSec=5s under [Service]. Those unit names are what
    systemd-xdg-autostart-generator derives from the two desktop file ids.
  - No full user unit named app-discord@autostart.service or
    app-telegram@autostart.service is declared, because it would shadow the
    generated unit, ExecStart included.
  - The bootstrap configuration declares none of these files.

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
  userPackage =
    pname:
    lib.lists.findFirst (
      p: (p.pname or "") == pname
    ) null host.config.home-manager.users.h82.home.packages;

  kleopatraPackage = userPackage "kleopatra";
  discordPackage = userPackage "discord";
  telegramPackage = userPackage "telegram-desktop";
  protonPassPackage = userPackage "proton-pass";

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
  kleopatraEntry = entryFor host.config "autostart/kleopatra.desktop";
  bootstrapOnePassword = entryFor bootstrapHost.config "autostart/1password.desktop";
  bootstrapKleopatra = entryFor bootstrapHost.config "autostart/kleopatra.desktop";
  discordEntry = entryFor host.config "autostart/discord.desktop";
  telegramEntry = entryFor host.config "autostart/telegram.desktop";
  protonPassEntry = entryFor host.config "autostart/proton-pass.desktop";

  apps = [
    "discord"
    "telegram"
  ];
  dropInName = app: "systemd/user/app-${app}@autostart.service.d/restart.conf";
  unitName = app: "systemd/user/app-${app}@autostart.service";

  bootstrapLeaks = lib.filter (name: entryFor bootstrapHost.config name != null) (
    [
      "autostart/discord.desktop"
      "autostart/telegram.desktop"
      "autostart/proton-pass.desktop"
    ]
    ++ map dropInName apps
  );

  dropInChecks = lib.concatMapStrings (
    app:
    let
      entry = entryFor host.config (dropInName app);
      unit = entryFor host.config (unitName app);
    in
    if entry == null then
      missing (dropInName app)
    else
      ''
        if [ "${builtins.toJSON (entry.enable or false)}" != "true" ]; then
          echo 'the restart drop-in for ${app} is declared but not enabled' >&2
          exit 1
        fi
        if [ "$(grep -v '^$' ${entry.source})" != "$(printf '[Service]\nRestart=on-failure\nRestartSec=5s')" ]; then
          echo 'the restart drop-in for ${app} does not set exactly Restart=on-failure and RestartSec=5s under [Service]' >&2
          exit 1
        fi
        ${lib.optionalString (unit != null) ''
          echo 'a full ${unitName app} unit is declared, which would shadow the generated autostart unit' >&2
          exit 1
        ''}
      ''
  ) apps;

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
      if ! grep -Fxq '[Desktop Entry]' ${entry.source}; then
        echo 'the autostart entry for ${name} has no [Desktop Entry] header, so the autostart scanner ignores it' >&2
        exit 1
      fi
      if ! grep -Fxq 'Type=Application' ${entry.source}; then
        echo 'the autostart entry for ${name} is missing Type=Application' >&2
        exit 1
      fi
      if ! grep -Fxq 'Hidden=false' ${entry.source}; then
        echo 'the autostart entry for ${name} is missing Hidden=false, which would leave it inert' >&2
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

  kleopatraExec = lib.optionalString (kleopatraEntry != null && kleopatraPackage != null) (
    "Exec=${kleopatraPackage}/bin/kleopatra --daemon"
  );

  discordExec = lib.optionalString (discordEntry != null && discordPackage != null) (
    "Exec=${discordPackage}/bin/discord --start-minimized"
  );

  telegramExec = lib.optionalString (telegramEntry != null && telegramPackage != null) (
    "Exec=${telegramPackage}/bin/Telegram -startintray"
  );

  protonPassExec = lib.optionalString (protonPassEntry != null && protonPassPackage != null) (
    "Exec=${protonPassPackage}/bin/proton-pass"
  );

  packageAbsent =
    pname: package:
    lib.optionalString (package == null) ''
      echo '${pname} is missing from the user package list, so its autostart command cannot be checked' >&2
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

  ${packageAbsent "kleopatra" kleopatraPackage}
  ${lib.optionalString (kleopatraEntry == null) (missing "autostart/kleopatra.desktop")}
  ${present "Kleopatra" kleopatraEntry kleopatraExec}

  ${packageAbsent "discord" discordPackage}
  ${lib.optionalString (discordEntry == null) (missing "autostart/discord.desktop")}
  ${present "Discord" discordEntry discordExec}

  ${packageAbsent "telegram-desktop" telegramPackage}
  ${lib.optionalString (telegramEntry == null) (missing "autostart/telegram.desktop")}
  ${present "Telegram" telegramEntry telegramExec}

  ${packageAbsent "proton-pass" protonPassPackage}
  ${lib.optionalString (protonPassEntry == null) (missing "autostart/proton-pass.desktop")}
  ${present "Proton Pass" protonPassEntry protonPassExec}

  # 3. The chat clients restart after a crash through drop-ins on the units
  #    systemd-xdg-autostart-generator creates, never through a full unit.
  ${dropInChecks}

  # 4. The bootstrap host declares none of them, so first-boot key recovery is not
  #    competing with a card-touching UI server.
  ${lib.optionalString (bootstrapOnePassword != null) ''
    echo 'the 1Password autostart entry leaked onto the bootstrap configuration' >&2
    exit 1
  ''}
  ${lib.optionalString (bootstrapKleopatra != null) ''
    echo 'the Kleopatra autostart entry leaked onto the bootstrap configuration' >&2
    exit 1
  ''}
  ${lib.concatMapStrings (name: ''
    echo '${name} leaked onto the bootstrap configuration' >&2
    exit 1
  '') bootstrapLeaks}

  touch $out
''
