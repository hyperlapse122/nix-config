/*
  Check interface:

    import ./tests/claude.nix { inherit pkgs self; }

  Asserts that Claude Code's declarative defaults are in place for user `h82`
  on both the production and bootstrap ThinkPad configurations.

  Verifies, per host:
  - CLAUDE_CODE_DISABLE_AUTO_MEMORY is exported as "1" in session variables.
  - /etc/claude-code/managed-settings.json is enabled, so activation writes it.
  - That file sets autoMemoryEnabled = false, model = "opus[1m]", and
    effortLevel = "medium".
  - No Home Manager file targets ~/.claude/settings.json, which Claude Code
    rewrites itself and would otherwise clobber activation.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  esc = value: lib.escapeShellArg (toString value);

  # Every lookup carries an `or` fallback so a mutation that removes an entry
  # or a key reaches the builder as shell rather than failing evaluation on a
  # null interpolation.  See
  # .compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md
  assertHost =
    hostName: host:
    let
      entry = host.config.environment.etc."claude-code/managed-settings.json" or null;
      managed = if entry == null then null else builtins.fromJSON (entry.text or "null");
      userConfig = host.config.home-manager.users.h82;
      killSwitch = userConfig.home.sessionVariables.CLAUDE_CODE_DISABLE_AUTO_MEMORY or "";
      # Home Manager resolves the destination from each entry's `target`, which
      # defaults to the attribute name but can be set explicitly, so an
      # attribute-name test would miss a renamed entry.
      claudeSettingsTargeted = lib.any (file: (file.target or "") == ".claude/settings.json") (
        lib.attrValues userConfig.home.file
      );

      absent = lib.optionalString (managed == null) ''
        echo 'missing /etc/claude-code/managed-settings.json on ${hostName}' >&2
        exit 1
      '';
      present = lib.optionalString (managed != null) ''
        managedEnabled=${esc (lib.boolToString (entry.enable or false))}
        if [ "$managedEnabled" != "true" ]; then
          echo "Expected /etc/claude-code/managed-settings.json to be enabled on ${hostName}, got: '$managedEnabled'" >&2
          exit 1
        fi

        managedAutoMem=${esc (builtins.toJSON (managed.autoMemoryEnabled or null))}
        if [ "$managedAutoMem" != "false" ]; then
          echo "Expected autoMemoryEnabled to be false on ${hostName}, got: '$managedAutoMem'" >&2
          exit 1
        fi

        managedModel=${esc (managed.model or "")}
        if [ "$managedModel" != "opus[1m]" ]; then
          echo "Expected model to be 'opus[1m]' on ${hostName}, got: '$managedModel'" >&2
          exit 1
        fi

        managedEffort=${esc (managed.effortLevel or "")}
        if [ "$managedEffort" != "medium" ]; then
          echo "Expected effortLevel to be 'medium' on ${hostName}, got: '$managedEffort'" >&2
          exit 1
        fi
      '';
    in
    ''
      claudeEnv=${esc killSwitch}
      if [ "$claudeEnv" != "1" ]; then
        echo "Expected CLAUDE_CODE_DISABLE_AUTO_MEMORY to be '1' on ${hostName}, got: '$claudeEnv'" >&2
        exit 1
      fi

      ${absent}${present}

      if [ ${esc (lib.boolToString claudeSettingsTargeted)} != "false" ]; then
        echo "Home Manager must not target ~/.claude/settings.json on ${hostName}; Claude Code owns it" >&2
        exit 1
      fi
    '';
in
pkgs.runCommand "claude-tests" { } ''
  set -x

  ${assertHost "ThinkPad-X1-Carbon-Gen-11" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11}

  ${assertHost "ThinkPad-X1-Carbon-Gen-11-bootstrap" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap}

  touch $out
''
