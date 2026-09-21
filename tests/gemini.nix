/*
  Check interface:

    import ./tests/gemini.nix { inherit pkgs self; }

  Asserts that implicit memory is disabled declaratively for the Gemini and
  Antigravity CLIs for user `h82` on both the production and bootstrap ThinkPad
  configurations.

  Verifies, per host:
  - ~/.gemini/antigravity-cli/settings.json sets disableAutoGenerateMemories = true.
  - ~/.gemini/settings.json sets experimental.autoMemory = false.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  esc = value: lib.escapeShellArg (toString value);

  # Every lookup carries an `or` fallback so a mutation that removes a
  # declaration or a key reaches the builder as shell rather than failing
  # evaluation on a null interpolation.  See
  # .compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md
  assertHost =
    hostName: host:
    let
      userConfig = host.config.home-manager.users.h82;
      agyJson = userConfig.home.file.".gemini/antigravity-cli/settings.json".text or null;
      geminiJson = userConfig.home.file.".gemini/settings.json".text or null;
      agy = if agyJson == null then null else builtins.fromJSON agyJson;
      gemini = if geminiJson == null then null else builtins.fromJSON geminiJson;

      agyAbsent = lib.optionalString (agy == null) ''
        echo 'missing ~/.gemini/antigravity-cli/settings.json on ${hostName}' >&2
        exit 1
      '';
      agyPresent = lib.optionalString (agy != null) ''
        agyDisableAutoMem=${esc (builtins.toJSON (agy.disableAutoGenerateMemories or null))}
        if [ "$agyDisableAutoMem" != "true" ]; then
          echo "Expected disableAutoGenerateMemories to be true on ${hostName}, got: '$agyDisableAutoMem'" >&2
          exit 1
        fi
      '';

      geminiAbsent = lib.optionalString (gemini == null) ''
        echo 'missing ~/.gemini/settings.json on ${hostName}' >&2
        exit 1
      '';
      geminiPresent = lib.optionalString (gemini != null) ''
        geminiAutoMem=${esc (builtins.toJSON (gemini.experimental.autoMemory or null))}
        if [ "$geminiAutoMem" != "false" ]; then
          echo "Expected experimental.autoMemory to be false on ${hostName}, got: '$geminiAutoMem'" >&2
          exit 1
        fi
      '';
    in
    ''
      ${agyAbsent}${agyPresent}
      ${geminiAbsent}${geminiPresent}
    '';
in
pkgs.runCommand "gemini-tests" { } ''
  set -x

  ${assertHost "ThinkPad-X1-Carbon-Gen-11" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11}

  ${assertHost "ThinkPad-X1-Carbon-Gen-11-bootstrap" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap}

  touch $out
''
