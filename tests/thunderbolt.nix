/*
  Check interface:

    import ./tests/thunderbolt.nix { inherit pkgs self; }

  Asserts that both ThinkPad configurations ship bolt, the Thunderbolt device
  manager, and Plasma's Thunderbolt settings module, declared in
  modules/nixos/hardware/thunderbolt.nix. Every assertion reads something
  activation produces -- the materialised systemd unit tree, the materialised
  udev rules directory, the system path -- rather than
  services.hardware.bolt.enable. plasma6.nix adds plasma-thunderbolt only when
  bolt is enabled, so the Plasma module is asserted on its own: an option read
  would stay green if an overlay swapped the package out.

  Verifies, on ThinkPad-X1-Carbon-Gen-11 and ThinkPad-X1-Carbon-Gen-11-bootstrap:
  - the materialised systemd unit tree carries bolt.service.
  - some file in the materialised udev rules directory carries bolt's rule that
    starts bolt.service when a Thunderbolt device appears, verbatim. Without it
    nothing starts the daemon, since bolt.service has no [Install] section.
  - the system path carries bin/boltctl.
  - the system path carries the kcm_bolt settings module and its desktop entry.

  It cannot see whether a real device gets authorized; docs/verification.md
  covers that on hardware. MS-7D91 is outside this check.

  The builder collects every failure instead of exiting at the first, so one red
  build names every broken assertion across both hosts.
*/
{ pkgs, self }:
let
  inherit (pkgs.lib) concatStringsSep mapAttrsToList escapeShellArg;

  # Every message and path below is text spliced into a shell script, so it is
  # escaped rather than trusted to be quote-free.
  esc = value: escapeShellArg (toString value);

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

  hostAssertions =
    hostName: host:
    let
      units = host.config.environment.etc."systemd/system".source or null;
      udevRules = host.config.environment.etc."udev/rules.d".source or null;
      systemPath = host.config.system.path;
    in
    concatStringsSep "\n" [
      (assertPath {
        flag = "-e";
        root = units;
        path = "bolt.service";
        message = "${hostName}: the materialised systemd units carry no bolt.service";
        absentMessage = "${hostName}: the built system declares no /etc/systemd/system tree";
      })
      (
        if udevRules == null then
          fail "${hostName}: the built system declares no /etc/udev/rules.d directory"
        else
          ''
            if ! grep -qFx -- ${esc boltRule} ${esc udevRules}/*.rules; then
              ${fail "${hostName}: no udev rules file carries bolt's start rule: ${boltRule}"}
            fi
          ''
      )
      (assertPath {
        flag = "-x";
        root = systemPath;
        path = "bin/boltctl";
        message = "${hostName}: the system path ships no bin/boltctl";
      })
      (assertPath {
        flag = "-f";
        root = systemPath;
        path = "lib/qt-6/plugins/plasma/kcms/systemsettings/kcm_bolt.so";
        message = "${hostName}: the system path ships no Plasma Thunderbolt settings module (kcm_bolt.so)";
      })
      (assertPath {
        flag = "-f";
        root = systemPath;
        path = "share/applications/kcm_bolt.desktop";
        message = "${hostName}: the system path ships no Plasma Thunderbolt desktop entry (kcm_bolt.desktop)";
      })
    ];
in
pkgs.runCommand "thunderbolt-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
  failed=0

  ${concatStringsSep "\n" (
    mapAttrsToList hostAssertions {
      ThinkPad-X1-Carbon-Gen-11 = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11;
      ThinkPad-X1-Carbon-Gen-11-bootstrap = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap;
    }
  )}

  if [ "$failed" != 0 ]; then
    exit 1
  fi
  touch $out
''
