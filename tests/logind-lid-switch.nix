/*
  Check interface:

    import ./tests/logind-lid-switch.nix { inherit pkgs self; }

  Asserts that ThinkPad-X1-Carbon-Gen-11 (production and bootstrap) render
  suspend-then-hibernate lid-switch behavior on both surfaces that can decide
  it -- systemd-logind (the fallback, consulted only when no Plasma session
  holds the handle-lid-switch inhibitor) and KDE Powerdevil (the mechanism
  actually in effect while a Plasma session is running) -- and that MS-7D91
  carries neither.

  Verifies:
  - ThinkPad-X1-Carbon-Gen-11 (production, bootstrap): environment.etc.
    "systemd/logind.conf" renders HandleLidSwitch=suspend-then-hibernate,
    HandleLidSwitchExternalPower=ignore, HandleLidSwitchDocked=ignore.
  - ThinkPad-X1-Carbon-Gen-11 (production, bootstrap): the kdePowerLid home
    activation script sets Battery/LowBattery LidAction=1 and SleepMode=3, AC
    LidAction=0, and InhibitLidActionWhenExternalMonitorPresent=true on all
    three profiles.
  - MS-7D91: environment.etc."systemd/logind.conf" carries none of the three
    Handle* keys, and no kdePowerLid activation entry exists at all.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  logindExpectedLines = [
    "HandleLidSwitch=suspend-then-hibernate"
    "HandleLidSwitchExternalPower=ignore"
    "HandleLidSwitchDocked=ignore"
  ];

  assertLogindHandled =
    hostName: host:
    let
      logindFile = pkgs.writeText "${hostName}-logind.conf" (
        host.config.environment.etc."systemd/logind.conf".text
      );
    in
    lib.concatMapStringsSep "\n" (line: ''
      if ! grep -Fxq -- '${line}' "${logindFile}"; then
        echo "${hostName}: logind.conf is missing expected line: ${line}" >&2
        exit 1
      fi
    '') logindExpectedLines;

  assertLogindUnaffected =
    hostName: host:
    let
      logindFile = pkgs.writeText "${hostName}-logind.conf" (
        host.config.environment.etc."systemd/logind.conf".text
      );
    in
    lib.concatMapStringsSep "\n" (line: ''
      if grep -Fxq -- '${line}' "${logindFile}"; then
        echo "${hostName}: logind.conf unexpectedly carries: ${line}" >&2
        exit 1
      fi
    '') logindExpectedLines;

  powerdevilExpectedLines = [
    "--group Battery --group SuspendAndShutdown --key LidAction -- 1"
    "--group Battery --group SuspendAndShutdown --key SleepMode -- 3"
    "--group LowBattery --group SuspendAndShutdown --key LidAction -- 1"
    "--group LowBattery --group SuspendAndShutdown --key SleepMode -- 3"
    "--group AC --group SuspendAndShutdown --key LidAction -- 0"
    "--group AC --group SuspendAndShutdown --key InhibitLidActionWhenExternalMonitorPresent --type bool true"
    "--group Battery --group SuspendAndShutdown --key InhibitLidActionWhenExternalMonitorPresent --type bool true"
    "--group LowBattery --group SuspendAndShutdown --key InhibitLidActionWhenExternalMonitorPresent --type bool true"
  ];

  assertPowerdevilHandled =
    hostName: host:
    let
      activationData = host.config.home-manager.users.h82.home.activation.kdePowerLid.data or null;
      scriptFile = pkgs.writeText "${hostName}-kde-power-lid.sh" (
        if activationData != null then activationData else ""
      );
    in
    ''
      if [ ! -s "${scriptFile}" ]; then
        echo "${hostName}: kdePowerLid activation script is missing or empty" >&2
        exit 1
      fi
      ${lib.concatMapStringsSep "\n" (line: ''
        if ! grep -Fq -- '${line}' "${scriptFile}"; then
          echo "${hostName}: kdePowerLid activation script is missing: ${line}" >&2
          exit 1
        fi
      '') powerdevilExpectedLines}
    '';

  assertPowerdevilAbsent =
    hostName: host:
    let
      activationData = host.config.home-manager.users.h82.home.activation.kdePowerLid.data or null;
    in
    lib.optionalString (activationData != null) ''
      echo "${hostName}: kdePowerLid activation entry unexpectedly exists" >&2
      exit 1
    '';
in
pkgs.runCommand "logind-lid-switch-tests"
  {
    nativeBuildInputs = [ pkgs.gnugrep ];
  }
  ''
    set -x

    ${assertLogindHandled "ThinkPad-X1-Carbon-Gen-11" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11}
    ${assertLogindHandled "ThinkPad-X1-Carbon-Gen-11-bootstrap" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap}
    ${assertLogindUnaffected "MS-7D91" self.nixosConfigurations.MS-7D91}

    ${assertPowerdevilHandled "ThinkPad-X1-Carbon-Gen-11" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11}
    ${assertPowerdevilHandled "ThinkPad-X1-Carbon-Gen-11-bootstrap" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap}
    ${assertPowerdevilAbsent "MS-7D91" self.nixosConfigurations.MS-7D91}

    touch $out
  ''
