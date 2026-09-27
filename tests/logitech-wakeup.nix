/*
  Check interface:

    import ./tests/logitech-wakeup.nix { inherit pkgs self; }

  Asserts that the merged `services.udev.extraRules` value contains the udev
  rule that disables USB remote wakeup for the Logitech Unifying and Logi Bolt
  wireless receivers.

  Verifies:
  - every configuration `tests/lib/configurations.nix` yields, production and
    bootstrap alike, declares the exact rule line.

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
      extraRules = entry.config.services.udev.extraRules;
      rulesFile = pkgs.writeText "${entry.name}-udev-extra-rules" extraRules;
    in
    ''
      if ! grep -Fq -- '${expectedRule}' "${rulesFile}"; then
        echo "Logitech wakeup-disable udev rule is missing from services.udev.extraRules on ${entry.name}" >&2
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
