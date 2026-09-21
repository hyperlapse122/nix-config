/*
  Check interface:

    import ./tests/keyd-remap.nix { inherit pkgs self; }

  Asserts what the keyd module generates for both states of the Copilot-key
  option. `self` supplies the evaluated production host. The Copilot-enabled
  fixture is that host extended with the option forced on, because the host
  pins it off; without mkForce the two definitions conflict.

  Assertions are scoped to an INI section. A bare whole-line grep matches
  anywhere in the file, so it stays green when a mapping moves to the wrong
  section -- which is the inverse of the intended behaviour, not a near miss.

  `keyd check` runs here as well: it parses the generated file, so it rejects a
  key name that is spelled wrong but still greps clean. It is parse-only and
  needs no input device. It cannot see section semantics, which is why the
  slicing above carries that half.
*/
{ pkgs, self }:
let
  host = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11;
  copilotHost = host.extendModules {
    modules = [ { my.keyd.copilotKey = pkgs.lib.mkForce true; } ];
  };
  keydConf = machine: machine.config.environment.etc."keyd/default.conf".source;
  quirks = host.config.environment.etc."libinput/local-overrides.quirks".source;
  serviceEnabled = host.config.services.keyd.enable;
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
    # Trace every assertion so a failing build log names the check that tripped;
    # the greps below are quiet by design and would otherwise fail silently.
    set -x

    default=${keydConf host}
    copilot=${keydConf copilotHost}
    quirksFile=${quirks}

    section() {
      awk -v want="[$1]" '$0 == want { inside = 1; next } /^\[/ { inside = 0 } inside' "$2"
    }

    # R1: the remapping service is enabled on the host.
    echo '${builtins.toJSON serviceEnabled}' | grep -Fxq "true"

    # The bindings that must hold whatever the Copilot option is set to.
    for conf in "$default" "$copilot"; do
      # R5: scoped to the internal keyboard, not to every connected keyboard.
      section ids "$conf" | grep -Fxq "0001:0001"
      if section ids "$conf" | grep -Fxq "*"; then
        echo "ids still carries the upstream wildcard" >&2
        exit 1
      fi

      # R2: Caps Lock alone emits the Hangul key.
      section main "$conf" | grep -Fxq "capslock=hangeul"

      # R3: Ctrl+Caps Lock keeps the real Caps Lock toggle.
      section control "$conf" | grep -Fxq "capslock=capslock"
    done

    # R4, AE1: the Copilot correction stays out unless a host asks for it.
    # Written as an explicit branch: `! cmd` is exempt from set -e, so a bare
    # negation would silently assert nothing.
    if grep -q "f23" "$default"; then
      echo "Copilot binding leaked into the default host configuration" >&2
      exit 1
    fi

    # R4, AE2: and is present when a host does.
    section main "$copilot" | grep -Fxq "leftshift+leftmeta+f23=layer(meta)"

    # R7: libinput keeps treating keyd's virtual keyboard as built in.
    grep -Fxq "MatchName=keyd virtual keyboard" "$quirksFile"
    grep -Fxq "AttrKeyboardIntegration=internal" "$quirksFile"

    # Both generated files parse as keyd configuration, which the greps above
    # cannot establish: a misspelled key name greps clean but fails here.
    keyd check "$default"
    keyd check "$copilot"

    touch $out
  ''
