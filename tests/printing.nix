/*
  Check interface:

    import ./tests/printing.nix { inherit pkgs self; }

  Asserts what modules/nixos/services/printing.nix produces on every
  configuration `tests/lib/configurations.nix` yields. Every assertion reads
  something activation produces -- the materialised systemd unit tree, the
  materialised nsswitch.conf and resolved.conf, the firewall start script, and
  the driver tree cupsd serves filters from -- never the options the module
  sets. Expectations come from the `my.printing.enable` trait and from
  `my.printing.queues`.

  On a configuration that enables the trait:
  - cups.socket listens and sockets.target wants it, so a masked unit fails.
  - avahi-daemon.service runs avahi-daemon and multi-user.target wants it.
  - no unit runs cups-browsed.
  - the hosts line of nsswitch.conf carries mdns4_minimal, before resolve
    when resolve is present.
  - on a configuration that runs systemd-resolved, resolved.conf turns its
    mDNS responder off. At least one enabled configuration must run resolved,
    so this branch never covers zero configurations.
  - the firewall start script accepts UDP 5353.
  - the cupsd driver tree carries the gutenprint and hplip filters.

  On a configuration that leaves the trait off: no cups.socket listens, no
  avahi-daemon.service runs, nsswitch.conf carries no mdns4_minimal, and
  resolved.conf keeps its mDNS default.

  On a production configuration that declares printer queues:
  - ensure-printers.service is wanted by multi-user.target, reads the rendered
    sops template, creates each queue with `-m everywhere`, and its script
    carries no literal ipp:// or ipps:// URI, so a device URI rendered into the
    Nix store fails.
  On every other configuration, including bootstrap outputs, no
  ensure-printers.service exists. At least one production configuration must
  declare a queue.

  The builder collects every failure instead of exiting at the first, so one
  red build names every affected configuration.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self; };
  printing = configurations.withTrait "my.printing.enable" (config: config.my.printing.enable);

  declaresQueues = entry: !entry.bootstrap && entry.config.my.printing.queues != [ ];
  queued = lib.filter declaresQueues configurations.entries;
  unqueued = lib.filter (entry: !declaresQueues entry) configurations.entries;

  esc = value: lib.escapeShellArg (toString value);

  fail = message: ''
    echo ${esc message} >&2
    failed=1
  '';

  units = config: config.environment.etc."systemd/system".source or null;
  etcFile =
    config: name:
    let
      entry = config.environment.etc.${name} or null;
    in
    if entry == null then null else entry.source;

  # cupsd serves filters from the tree its ServerBin names; CUPS_DATADIR points
  # at share/cups inside the same tree.
  driverTree =
    config:
    let
      dataDir = config.environment.sessionVariables.CUPS_DATADIR or null;
    in
    if dataDir == null then null else dirOf (dirOf dataDir);

  # The Proton VPN module, not the module under test, decides this.
  runsResolved = config: config.services.resolved.enable;

  withTree =
    entry: body:
    let
      tree = units entry.config;
    in
    if tree == null then
      fail "${entry.name}: the built system declares no /etc/systemd/system tree"
    else
      body tree;

  assertEnabled =
    entry:
    let
      inherit (entry) config name;
      nsswitch = etcFile config "nsswitch.conf";
      resolvedConf = etcFile config "systemd/resolved.conf";
      drivers = driverTree config;
    in
    lib.concatStringsSep "\n" [
      (withTree entry (tree: ''
        if ! grep -q '^ListenStream=' ${esc "${tree}/cups.socket"}; then
          ${fail "${name}: the materialised cups.socket is missing, masked, or listens nowhere"}
        fi
        if [ ! -e ${esc "${tree}/sockets.target.wants/cups.socket"} ]; then
          ${fail "${name}: sockets.target does not want cups.socket"}
        fi
        if ! grep -q '^ExecStart=.*/avahi-daemon ' ${esc "${tree}/avahi-daemon.service"}; then
          ${fail "${name}: the materialised avahi-daemon.service is missing, masked, or does not run avahi-daemon"}
        fi
        if [ ! -e ${esc "${tree}/multi-user.target.wants/avahi-daemon.service"} ]; then
          ${fail "${name}: multi-user.target does not want avahi-daemon.service"}
        fi
        if grep -qs '^ExecStart=.*cups-browsed' ${esc tree}/*.service; then
          ${fail "${name}: a unit runs cups-browsed"}
        fi
        firewall=$(sed -n 's/^ExecStart=@\([^ ]*\) .*/\1/p' ${esc "${tree}/firewall.service"})
        if [ -z "$firewall" ] || ! grep -q -- '-p udp --dport 5353 -j nixos-fw-accept' "$firewall"; then
          ${fail "${name}: the firewall start script does not accept UDP 5353 for mDNS"}
        fi
      ''))
      (
        if nsswitch == null then
          fail "${name}: the built system declares no /etc/nsswitch.conf"
        else
          ''
            hosts=$(grep '^hosts:' ${esc nsswitch})
            case "$hosts" in
              *mdns4_minimal*) ;;
              *) ${fail "${name}: the nsswitch.conf hosts line carries no mdns4_minimal"} ;;
            esac
            case "$hosts" in
              *resolve*mdns4_minimal*) ${fail "${name}: the nsswitch.conf hosts line puts resolve before mdns4_minimal"} ;;
            esac
          ''
      )
      (lib.optionalString (runsResolved config) (
        if resolvedConf == null then
          fail "${name}: resolved runs but the built system declares no /etc/systemd/resolved.conf"
        else
          ''
            if ! grep -qx 'MulticastDNS=false' ${esc resolvedConf}; then
              ${fail "${name}: resolved.conf leaves resolved's mDNS responder on beside Avahi"}
            fi
          ''
      ))
      (
        if drivers == null then
          fail "${name}: the built system sets no CUPS_DATADIR, so the cupsd driver tree is unknown"
        else
          ''
            if ! ls ${esc drivers}/lib/cups/filter/rastertogutenprint.* >/dev/null 2>&1; then
              ${fail "${name}: the cupsd driver tree carries no gutenprint filter"}
            fi
            if [ ! -x ${esc "${drivers}/lib/cups/filter/hpcups"} ]; then
              ${fail "${name}: the cupsd driver tree carries no hplip hpcups filter"}
            fi
          ''
      )
    ];

  assertDisabled =
    entry:
    let
      inherit (entry) config name;
      nsswitch = etcFile config "nsswitch.conf";
      resolvedConf = etcFile config "systemd/resolved.conf";
    in
    lib.concatStringsSep "\n" [
      (withTree entry (tree: ''
        if grep -qs '^ListenStream=' ${esc "${tree}/cups.socket"}; then
          ${fail "${name}: my.printing.enable is off but cups.socket listens"}
        fi
        if grep -qs '^ExecStart=.*/avahi-daemon ' ${esc "${tree}/avahi-daemon.service"}; then
          ${fail "${name}: my.printing.enable is off but avahi-daemon.service runs avahi-daemon"}
        fi
      ''))
      (lib.optionalString (nsswitch != null) ''
        if grep '^hosts:' ${esc nsswitch} | grep -q mdns4_minimal; then
          ${fail "${name}: my.printing.enable is off but the nsswitch.conf hosts line carries mdns4_minimal"}
        fi
      '')
      (lib.optionalString (resolvedConf != null) ''
        if grep -q '^MulticastDNS=false$' ${esc resolvedConf}; then
          ${fail "${name}: my.printing.enable is off but resolved.conf turns resolved's mDNS responder off"}
        fi
      '')
    ];

  assertQueued =
    entry:
    withTree entry (tree: ''
      unit=${esc "${tree}/ensure-printers.service"}
      if [ ! -e ${esc "${tree}/multi-user.target.wants/ensure-printers.service"} ]; then
        ${fail "${entry.name}: queues are declared but multi-user.target does not want ensure-printers.service"}
      fi
      if ! grep -qx 'EnvironmentFile=/run/secrets/rendered/printers.env' "$unit"; then
        ${fail "${entry.name}: ensure-printers.service is missing, masked, or does not read the rendered printers.env"}
      fi
      script=$(sed -n 's/^ExecStart=\([^ ]*\).*/\1/p' "$unit")
      if [ -z "$script" ] || ! grep -q -- '-m everywhere' "$script"; then
        ${fail "${entry.name}: ensure-printers.service does not create queues with -m everywhere"}
      fi
      if [ -n "$script" ] && grep -qE 'ipps?://' "$script" "$unit"; then
        ${fail "${entry.name}: ensure-printers.service carries a literal device URI in the Nix store"}
      fi
    '');

  assertUnqueued =
    entry:
    withTree entry (tree: ''
      if [ -e ${esc "${tree}/ensure-printers.service"} ]; then
        ${fail "${entry.name}: no queue is declared for this configuration but ensure-printers.service exists"}
      fi
    '');

  resolvedGuard = lib.optionalString (!lib.any (entry: runsResolved entry.config) printing.enabled) ''
    echo 'tests/printing.nix: no configuration enabling my.printing.enable runs resolved, so the mDNS conflict branch would cover none' >&2
    exit 1
  '';

  queueGuard = lib.optionalString (queued == [ ]) ''
    echo 'tests/printing.nix: no production configuration declares my.printing.queues, so the queue branch would cover none' >&2
    exit 1
  '';
in
pkgs.runCommand "printing-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
  set -x
  ${configurations.guard}
  ${printing.guard}
  ${resolvedGuard}
  ${queueGuard}
  failed=0

  ${lib.concatMapStringsSep "\n" assertEnabled printing.enabled}
  ${lib.concatMapStringsSep "\n" assertDisabled printing.disabled}
  ${lib.concatMapStringsSep "\n" assertQueued queued}
  ${lib.concatMapStringsSep "\n" assertUnqueued unqueued}

  if [ "$failed" != 0 ]; then
    exit 1
  fi
  touch $out
''
