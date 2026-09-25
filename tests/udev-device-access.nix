/*
  Check interface:

    import ./tests/udev-device-access.nix { inherit pkgs self; }

  Asserts that the udev rules each host actually builds carry the device-access
  rules for the NuPhy Gem80 keyboard, the STM32 ROM DFU bootloader, and the
  Sennheiser BTD 600/700 dongles. Every assertion reads the materialised rules
  directory (`environment.etc."udev/rules.d"`), never the option lists it is
  derived from. `services.udev.extraRules` lands in 99-local.rules while
  `services.udev.packages` files keep their own names, so the option value
  cannot say which file a rule ends up in. That decides whether a `uaccess` tag
  does anything: systemd's 73-seat-late.rules queues the uaccess builtin only
  for devices already tagged when it is evaluated, so a tag added later passes
  every check that reads an option and grants no access on real hardware.

  Verifies:
  - all four host configurations carry each Sennheiser BTD rule line verbatim,
    and carry a file with the uaccess builtin, which supplies the ordering bound
    below.
  - MS-7D91 and MS-7D91-bootstrap carry both NuPhy rule lines verbatim, each in
    a file whose numeric prefix is strictly below that bound. The comparison
    passes only on two numeric operands, so a file with no numeric prefix, or a
    directory with no uaccess-builtin file, fails instead of skipping it.
  - neither ThinkPad configuration carries either NuPhy rule line. The
    assertion is an explicit `if`, because a bare `! grep` is exempt from
    `set -e`, and the uaccess-builtin requirement above is its positive control
    against passing on an empty directory.

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

    # The numeric prefix of a rules file name, or a failure when it has none.
    numeric_prefix() {
      prefix=$(basename "$1" | cut -d- -f1)
      case "$prefix" in
        "" | *[!0-9]*) return 1 ;;
      esac
      echo "$((10#$prefix))"
    }

    # The lowest numeric prefix among the files in $1 that run the uaccess
    # builtin, or nothing when no numbered file does.
    lowest_builtin_prefix() {
      lowest=""
      for file in $(grep -lF -- ${esc builtinLine} "$1"/*.rules); do
        if number=$(numeric_prefix "$file"); then
          if [ -z "$lowest" ] || [ "$number" -lt "$lowest" ]; then
            lowest=$number
          fi
        fi
      done
      echo "$lowest"
    }

    # $1 host, $2 rules directory, $3 ordering bound, $4 rule line.
    check_uaccess_rule() {
      found=0
      ordered=0
      for file in $(files_with_line "$2" "$4"); do
        found=1
        if number=$(numeric_prefix "$file") && [ -n "$3" ] && [ "$number" -lt "$3" ]; then
          ordered=1
        fi
      done
      if [ "$found" = 0 ]; then
        fail "$1: no udev rules file carries: $4"
      elif [ "$ordered" = 0 ]; then
        fail "$1: the rule sits in no file applied before the uaccess builtin (prefix $3), so its tag grants nothing: $4"
      fi
    }

    # $1 host, $2 rules directory, $3 true when the NuPhy rules belong there.
    check_host() {
      host=$1
      dir=$2
      nuphy_belongs=$3
      bound=$(lowest_builtin_prefix "$dir")
      if [ -z "$bound" ]; then
        fail "$host: no numbered rules file carries the uaccess builtin"
      fi
      for line in ${escapeShellArgs btdRules}; do
        if [ -z "$(files_with_line "$dir" "$line")" ]; then
          fail "$host: no udev rules file carries: $line"
        fi
      done
      if [ "$nuphy_belongs" = true ]; then
        for line in ${escapeShellArgs nuphyRules}; do
          check_uaccess_rule "$host" "$dir" "$bound" "$line"
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
