/*
  Check interface:

    import ./tests/keyd-remap.nix { inherit pkgs self; }

  Asserts what the keyd module generates on every configuration
  `tests/lib/configurations.nix` yields, with the expectation taken from each
  configuration's `my.keyd.enable` trait rather than from `services.keyd.enable`,
  the option the module under test sets.

  On a configuration that enables the trait:
  - the materialized keyd.service runs keyd, so a masked or missing unit fails.
  - the generated /etc/keyd/default.conf is scoped to the internal keyboard,
    maps Caps Lock alone to Hangul and Ctrl+Caps Lock to the real Caps Lock, and
    keeps the Copilot binding out.
  - a fixture that is the production configuration with `my.keyd.copilotKey`
    forced on carries the Copilot binding and the same invariant bindings.
  - libinput keeps treating keyd's virtual keyboard as built in.
  - `keyd check` parses every generated file, so a misspelled key name that
    still greps clean fails here.

  On a configuration that leaves the trait off: no keyd.service runs keyd, and
  neither /etc/keyd/default.conf nor the libinput quirk is declared.

  At least one production configuration must enable the trait, or the helper
  fails the check, so the positive branch never covers zero configurations.

  Assertions are scoped to an INI section. A bare whole-line grep matches
  anywhere in the file, so it stays green when a mapping moves to the wrong
  section -- which is the inverse of the intended behaviour, not a near miss.

  Every /etc lookup carries an `or null` fallback and store paths are
  interpolated only inside the present branch, so a missing entry fails inside
  the builder rather than during evaluation. The builder collects every failure
  before it exits, so one red build names every affected configuration.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self; };
  keyd = configurations.withTrait "my.keyd.enable" (config: config.my.keyd.enable);

  esc = value: lib.escapeShellArg (toString value);

  fail = message: ''
    echo ${esc message} >&2
    failed=1
  '';

  etcSource = config: name: config.environment.etc.${name}.source or null;

  keydConf = config: etcSource config "keyd/default.conf";
  units = config: etcSource config "systemd/system";

  # The bindings that must hold whatever the Copilot option is set to.
  assertBindings =
    label: conf:
    if conf == null then
      fail "${label}: no /etc/keyd/default.conf is declared"
    else
      ''
        conf=${esc conf}
        if ! section ids "$conf" | grep -Fxq "0001:0001"; then
          ${fail "${label}: the remap is not scoped to the internal keyboard (ids 0001:0001)"}
        fi
        if section ids "$conf" | grep -Fxq "*"; then
          ${fail "${label}: ids still carries the upstream wildcard"}
        fi
        if ! section main "$conf" | grep -Fxq "capslock=hangeul"; then
          ${fail "${label}: Caps Lock alone does not emit the Hangul key in [main]"}
        fi
        if ! section control "$conf" | grep -Fxq "capslock=capslock"; then
          ${fail "${label}: Ctrl+Caps Lock does not keep the real Caps Lock in [control]"}
        fi
        if ! keyd check "$conf"; then
          ${fail "${label}: keyd check rejects the generated configuration"}
        fi
      '';

  assertEnabled =
    entry:
    let
      conf = keydConf entry.config;
      unitTree = units entry.config;
      quirks = etcSource entry.config "libinput/local-overrides.quirks";
    in
    lib.concatStringsSep "\n" [
      (
        if unitTree == null then
          fail "${entry.name}: the built system declares no /etc/systemd/system tree"
        else
          ''
            if ! grep -q '^ExecStart=.*/bin/keyd$' ${esc "${unitTree}/keyd.service"}; then
              ${fail "${entry.name}: my.keyd.enable is set but the materialised keyd.service is missing, masked, or does not run keyd"}
            fi
          ''
      )
      (assertBindings entry.name conf)
      # The Copilot chord follows the host's own my.keyd.copilotKey: present
      # where the host asks for it, absent everywhere else.
      (lib.optionalString (conf != null && entry.config.my.keyd.copilotKey) ''
        if ! section main ${esc conf} | grep -Fxq "leftshift+leftmeta+f23=layer(meta)"; then
          ${fail "${entry.name}: my.keyd.copilotKey is set but the Copilot binding is missing from [main]"}
        fi
      '')
      (lib.optionalString (conf != null && !entry.config.my.keyd.copilotKey) ''
        if grep -q "f23" ${esc conf}; then
          ${fail "${entry.name}: the Copilot binding leaked into a configuration that does not ask for it"}
        fi
      '')
      (
        if quirks == null then
          fail "${entry.name}: no libinput quirk for keyd's virtual keyboard is declared"
        else
          ''
            if ! grep -Fxq "MatchName=keyd virtual keyboard" ${esc quirks} \
              || ! grep -Fxq "AttrKeyboardIntegration=internal" ${esc quirks}; then
              ${fail "${entry.name}: libinput no longer treats keyd's virtual keyboard as internal"}
            fi
          ''
      )
    ];

  # The production configuration with the Copilot correction forced on. The
  # option defaults off, and mkForce keeps this fixture valid if a host ever
  # sets it.
  assertCopilot =
    entry:
    let
      copilotConfig =
        (self.nixosConfigurations.${entry.name}.extendModules {
          modules = [ { my.keyd.copilotKey = lib.mkForce true; } ];
        }).config;
      conf = keydConf copilotConfig;
      label = "${entry.name} with my.keyd.copilotKey";
    in
    lib.concatStringsSep "\n" [
      (assertBindings label conf)
      (lib.optionalString (conf != null) ''
        if ! section main ${esc conf} | grep -Fxq "leftshift+leftmeta+f23=layer(meta)"; then
          ${fail "${label}: the Copilot binding is missing from [main]"}
        fi
      '')
    ];

  assertDisabled =
    entry:
    let
      unitTree = units entry.config;
    in
    lib.concatStringsSep "\n" [
      (lib.optionalString (unitTree != null) ''
        if grep -qs '^ExecStart=.*/bin/keyd$' ${esc "${unitTree}/keyd.service"}; then
          ${fail "${entry.name}: my.keyd.enable is off but the materialised keyd.service runs keyd"}
        fi
      '')
      (lib.optionalString (keydConf entry.config != null) (
        fail "${entry.name}: my.keyd.enable is off but /etc/keyd/default.conf is declared"
      ))
      (lib.optionalString (etcSource entry.config "libinput/local-overrides.quirks" != null) (
        fail "${entry.name}: my.keyd.enable is off but the keyd libinput quirk is declared"
      ))
    ];
in
pkgs.runCommand "keyd-remap-tests"
  {
    nativeBuildInputs = [
      pkgs.gawk
      pkgs.gnugrep
      pkgs.keyd
    ];
  }
  ''
    set -x
    ${configurations.guard}
    ${keyd.guard}
    failed=0

    section() {
      awk -v want="[$1]" '$0 == want { inside = 1; next } /^\[/ { inside = 0 } inside' "$2"
    }

    ${lib.concatMapStringsSep "\n" assertEnabled keyd.enabled}
    ${lib.concatMapStringsSep "\n" assertCopilot (lib.filter (entry: !entry.bootstrap) keyd.enabled)}
    ${lib.concatMapStringsSep "\n" assertDisabled keyd.disabled}

    if [ "$failed" != 0 ]; then
      exit 1
    fi
    touch $out
  ''
