/*
  Check interface:

    import ./tests/winbox.nix { inherit pkgs self; }

  Asserts what modules/nixos/desktop/winbox.nix produces on every
  configuration `tests/lib/configurations.nix` yields, production and
  bootstrap alike. Every assertion reads something the built system carries
  -- the system path and the firewall start script -- never the options the
  module sets.

  Verifies, per configuration:
  - the system path carries bin/WinBox and share/applications/winbox.desktop.
  - the firewall start script accepts UDP 5678 (MikroTik Neighbor Discovery),
    UDP 20561 (MAC-address connections), and the UDP range 40000:50000.

  The builder collects every failure before it exits, so one red build names
  every affected configuration.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self; };

  esc = value: lib.escapeShellArg (toString value);

  fail = message: ''
    echo ${esc message} >&2
    failed=1
  '';

  # An /etc entry that is disabled or retargeted is not materialised at its
  # path, so it counts as missing even though its source still evaluates.
  units =
    config:
    let
      entry = config.environment.etc."systemd/system" or null;
    in
    if
      entry == null || !(entry.enable or true) || (entry.target or "systemd/system") != "systemd/system"
    then
      null
    else
      entry.source;

  ports = [
    "5678"
    "20561"
    "40000:50000"
  ];

  checkHost =
    entry:
    let
      inherit (entry) config name;
      path = config.system.path;
      tree = units config;
    in
    ''
      if [ ! -x ${esc "${path}/bin/WinBox"} ]; then
        ${fail "${name}: the system path carries no executable bin/WinBox"}
      fi
      if [ ! -f ${esc "${path}/share/applications/winbox.desktop"} ]; then
        ${fail "${name}: the system path carries no share/applications/winbox.desktop"}
      fi
      ${
        if tree == null then
          fail "${name}: the built system declares no /etc/systemd/system tree"
        else
          ''
            firewall=$(sed -n 's/^ExecStart=@\([^ ]*\) .*/\1/p' ${esc "${tree}/firewall.service"})
            if [ -z "$firewall" ]; then
              ${fail "${name}: firewall.service is missing, masked, or runs no start script"}
              firewall=/dev/null
            fi
            ${lib.concatMapStrings (port: ''
              if ! grep -q -- ${esc "-p udp --dport ${port} -j nixos-fw-accept"} "$firewall"; then
                ${fail "${name}: the firewall start script does not accept UDP ${port} for WinBox"}
              fi
            '') ports}
          ''
      }
    '';
in
pkgs.runCommand "winbox-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
  set -x
  ${configurations.guard}
  failed=0

  ${lib.concatMapStringsSep "\n" checkHost configurations.entries}

  if [ "$failed" != 0 ]; then
    exit 1
  fi
  touch $out
''
