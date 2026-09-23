/*
  Check interface:

    import ./tests/logitech-wakeup.nix { inherit pkgs self; }

  Asserts that the merged `services.udev.extraRules` value on every host
  configuration contains the udev rule that disables USB remote wakeup for
  the Logitech Unifying and Logi Bolt wireless receivers.

  Verifies:
  - ThinkPad-X1-Carbon-Gen-11, ThinkPad-X1-Carbon-Gen-11-bootstrap, MS-7D91,
    and MS-7D91-bootstrap all declare the exact rule line.
*/
{ pkgs, self }:
let
  expectedRule = ''ACTION=="add", SUBSYSTEM=="usb", DRIVERS=="usb", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c52b|c548", ATTR{power/wakeup}="disabled"'';

  assertHost =
    hostName: host:
    let
      extraRules = host.config.services.udev.extraRules;
      rulesFile = pkgs.writeText "${hostName}-udev-extra-rules" extraRules;
    in
    ''
      if ! grep -Fq -- '${expectedRule}' "${rulesFile}"; then
        echo "Logitech wakeup-disable udev rule is missing from services.udev.extraRules on ${hostName}" >&2
        exit 1
      fi
    '';
in
pkgs.runCommand "logitech-wakeup-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
  set -x

  ${assertHost "ThinkPad-X1-Carbon-Gen-11" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11}
  ${assertHost "ThinkPad-X1-Carbon-Gen-11-bootstrap" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap}
  ${assertHost "MS-7D91" self.nixosConfigurations.MS-7D91}
  ${assertHost "MS-7D91-bootstrap" self.nixosConfigurations.MS-7D91-bootstrap}

  touch $out
''
