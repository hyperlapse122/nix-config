/*
  Check interface:

    import ./tests/nix-cleanup.nix { inherit pkgs self; }

  Asserts that weekly Nix generation cleanup reaches the production ThinkPad
  configuration as built output, and reaches the bootstrap one not at all.

  Every assertion below reads something activation produces -- the rendered
  service and timer units, the materialised /etc/systemd/system tree, the system
  path -- rather than the programs.nh options they are derived from.  An option
  can evaluate correctly while a mkIf keeps the unit out of the built system, and
  a rendered unit exists even when nothing is wired to start it.

  Verifies:
  - the production nh-clean service unit exists, and the script its ExecStart
    names runs `nh clean all` with a retention count and a retention window.
  - the production nh-clean timer carries OnCalendar=weekly and Persistent=true,
    so a run missed while the laptop was off is caught up at the next boot.
  - the materialised system unit tree wires that timer into timers.target.wants.
    Without this the two assertions above pass on a timer nothing ever starts.
  - the retention count is at or above the boot loader's configurationLimit.  The
    boot menu is rewritten only by a rebuild while collection runs on a timer, so
    a smaller count would leave menu entries naming collected generations.  The
    count is read out of the built start script rather than out of extraArgs, so
    the operand is the text the machine will actually run.
  - the production system path ships bin/nh.  The nh module gates its package on
    programs.nh.enable and its units on clean.enable, so dropping the former
    leaves every assertion above untouched; this is the only one that sees it.
  - the production system schedules no second collector.  nix-gc.service is
    materialised whenever Nix is enabled, so the signal is the absence of
    nix-gc.timer, not of the service.
  - the bootstrap system renders neither unit and ships no bin/nh.

  The builder collects every failure instead of exiting at the first, so one red
  build names every broken assertion.  That matters for the mutation rounds this
  repository requires: exiting early leaves the remaining assertions unobserved,
  and a round that produces no evidence for an assertion proves nothing about it.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  host = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11;
  bootstrapHost = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap;

  # Every message and path below is text spliced into a shell script; escape it
  # rather than trusting the values to be quote-free.
  esc = value: lib.escapeShellArg (toString value);

  fail = message: ''
    echo ${esc message} >&2
    failed=1
  '';

  # The limit that governs each host's menu: modules/nixos/boot.nix forces
  # systemd-boot off on production and lanzaboote off on bootstrap, so reading
  # one of them unconditionally would read the loader that is not in use.
  bootLimit =
    cfg:
    if cfg.boot.lanzaboote.enable then
      cfg.boot.lanzaboote.configurationLimit
    else
      cfg.boot.loader.systemd-boot.configurationLimit;

  serviceUnit = host.config.systemd.units."nh-clean.service".unit or null;
  timerUnit = host.config.systemd.units."nh-clean.timer".unit or null;
  systemUnits = host.config.environment.etc."systemd/system".source or null;
  bootstrapSystemUnits = bootstrapHost.config.environment.etc."systemd/system".source or null;

  # Store-path interpolations stay inside optionalString guards so that removing
  # what they name fails inside the builder with the message below, rather than
  # aborting evaluation with a null coercion error.
  # Bound once so the comparison operand and the message it prints cannot drift
  # apart when one of them is edited.
  limit = esc (bootLimit host.config);

  serviceAbsent = lib.optionalString (serviceUnit == null) (
    fail "the production system renders no nh-clean.service unit"
  );

  servicePresent = lib.optionalString (serviceUnit != null) ''
    unit=${serviceUnit}/nh-clean.service
    if [ ! -f "$unit" ]; then
      ${fail "the rendered nh-clean.service directory carries no unit file"}
    else
      start=$(grep -m1 '^ExecStart=' "$unit" | cut -d= -f2- | sed 's/[[:space:]]*$//')
      if [ -z "$start" ] || [ ! -f "$start" ]; then
        ${fail "nh-clean.service names no readable ExecStart script"}
      else
        if ! grep -q 'clean all' "$start"; then
          ${fail "the nh-clean start script does not run 'nh clean all'"}
        fi
        if ! grep -q -- '--keep-since 14d' "$start"; then
          ${fail "the nh-clean start script does not keep generations from the last 14 days"}
        fi
        keep=$(grep -o -- '--keep [0-9][0-9]*' "$start" | head -1 | awk '{ print $2 }')
        if [ -z "$keep" ]; then
          ${fail "the nh-clean start script names no retention count"}
        elif [ "$keep" -lt ${limit} ]; then
          echo "retention count $keep is below the boot loader configurationLimit ${limit}; the boot menu would offer entries whose generations were collected" >&2
          failed=1
        fi
      fi
    fi
  '';

  timerAbsent = lib.optionalString (timerUnit == null) (
    fail "the production system renders no nh-clean.timer unit"
  );

  timerPresent = lib.optionalString (timerUnit != null) ''
    timer=${timerUnit}/nh-clean.timer
    if [ ! -f "$timer" ]; then
      ${fail "the rendered nh-clean.timer directory carries no unit file"}
    else
      if ! grep -Fxq 'OnCalendar=weekly' "$timer"; then
        ${fail "nh-clean.timer does not run weekly"}
      fi
      if ! grep -Fxq 'Persistent=true' "$timer"; then
        ${fail "nh-clean.timer is not persistent, so a run missed while the laptop was off is never caught up"}
      fi
    fi
  '';

  unitsAbsent = lib.optionalString (systemUnits == null) (
    fail "the production system materialises no /etc/systemd/system tree"
  );

  unitsPresent = lib.optionalString (systemUnits != null) ''
    if [ ! -e ${systemUnits}/timers.target.wants/nh-clean.timer ]; then
      ${fail "nh-clean.timer is rendered but not wired into timers.target.wants, so nothing starts it"}
    fi
    if [ -e ${systemUnits}/timers.target.wants/nix-gc.timer ]; then
      ${fail "the production system schedules nix-gc alongside nh-clean, so two collectors run"}
    fi
  '';

  bootstrapUnitsAbsent = lib.optionalString (bootstrapSystemUnits == null) (
    fail "the bootstrap system materialises no /etc/systemd/system tree, so its unit assertions read nothing"
  );

  bootstrapUnitsPresent = lib.optionalString (bootstrapSystemUnits != null) ''
    for leaked in nh-clean.service nh-clean.timer; do
      if [ -e ${bootstrapSystemUnits}/"$leaked" ]; then
        echo "the bootstrap system renders $leaked" >&2
        failed=1
      fi
    done
  '';
in
pkgs.runCommand "nix-cleanup-tests"
  {
    nativeBuildInputs = [
      pkgs.gnugrep
      pkgs.gnused
      pkgs.gawk
      pkgs.coreutils
    ];
  }
  ''
    set -x
    failed=

    ${serviceAbsent}
    ${servicePresent}
    ${timerAbsent}
    ${timerPresent}
    ${unitsAbsent}
    ${unitsPresent}
    ${bootstrapUnitsAbsent}
    ${bootstrapUnitsPresent}

    if [ ! -x ${host.config.system.path}/bin/nh ]; then
      ${fail "the production system path ships no bin/nh, so the cleanup cannot be run or previewed by hand"}
    fi
    if [ -e ${bootstrapHost.config.system.path}/bin/nh ]; then
      ${fail "the bootstrap system path ships bin/nh"}
    fi

    if [ -n "$failed" ]; then
      exit 1
    fi
    touch $out
  ''
