/*
  Check interface:

    import ./tests/logitech-wakeup.nix { inherit pkgs self; }

  Asserts that the materialized udev rules directory contains the udev
  rule that disables USB remote wakeup for the Logitech Unifying and Logi Bolt
  wireless receivers.

  Verifies:
  - every configuration `tests/lib/configurations.nix` yields, production and
    bootstrap alike, installs the exact uncommented rule line at the path
    udev consumes. Disabled or retargeted declarations do not count.

  The builder collects every failure before it exits, so one red build names
  every affected configuration.
*/
{ pkgs, self }:
let
  configurations = import ./lib/configurations.nix { inherit pkgs self; };

  expectedRule = ''ACTION=="add", SUBSYSTEM=="usb", DRIVERS=="usb", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c52b|c548", ATTR{power/wakeup}="disabled"'';

  assertEntry =
    entry:
    let
      rules = "${entry.config.system.build.etc}/etc/udev/rules.d";
    in
    ''
      ruleFound=0
      for ruleFile in ${pkgs.lib.escapeShellArg rules}/*.rules; do
        if [ -f "$ruleFile" ] && grep -Fxq -- '${expectedRule}' "$ruleFile"; then
          ruleFound=1
        fi
      done
      if [ "$ruleFound" = 0 ]; then
        echo "Logitech wakeup-disable rule is missing from the installed udev rules on ${entry.name}" >&2
        failed=1
      fi
    '';
in
pkgs.runCommand "logitech-wakeup-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
  set -x
  ${configurations.guard}
  failed=0

  ${pkgs.lib.concatMapStringsSep "\n" assertEntry configurations.entries}

  if [ "$failed" != 0 ]; then
    exit 1
  fi
  touch $out
''
