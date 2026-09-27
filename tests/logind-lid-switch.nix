/*
  Check interface:

    import ./tests/logind-lid-switch.nix { inherit pkgs self; }

  Asserts the lid-switch policy on both surfaces that can decide it --
  systemd-logind (the fallback, consulted only when no Plasma session holds the
  handle-lid-switch inhibitor) and KDE Powerdevil (the mechanism actually in
  effect while a Plasma session is running) -- on every configuration
  `tests/lib/configurations.nix` yields, production and bootstrap alike. The
  expectation is taken from each configuration's `my.laptop.enable` trait, never
  from `services.logind.settings` or `home.activation`, the options the modules
  under test set.

  On a configuration that enables the trait:
  - the materialised /etc/systemd/logind.conf renders
    HandleLidSwitch=suspend-then-hibernate, HandleLidSwitchExternalPower=ignore
    and HandleLidSwitchDocked=ignore.
  - the h82 kdePowerLid Home Manager activation script sets Battery/LowBattery
    LidAction=1 and SleepMode=3, AC LidAction=0, and
    InhibitLidActionWhenExternalMonitorPresent=true on all three profiles.

  On a configuration that leaves the trait off:
  - the materialised /etc/systemd/logind.conf carries none of the three
    Handle* lines.
  - no kdePowerLid activation entry exists at all.

  At least one production configuration must enable the trait, or the helper
  fails the check, so the positive branch never covers zero configurations.

  Every lookup carries an `or null` fallback and store paths are interpolated
  only inside the present branch, so a missing entry fails inside the builder
  rather than during evaluation. The builder collects every failure before it
  exits, so one red build names every affected configuration.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self; };
  laptop = configurations.withTrait "my.laptop.enable" (config: config.my.laptop.enable);

  esc = value: lib.escapeShellArg (toString value);

  fail = message: ''
    echo ${esc message} >&2
    failed=1
  '';

  logindExpectedLines = [
    "HandleLidSwitch=suspend-then-hibernate"
    "HandleLidSwitchExternalPower=ignore"
    "HandleLidSwitchDocked=ignore"
  ];

  powerdevilExpectedLines = [
    "--file powerdevilrc --group Battery --group SuspendAndShutdown --key LidAction -- 1"
    "--file powerdevilrc --group Battery --group SuspendAndShutdown --key SleepMode -- 3"
    "--file powerdevilrc --group LowBattery --group SuspendAndShutdown --key LidAction -- 1"
    "--file powerdevilrc --group LowBattery --group SuspendAndShutdown --key SleepMode -- 3"
    "--file powerdevilrc --group AC --group SuspendAndShutdown --key LidAction -- 0"
    "--file powerdevilrc --group AC --group SuspendAndShutdown --key InhibitLidActionWhenExternalMonitorPresent --type bool true"
    "--file powerdevilrc --group Battery --group SuspendAndShutdown --key InhibitLidActionWhenExternalMonitorPresent --type bool true"
    "--file powerdevilrc --group LowBattery --group SuspendAndShutdown --key InhibitLidActionWhenExternalMonitorPresent --type bool true"
  ];

  # The file the etc module materialises, honouring the entry's `enable`: a
  # disabled entry keeps its source but never reaches /etc.
  logindConf =
    config:
    let
      entry = config.environment.etc."systemd/logind.conf" or null;
    in
    if entry != null && (entry.enable or false) then entry.source or null else null;

  powerLidData = entry: entry.user.home.activation.kdePowerLid.data or null;

  assertEnabled =
    entry:
    let
      conf = logindConf entry.config;
      activationData = powerLidData entry;
      scriptFile = pkgs.writeText "${entry.name}-kde-power-lid.sh" (
        if activationData != null then activationData else ""
      );
    in
    lib.concatStringsSep "\n" [
      (
        if conf == null then
          fail "${entry.name}: my.laptop.enable is set but no /etc/systemd/logind.conf is materialised"
        else
          lib.concatMapStringsSep "\n" (line: ''
            if ! grep -Fxq -- ${esc line} ${esc conf}; then
              ${fail "${entry.name}: my.laptop.enable is set but logind.conf is missing: ${line}"}
            fi
          '') logindExpectedLines
      )
      (
        if activationData == null then
          fail "${entry.name}: my.laptop.enable is set but no kdePowerLid activation entry exists"
        else
          ''
            if [ ! -s ${esc scriptFile} ]; then
              ${fail "${entry.name}: the kdePowerLid activation script is empty"}
            fi
            ${lib.concatMapStringsSep "\n" (line: ''
              if ! grep -Fq -- ${esc line} ${esc scriptFile}; then
                ${fail "${entry.name}: the kdePowerLid activation script is missing: ${line}"}
              fi
            '') powerdevilExpectedLines}
          ''
      )
    ];

  assertDisabled =
    entry:
    let
      conf = logindConf entry.config;
    in
    lib.concatStringsSep "\n" [
      (lib.optionalString (conf != null) (
        lib.concatMapStringsSep "\n" (line: ''
          if grep -Fxq -- ${esc line} ${esc conf}; then
            ${fail "${entry.name}: my.laptop.enable is off but logind.conf carries: ${line}"}
          fi
        '') logindExpectedLines
      ))
      (lib.optionalString (powerLidData entry != null) (
        fail "${entry.name}: my.laptop.enable is off but a kdePowerLid activation entry exists"
      ))
    ];
in
pkgs.runCommand "logind-lid-switch-tests"
  {
    nativeBuildInputs = [ pkgs.gnugrep ];
  }
  ''
    set -x
    ${configurations.guard}
    ${laptop.guard}
    failed=0

    ${lib.concatMapStringsSep "\n" assertEnabled laptop.enabled}
    ${lib.concatMapStringsSep "\n" assertDisabled laptop.disabled}

    if [ "$failed" != 0 ]; then
      exit 1
    fi
    touch $out
  ''
