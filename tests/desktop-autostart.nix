/*
  Check interface:

    import ./tests/desktop-autostart.nix { inherit pkgs self; }

  Asserts, on every configuration `tests/lib/configurations.nix` yields, that
  the 1Password CLI module is enabled, and that the login autostart entries and
  the restart drop-ins for the chat clients are declared on production
  configurations only. The split is taken from each configuration's
  `my.bootstrap`, not from any option the autostart module sets.

  Verifies:
  - programs._1password.enable is true on every configuration.
  - Each production configuration's Home Manager user declares an enabled,
    forced autostart entry targeting autostart/1password.desktop, whose Exec
    line runs that configuration's programs._1password-gui.package with
    --silent.
  - The same for autostart/kleopatra.desktop with --daemon,
    autostart/discord.desktop with --start-minimized, and
    autostart/telegram.desktop with -startintray, each running the package
    found in that configuration's user package list.
  - Every entry declares Type=Application and X-KDE-autostart-phase=2.
  - systemd/user/app-discord@autostart.service.d/restart.conf and the
    app-telegram equivalent are enabled and set Restart=on-failure and
    RestartSec=5s under [Service]. Those unit names are what
    systemd-xdg-autostart-generator derives from the two desktop file ids.
  - No full user unit named app-discord@autostart.service or
    app-telegram@autostart.service is declared, because it would shadow the
    generated unit, ExecStart included.
  - Every bootstrap configuration declares none of these files.

  The entries are located by their resolved target rather than by attribute
  name, and their enable and force flags are read beside their text, because an
  entry can be disabled or retargeted while its text still evaluates. Every
  store-path interpolation sits inside an optionalString guard so a removal
  mutation fails inside the builder rather than aborting evaluation. The
  builder collects every failure before it exits, so one red build names every
  affected configuration.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self; };

  fail = message: ''
    echo ${lib.escapeShellArg message} >&2
    failed=1
  '';

  # Resolve by target, not by attribute name: target merely defaults to the name.
  # Home Manager's target apply expands a relative path against xdg.configHome
  # and then strips the home prefix, so derive the resolved form the same way
  # rather than hardcoding it.
  resolvedTarget =
    user: name:
    lib.strings.removePrefix "${user.home.homeDirectory or ""}/" "${user.xdg.configHome or ""}/${name}";

  entryFor =
    user: name:
    lib.lists.findFirst (f: (f.target or "") == resolvedTarget user name) null (
      lib.attrValues (user.xdg.configFile or { })
    );

  apps = [
    "discord"
    "telegram"
  ];
  dropInName = app: "systemd/user/app-${app}@autostart.service.d/restart.conf";
  unitName = app: "systemd/user/app-${app}@autostart.service";

  autostartNames = [
    "autostart/1password.desktop"
    "autostart/kleopatra.desktop"
    "autostart/discord.desktop"
    "autostart/telegram.desktop"
  ];

  assertCli = entry: ''
    if [ "${builtins.toJSON (entry.config.programs._1password.enable or false)}" != "true" ]; then
      ${fail "programs._1password.enable is not true on ${entry.name}"}
    fi
  '';

  assertProduction =
    entry:
    let
      inherit (entry) user;
      host = entry.name;

      userPackage =
        pname: lib.lists.findFirst (p: (p.pname or "") == pname) null (user.home.packages or [ ]);

      onePasswordPackage = entry.config.programs._1password-gui.package or null;
      kleopatraPackage = userPackage "kleopatra";
      discordPackage = userPackage "discord";
      telegramPackage = userPackage "telegram-desktop";

      onePasswordEntry = entryFor user "autostart/1password.desktop";
      kleopatraEntry = entryFor user "autostart/kleopatra.desktop";
      discordEntry = entryFor user "autostart/discord.desktop";
      telegramEntry = entryFor user "autostart/telegram.desktop";

      missing = name: fail "no Home Manager autostart entry targets ${name} on ${host}";

      present =
        name: entry: execSuffix:
        lib.optionalString (entry != null) ''
          if [ "${builtins.toJSON (entry.enable or false)}" != "true" ]; then
            ${fail "the autostart entry for ${name} is declared but not enabled on ${host}"}
          fi
          if [ "${builtins.toJSON (entry.force or false)}" != "true" ]; then
            ${fail "the autostart entry for ${name} does not set force on ${host}, so activation would abort on the app-written file"}
          fi
          if ! grep -Fxq '[Desktop Entry]' ${entry.source}; then
            ${fail "the autostart entry for ${name} has no [Desktop Entry] header on ${host}, so the autostart scanner ignores it"}
          fi
          if ! grep -Fxq 'Type=Application' ${entry.source}; then
            ${fail "the autostart entry for ${name} is missing Type=Application on ${host}"}
          fi
          if ! grep -Fxq 'Hidden=false' ${entry.source}; then
            ${fail "the autostart entry for ${name} is missing Hidden=false on ${host}, which would leave it inert"}
          fi
          if ! grep -Fxq 'X-KDE-autostart-phase=2' ${entry.source}; then
            ${fail "the autostart entry for ${name} is missing X-KDE-autostart-phase=2 on ${host}, so it would race the Plasma tray"}
          fi
          if ! grep -Fxq ${lib.escapeShellArg execSuffix} ${entry.source}; then
            ${fail "the autostart entry for ${name} does not run the expected command on ${host}"}
          fi
        '';

      packageAbsent =
        pname: package:
        lib.optionalString (package == null) (
          fail "${pname} is missing from the user package list on ${host}, so its autostart command cannot be checked"
        );

      onePasswordExec = lib.optionalString (onePasswordEntry != null && onePasswordPackage != null) (
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

      dropInChecks = lib.concatMapStrings (
        app:
        let
          dropIn = entryFor user (dropInName app);
          unit = entryFor user (unitName app);
        in
        (
          if dropIn == null then
            missing (dropInName app)
          else
            ''
              if [ "${builtins.toJSON (dropIn.enable or false)}" != "true" ]; then
                ${fail "the restart drop-in for ${app} is declared but not enabled on ${host}"}
              fi
              if [ "$(grep -v '^$' ${dropIn.source})" != "$(printf '[Service]\nRestart=on-failure\nRestartSec=5s')" ]; then
                ${fail "the restart drop-in for ${app} does not set exactly Restart=on-failure and RestartSec=5s under [Service] on ${host}"}
              fi
            ''
        )
        + lib.optionalString (unit != null) (
          fail "a full ${unitName app} unit is declared on ${host}, which would shadow the generated autostart unit"
        )
      ) apps;
    in
    ''
      ${lib.optionalString (onePasswordPackage == null) (
        fail "programs._1password-gui.package is unset on ${host}, so the 1Password autostart command cannot be checked"
      )}
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

      # The chat clients restart after a crash through drop-ins on the units
      # systemd-xdg-autostart-generator creates, never through a full unit.
      ${dropInChecks}
    '';

  # A bootstrap configuration declares none of them, so first-boot key recovery
  # is not competing with a card-touching UI server.
  assertBootstrap =
    entry:
    lib.concatMapStrings (name: fail "${name} leaked onto the bootstrap configuration ${entry.name}") (
      lib.filter (name: entryFor entry.user name != null) (autostartNames ++ map dropInName apps)
    );
in
pkgs.runCommand "desktop-autostart-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
  set -x
  ${configurations.guard}
  failed=0

  ${lib.concatMapStringsSep "\n" assertCli configurations.entries}
  ${lib.concatMapStringsSep "\n" assertProduction configurations.production}
  ${lib.concatMapStringsSep "\n" assertBootstrap configurations.bootstraps}

  if [ "$failed" != 0 ]; then
    exit 1
  fi
  touch $out
''
