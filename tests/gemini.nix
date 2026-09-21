/*
  Check interface:

    import ./tests/gemini.nix { inherit pkgs self; }

  Asserts that implicit memory is disabled declaratively for the Gemini and
  Antigravity CLIs for user `h82` on the ThinkPad host configuration.

  Verifies:
  - ~/.gemini/antigravity-cli/settings.json sets disableAutoGenerateMemories = true.
  - ~/.gemini/settings.json sets experimental.autoMemory = false.
*/
{ pkgs, self }:
let
  host = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11;
  userConfig = host.config.home-manager.users.h82;

  agySettingsJson = userConfig.home.file.".gemini/antigravity-cli/settings.json".text or null;
  geminiSettingsJson = userConfig.home.file.".gemini/settings.json".text or null;

  # Both entries are resolved out of the Home Manager configuration, so a
  # mutation that removes one must reach the builder as shell rather than fail
  # evaluation on a null interpolation.  See
  # .compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md
  agyAbsent = pkgs.lib.optionalString (agySettingsJson == null) ''
    echo 'missing ~/.gemini/antigravity-cli/settings.json in Home Manager configuration' >&2
    exit 1
  '';
  agyPresent = pkgs.lib.optionalString (agySettingsJson != null) ''
    echo ${pkgs.lib.escapeShellArg (toString agySettingsJson)} > agy-settings.json
    agyDisableAutoMem=$(jq -r '.disableAutoGenerateMemories' agy-settings.json)
    if [ "$agyDisableAutoMem" != "true" ]; then
      echo "Expected disableAutoGenerateMemories to be true in agy settings, got: '$agyDisableAutoMem'" >&2
      exit 1
    fi
  '';

  geminiAbsent = pkgs.lib.optionalString (geminiSettingsJson == null) ''
    echo 'missing ~/.gemini/settings.json in Home Manager configuration' >&2
    exit 1
  '';
  geminiPresent = pkgs.lib.optionalString (geminiSettingsJson != null) ''
    echo ${pkgs.lib.escapeShellArg (toString geminiSettingsJson)} > gemini-settings.json
    geminiAutoMem=$(jq -r '.experimental.autoMemory' gemini-settings.json)
    if [ "$geminiAutoMem" != "false" ]; then
      echo "Expected experimental.autoMemory to be false in gemini settings, got: '$geminiAutoMem'" >&2
      exit 1
    fi
  '';
in
pkgs.runCommand "gemini-tests"
  {
    nativeBuildInputs = [
      pkgs.jq
    ];
  }
  ''
    set -x

    # 1. Verify Antigravity CLI settings.json
    ${agyAbsent}${agyPresent}

    # 2. Verify Gemini CLI settings.json
    ${geminiAbsent}${geminiPresent}

    touch $out
  ''
