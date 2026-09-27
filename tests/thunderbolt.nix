/*
  Check interface:

    import ./tests/thunderbolt.nix { inherit pkgs self; }

  Asserts what modules/nixos/hardware/thunderbolt.nix produces on every
  configuration `tests/lib/configurations.nix` yields, with the expectation
  taken from each configuration's `my.thunderbolt.enable` trait rather than from
  services.hardware.bolt.enable, the option the module under test sets. Every
  assertion reads something activation produces -- the materialised systemd
  unit tree, the materialised udev rules directory, the system path. plasma6.nix
  adds plasma-thunderbolt only when bolt is enabled, so the Plasma module is
  asserted on its own: an option read would stay green if an overlay swapped
  the package out.

  On a configuration that enables the trait:
  - the materialised systemd unit tree carries a bolt.service that runs boltd,
    so a unit masked to /dev/null fails.
  - some file in the materialised udev rules directory carries bolt's rule that
    starts bolt.service when a Thunderbolt device appears, verbatim. Without it
    nothing starts the daemon, since bolt.service has no [Install] section.
  - the system path carries bin/boltctl.
  - the system path carries the kcm_bolt settings module and its desktop entry.

  On a configuration that leaves the trait off: no bolt.service runs boltd, no
  udev rules file carries bolt's start rule, and the system path ships neither
  bin/boltctl nor the kcm_bolt settings module or its desktop entry.

  At least one production configuration must enable the trait, or the helper
  fails the check, so the positive branch never covers zero configurations.

  It cannot see whether a real device gets authorized; docs/verification.md
  covers that on hardware.

  Every /etc lookup carries an `or null` fallback and store paths are
  interpolated only inside the present branch, so a missing entry fails inside
  the builder rather than during evaluation. The builder collects every failure
  instead of exiting at the first, so one red build names every affected
  configuration.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self; };
  thunderbolt = configurations.withTrait "my.thunderbolt.enable" (
    config: config.my.thunderbolt.enable
  );

  # Every message and path below is text spliced into a shell script, so it is
  # escaped rather than trusted to be quote-free.
  esc = value: lib.escapeShellArg (toString value);

  fail = message: ''
    echo ${esc message} >&2
    failed=1
  '';

  # `root` may be null: an absent /etc entry is resolved with `or null` so the
  # failure is reported inside the builder instead of aborting evaluation.
  assertPath =
    {
      flag,
      root,
      path,
      message,
      absentMessage ? message,
    }:
    if root == null then
      fail absentMessage
    else
      ''
        if [ ! ${flag} ${esc "${root}/${path}"} ]; then
          ${fail message}
        fi
      '';

  boltRule = ''SUBSYSTEM=="thunderbolt", TAG+="systemd", ENV{SYSTEMD_WANTS}+="bolt.service"'';

  # The system-path files bolt and its Plasma settings module ship.
  systemPathFiles = [
    {
      flag = "-x";
      path = "bin/boltctl";
      what = "bin/boltctl";
    }
    {
      flag = "-f";
      path = "lib/qt-6/plugins/plasma/kcms/systemsettings/kcm_bolt.so";
      what = "Plasma Thunderbolt settings module (kcm_bolt.so)";
    }
    {
      flag = "-f";
      path = "share/applications/kcm_bolt.desktop";
      what = "Plasma Thunderbolt desktop entry (kcm_bolt.desktop)";
    }
  ];

  units = config: config.environment.etc."systemd/system".source or null;
  udevRules = config: config.environment.etc."udev/rules.d".source or null;

  assertEnabled =
    entry:
    let
      unitTree = units entry.config;
      rules = udevRules entry.config;
      systemPath = entry.config.system.path;
    in
    lib.concatStringsSep "\n" (
      [
        # Read the unit's content, not its existence: a disabled unit is still
        # present in the tree as a symlink to /dev/null.
        (
          if unitTree == null then
            fail "${entry.name}: the built system declares no /etc/systemd/system tree"
          else
            ''
              if ! grep -q '^ExecStart=.*/libexec/boltd$' ${esc "${unitTree}/bolt.service"}; then
                ${fail "${entry.name}: my.thunderbolt.enable is set but the materialised bolt.service is missing, masked, or does not run boltd"}
              fi
            ''
        )
        (
          if rules == null then
            fail "${entry.name}: the built system declares no /etc/udev/rules.d directory"
          else
            ''
              if ! grep -qFx -- ${esc boltRule} ${esc rules}/*.rules; then
                ${fail "${entry.name}: no udev rules file carries bolt's start rule: ${boltRule}"}
              fi
            ''
        )
      ]
      ++ map (
        file:
        assertPath {
          inherit (file) flag path;
          root = systemPath;
          message = "${entry.name}: the system path ships no ${file.what}";
        }
      ) systemPathFiles
    );

  assertDisabled =
    entry:
    let
      unitTree = units entry.config;
      rules = udevRules entry.config;
      systemPath = entry.config.system.path;
    in
    lib.concatStringsSep "\n" (
      [
        (lib.optionalString (unitTree != null) ''
          if grep -qs '^ExecStart=.*/libexec/boltd$' ${esc "${unitTree}/bolt.service"}; then
            ${fail "${entry.name}: my.thunderbolt.enable is off but the materialised bolt.service runs boltd"}
          fi
        '')
        (lib.optionalString (rules != null) ''
          if grep -qsFx -- ${esc boltRule} ${esc rules}/*.rules; then
            ${fail "${entry.name}: my.thunderbolt.enable is off but a udev rules file carries bolt's start rule"}
          fi
        '')
      ]
      ++ map (file: ''
        if [ -e ${esc "${systemPath}/${file.path}"} ]; then
          ${fail "${entry.name}: my.thunderbolt.enable is off but the system path ships ${file.what}"}
        fi
      '') systemPathFiles
    );
in
pkgs.runCommand "thunderbolt-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
  set -x
  ${configurations.guard}
  ${thunderbolt.guard}
  failed=0

  ${lib.concatMapStringsSep "\n" assertEnabled thunderbolt.enabled}
  ${lib.concatMapStringsSep "\n" assertDisabled thunderbolt.disabled}

  if [ "$failed" != 0 ]; then
    exit 1
  fi
  touch $out
''
