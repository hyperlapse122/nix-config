/*
  Check interface:

    import ./tests/udev-device-access.nix { inherit pkgs self; }

  Asserts that the udev rules each host actually builds carry the device-access
  rules for the NuPhy Gem80 keyboard, the STM32 ROM DFU bootloader, and the
  Sennheiser BTD 600/700 dongles. Every assertion reads the materialised rules
  directory (`environment.etc."udev/rules.d"`), never the option lists it is
  derived from. `services.udev.extraRules` lands in 99-local.rules while
  `services.udev.packages` files keep their own names, so the option value
  cannot say which file a rule ends up in. That decides whether the rule does
  anything, because udev applies the files in byte order of their names:
  - systemd's 73-seat-late.rules queues the uaccess builtin only for devices
    already tagged when it is evaluated, so a `uaccess` tag added by a later
    file passes every check that reads an option and grants no access on real
    hardware.
  - `MODE` is decided by the last assignment, and systemd's 50-udev-default.rules
    sets 0664 on every USB device node, so a `MODE` rule in an earlier file
    loses to it.

  Files are compared by name in byte order (LC_ALL=C sort), the order udev uses,
  never by a parsed numeric prefix: a 9- prefix sorts after 73-, and 060- sorts
  before it.

  Verifies:
  - all four host configurations carry each Sennheiser BTD rule line verbatim,
    each in a file that sorts after the last file carrying the USB default.
  - all four carry a file with the uaccess builtin and a file with the USB
    default. They supply the two anchors above and are the positive controls
    that stop an empty directory passing.
  - MS-7D91 and MS-7D91-bootstrap carry both NuPhy rule lines verbatim, each in
    a file that sorts before the first file carrying the uaccess builtin. An
    absent anchor fails the ordering assertion instead of skipping it.
  - neither ThinkPad configuration carries either NuPhy rule line. The
    assertion is an explicit `if`, because a bare `! grep` is exempt from
    `set -e`.

  The builder collects every failure instead of exiting at the first, so one red
  build names every broken assertion across the four hosts.
*/
{ pkgs, self }:
let
  inherit (pkgs.lib) boolToString escapeShellArg escapeShellArgs;

  # Every rule below is text spliced into a shell script, so it is escaped
  # rather than trusted to be quote-free.
  esc = value: escapeShellArg (toString value);

  nuphyRules = [
    ''KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="19f5", ATTRS{idProduct}=="3275", TAG+="uaccess"''
    ''SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="df11", TAG+="uaccess"''
  ];

  btdRules = [
    ''SUBSYSTEM=="usb", ATTR{idVendor}=="3542", ATTR{idProduct}=="3000", MODE="0666"''
    ''SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3542", ATTRS{idProduct}=="3000", MODE="0666"''
    ''SUBSYSTEM=="usb", ATTR{idVendor}=="3542", ATTR{idProduct}=="3001", MODE="0666"''
    ''SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3542", ATTRS{idProduct}=="3001", MODE="0666"''
  ];

  builtinLine = ''RUN{builtin}+="uaccess"'';
  usbDefaultLine = ''SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", MODE="0664"'';

  helpers = ''
    failed=0
    fail() {
      echo "$1" >&2
      failed=1
    }

    # Every rules file in $1 that carries the whole line $2.
    files_with_line() {
      grep -lFx -- "$2" "$1"/*.rules
    }

    # Whether rules file name $1 sorts strictly before $2 in byte order.
    sorts_before() {
      [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | LC_ALL=C sort | head -n 1)" = "$1" ]
    }

    # The name of the first or last (by $3) rules file in $1 that carries the
    # fixed string $2, or nothing when no file does.
    edge_file_with() {
      edge=""
      for file in $(grep -lF -- "$2" "$1"/*.rules); do
        name=$(basename "$file")
        if [ -z "$edge" ]; then
          edge=$name
        elif [ "$3" = first ] && sorts_before "$name" "$edge"; then
          edge=$name
        elif [ "$3" = last ] && sorts_before "$edge" "$name"; then
          edge=$name
        fi
      done
      echo "$edge"
    }

    # $1 host, $2 rules directory, $3 the rules file the rule is ordered
    # against, $4 rule line, $5 before or after. The rule passes only when some
    # file carrying it sorts on that side of a present anchor.
    check_rule_order() {
      found=0
      ordered=0
      for file in $(files_with_line "$2" "$4"); do
        found=1
        name=$(basename "$file")
        if [ -n "$3" ] && [ "$5" = before ] && sorts_before "$name" "$3"; then
          ordered=1
        fi
        if [ -n "$3" ] && [ "$5" = after ] && sorts_before "$3" "$name"; then
          ordered=1
        fi
      done
      if [ "$found" = 0 ]; then
        fail "$1: no udev rules file carries: $4"
      elif [ "$ordered" = 0 ]; then
        fail "$1: the rule sits in no file applied $5 $3, so it does not take effect: $4"
      fi
    }

    # $1 host, $2 rules directory, $3 true when the NuPhy rules belong there.
    check_host() {
      host=$1
      dir=$2
      nuphy_belongs=$3
      builtin_file=$(edge_file_with "$dir" ${esc builtinLine} first)
      usb_default_file=$(edge_file_with "$dir" ${esc usbDefaultLine} last)
      if [ -z "$builtin_file" ]; then
        fail "$host: no rules file carries the uaccess builtin"
      fi
      if [ -z "$usb_default_file" ]; then
        fail "$host: no rules file carries systemd's default MODE for USB device nodes"
      fi
      for line in ${escapeShellArgs btdRules}; do
        check_rule_order "$host" "$dir" "$usb_default_file" "$line" after
      done
      if [ "$nuphy_belongs" = true ]; then
        for line in ${escapeShellArgs nuphyRules}; do
          check_rule_order "$host" "$dir" "$builtin_file" "$line" before
        done
      else
        for line in ${escapeShellArgs nuphyRules}; do
          if [ -n "$(files_with_line "$dir" "$line")" ]; then
            fail "$host: a NuPhy rule reaches a configuration it does not belong to: $line"
          fi
        done
      fi
    }
  '';

  hostAssertion = hostName: host: nuphyBelongs: ''
    check_host ${esc hostName} ${
      esc host.config.environment.etc."udev/rules.d".source
    } ${boolToString nuphyBelongs}
  '';
in
pkgs.runCommand "udev-device-access-tests" { } ''
  ${helpers}

  ${hostAssertion "ThinkPad-X1-Carbon-Gen-11" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11
    false
  }
  ${hostAssertion "ThinkPad-X1-Carbon-Gen-11-bootstrap"
    self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap
    false
  }
  ${hostAssertion "MS-7D91" self.nixosConfigurations.MS-7D91 true}
  ${hostAssertion "MS-7D91-bootstrap" self.nixosConfigurations.MS-7D91-bootstrap true}

  if [ "$failed" != 0 ]; then
    exit 1
  fi
  touch $out
''
