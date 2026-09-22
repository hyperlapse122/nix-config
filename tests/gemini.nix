/*
  Check interface:

    import ./tests/gemini.nix { inherit pkgs self; }

  Asserts that implicit memory is disabled declaratively for the Gemini and
  Antigravity CLIs for user `h82` on both the production and bootstrap ThinkPad
  configurations.

  The two files reach the home directory by different mechanisms. The Gemini
  CLI only reads ~/.gemini/settings.json, so a store symlink holds it. The
  Antigravity CLI rewrites ~/.gemini/antigravity-cli/settings.json at runtime --
  trusting a workspace replaces the whole file -- so a symlink there is replaced
  by a regular file and the next activation fails rather than clobber it. That
  file is merged at activation instead, as ~/.claude/settings.json is.

  Verifies, per host:
  - ~/.gemini/settings.json sets experimental.autoMemory = false.
  - the JSON this repository renders for the Antigravity CLI sets
    disableAutoGenerateMemories = true. Asserting the rendered file rather than
    the Nix attribute set keeps the check on what activation feeds the merger.
  - home.activation.antigravitySettings exists, runs after installPackages,
    names the packaged merger, points it at the real settings file, and does not
    swallow its exit status.
  - no Home Manager file targets .gemini/antigravity-cli/settings.json. A merge
    and a store symlink are mutually exclusive, and the symlink is the bug this
    check exists to keep out. Home Manager resolves a file's destination from
    `target`, which only defaults to the attribute name, so the lookup compares
    resolved targets rather than attribute names.

  Whether the merge preserves the keys the agent owns is behaviour of the
  packaged script, not of evaluated configuration; the `agent-settings` check in
  flake.nix drives that script against a seeded settings file.

  Every lookup carries an `or` fallback so a mutation that removes a declaration
  or a key reaches the builder as shell rather than failing evaluation on a null
  interpolation.  See
  .compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md

  The builder collects every failure instead of exiting at the first, so one red
  build names every broken assertion across both hosts.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  esc = value: lib.escapeShellArg (toString value);

  assertHost =
    hostName: host:
    let
      userConfig = host.config.home-manager.users.h82;
      geminiJson = userConfig.home.file.".gemini/settings.json".text or null;
      gemini = if geminiJson == null then null else builtins.fromJSON geminiJson;

      activation = userConfig.home.activation.antigravitySettings or null;
      script = if activation == null then "" else (activation.data or "");
      # After installPackages, so a refusal cannot strand linkGeneration and
      # installPackages behind it. Asserting writeBoundary instead would pass
      # the position that causes that, since installPackages is itself after
      # writeBoundary.
      runsAfterPackages = lib.elem "installPackages" (
        if activation == null then [ ] else (activation.after or [ ])
      );

      antigravityTargeted = lib.any (
        file: (file.target or "") == ".gemini/antigravity-cli/settings.json"
      ) (lib.attrValues (userConfig.home.file or { }));

      geminiAbsent = lib.optionalString (gemini == null) ''
        echo 'missing ~/.gemini/settings.json on ${hostName}' >&2
        failed=1
      '';
      geminiPresent = lib.optionalString (gemini != null) ''
        geminiAutoMem=${esc (builtins.toJSON (gemini.experimental.autoMemory or null))}
        if [ "$geminiAutoMem" != "false" ]; then
          echo "Expected experimental.autoMemory to be false on ${hostName}, got: '$geminiAutoMem'" >&2
          failed=1
        fi
      '';

      activationAbsent = lib.optionalString (activation == null) ''
        echo 'missing home.activation.antigravitySettings on ${hostName}' >&2
        failed=1
      '';

      activationPresent = lib.optionalString (activation != null) ''
        if [ ${esc (lib.boolToString runsAfterPackages)} != "true" ]; then
          echo 'home.activation.antigravitySettings must run after installPackages on ${hostName}' >&2
          failed=1
        fi

        if ! printf '%s' ${esc script} | grep -qF '/bin/agent-settings'; then
          echo 'the antigravitySettings activation script must invoke the packaged merger on ${hostName}' >&2
          failed=1
        fi

        # Swallowing the merger's exit status turns a refusal into a silent
        # no-op, which is the failure mode the no-swallow rule exists for.
        # `|| true` is only the most obvious spelling, so this matches the
        # equivalents too. Comment lines are stripped first, because the block
        # documents why the swallow is absent and matching that sentence would
        # fail the honest script.
        if printf '%s' ${esc script} | grep -v '^[[:space:]]*#' \
          | grep -qE '(\|\|[[:space:]]*(true|:|echo)|;[[:space:]]*true|set \+e)'; then
          echo 'the antigravitySettings activation script must not swallow the merger exit status on ${hostName}' >&2
          failed=1
        fi

        # Read the flags the merger is actually invoked with, not merely whether
        # the script mentions a path somewhere: a script that names the right
        # file in a comment and hands the merger a different one would pass.
        settingsArg=$(printf '%s' ${esc script} \
          | tr '\n' ' ' | grep -oE -- '--settings[[:space:]]+[^[:space:]]+' \
          | head -1 | awk '{print $2}' || true)
        if [ "$settingsArg" != ${esc "${userConfig.home.homeDirectory or ""}/.gemini/antigravity-cli/settings.json"} ]; then
          echo "the merger must be pointed at the real settings file on ${hostName}, got: '$settingsArg'" >&2
          failed=1
        fi

        # Compared against a file rendered here rather than re-derived from the
        # module, so a mutation of the declared set turns this red.
        declaredPath=$(printf '%s' ${esc script} \
          | tr '\n' ' ' | grep -oE -- '--declared[[:space:]]+/nix/store/[^[:space:]]+' \
          | head -1 | awk '{print $2}' || true)
        if [ -z "$declaredPath" ]; then
          echo 'the antigravitySettings activation script passes no declared-settings file on ${hostName}' >&2
          failed=1
        elif ! diff -u "$declaredPath" "$declaredExpected" >/dev/null; then
          echo 'the declared Antigravity settings this repository renders drifted from the asserted values on ${hostName}' >&2
          failed=1
        fi
      '';

      symlinkPresent = lib.optionalString antigravityTargeted ''
        echo 'Home Manager must not target ~/.gemini/antigravity-cli/settings.json on ${hostName}; the Antigravity CLI owns it' >&2
        failed=1
      '';
    in
    ''
      ${geminiAbsent}${geminiPresent}
      ${activationAbsent}${activationPresent}${symlinkPresent}
    '';

  declaredExpected = pkgs.writeText "antigravity-expected-settings.json" (
    builtins.toJSON {
      set = {
        disableAutoGenerateMemories = true;
      };
      remove = [ ];
    }
  );
in
pkgs.runCommand "gemini-tests" { nativeBuildInputs = [ pkgs.diffutils ]; } ''
  set -x
  failed=0
  declaredExpected=${declaredExpected}

  ${assertHost "ThinkPad-X1-Carbon-Gen-11" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11}

  ${assertHost "ThinkPad-X1-Carbon-Gen-11-bootstrap" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap}

  if [ "$failed" != "0" ]; then
    exit 1
  fi

  touch $out
''
