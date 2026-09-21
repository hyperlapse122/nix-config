/*
  Check interface:

    import ./tests/claude.nix { inherit pkgs self; }

  Asserts that Claude Code's declarative defaults are in place for user `h82`
  on the ThinkPad host configuration.

  Verifies:
  - CLAUDE_CODE_DISABLE_AUTO_MEMORY is exported as "1" in session variables.
  - /etc/claude-code/managed-settings.json sets autoMemoryEnabled = false,
    model = "opus[1m]", and effortLevel = "medium".
  - Home Manager does not manage ~/.claude/settings.json, which Claude Code
    rewrites itself and would otherwise clobber activation.
*/
{ pkgs, self }:
let
  host = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11;
  userConfig = host.config.home-manager.users.h82;

  sessionVars = userConfig.home.sessionVariables;
  managedSettingsJson = host.config.environment.etc."claude-code/managed-settings.json".text or null;
  claudeUserSettingsManaged = userConfig.home.file ? ".claude/settings.json";

  # The managed settings entry is resolved out of the host configuration, so a
  # mutation that removes it must reach the builder as shell rather than fail
  # evaluation on a null interpolation.  See
  # .compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md
  managedAbsent = pkgs.lib.optionalString (managedSettingsJson == null) ''
    echo 'missing /etc/claude-code/managed-settings.json in host configuration' >&2
    exit 1
  '';
  managedPresent = pkgs.lib.optionalString (managedSettingsJson != null) ''
    echo ${pkgs.lib.escapeShellArg (toString managedSettingsJson)} > managed-settings.json

    managedAutoMem=$(jq -r '.autoMemoryEnabled' managed-settings.json)
    if [ "$managedAutoMem" != "false" ]; then
      echo "Expected autoMemoryEnabled to be false in managed settings, got: '$managedAutoMem'" >&2
      exit 1
    fi

    managedModel=$(jq -r '.model' managed-settings.json)
    if [ "$managedModel" != "opus[1m]" ]; then
      echo "Expected model to be 'opus[1m]' in managed settings, got: '$managedModel'" >&2
      exit 1
    fi

    managedEffort=$(jq -r '.effortLevel' managed-settings.json)
    if [ "$managedEffort" != "medium" ]; then
      echo "Expected effortLevel to be 'medium' in managed settings, got: '$managedEffort'" >&2
      exit 1
    fi
  '';
in
pkgs.runCommand "claude-tests"
  {
    nativeBuildInputs = [
      pkgs.jq
    ];
  }
  ''
    set -x

    # 1. Verify Claude Code session variable kill switch
    claudeEnv='${sessionVars.CLAUDE_CODE_DISABLE_AUTO_MEMORY or ""}'
    if [ "$claudeEnv" != "1" ]; then
      echo "Expected CLAUDE_CODE_DISABLE_AUTO_MEMORY to be '1', got: '$claudeEnv'" >&2
      exit 1
    fi

    # 2. Verify Claude Code managed settings
    ${managedAbsent}${managedPresent}

    # 3. Claude Code writes ~/.claude/settings.json itself, so Home Manager
    #    must leave it alone or activation fails on an existing file.
    if [ '${pkgs.lib.boolToString claudeUserSettingsManaged}' != "false" ]; then
      echo "Home Manager must not manage ~/.claude/settings.json; Claude Code owns it" >&2
      exit 1
    fi

    touch $out
  ''
