/*
  Check interface:

    import ./tests/gemini.nix { inherit pkgs self; }

  Asserts that implicit memory is disabled declaratively for the Gemini and
  Antigravity CLIs for user `h82` on every configuration
  `tests/lib/configurations.nix` yields, production and bootstrap alike, since
  none of it depends on a host trait or on `my.bootstrap`.

  The two files reach the home directory by different mechanisms. The Gemini
  CLI only reads ~/.gemini/settings.json, so a store symlink holds it. The
  Antigravity CLI rewrites ~/.gemini/antigravity-cli/settings.json at runtime --
  trusting a workspace replaces the whole file -- so a symlink there is replaced
  by a regular file and the next activation fails rather than clobber it. That
  file is merged at activation instead, as ~/.claude/settings.json is.

  Verifies, per configuration:
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

  - home.activation.antigravityHooks exists, runs after installPackages, points
    the merger at ~/.gemini/config/hooks.json, and hands it a declaration that
    only removes the retired `orca-orchestration` entry and declares no hook of
    its own. Orca writes its own `orca-status` entry in that file, so owning
    or removing any other key -- or the whole document -- would erase it. The
    expected declaration is rendered here, not read back from the module.

  Whether the merge preserves the keys the agent owns is behaviour of the
  packaged script, not of evaluated configuration; the `agent-settings` check in
  flake.nix drives that script against a seeded settings file.

  Every lookup carries an `or` fallback so a mutation that removes a declaration
  or a key reaches the builder as shell rather than failing evaluation on a null
  interpolation.  See
  .compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md

  The builder collects every failure instead of exiting at the first, so one red
  build names every broken assertion across every configuration.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self; };

  esc = value: lib.escapeShellArg (toString value);

  assertHost =
    entry:
    let
      hostName = entry.name;
      userConfig = entry.user;
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

      hooksActivation = userConfig.home.activation.antigravityHooks or null;
      hooksScript = if hooksActivation == null then "" else (hooksActivation.data or "");
      hooksAfterPackages = lib.elem "installPackages" (
        if hooksActivation == null then [ ] else (hooksActivation.after or [ ])
      );
      hooksExpected = pkgs.writeText "antigravity-expected-hooks.json" (
        builtins.toJSON {
          remove = [ "orca-orchestration" ];
        }
      );

      hooksAbsent = lib.optionalString (hooksActivation == null) ''
        echo 'missing home.activation.antigravityHooks on ${hostName}' >&2
        failed=1
      '';

      hooksPresent = lib.optionalString (hooksActivation != null) ''
        if [ ${esc (lib.boolToString hooksAfterPackages)} != "true" ]; then
          echo 'home.activation.antigravityHooks must run after installPackages on ${hostName}' >&2
          failed=1
        fi

        if printf '%s' ${esc hooksScript} | grep -v '^[[:space:]]*#' \
          | grep -qE '(\|\|[[:space:]]*(true|:|echo)|;[[:space:]]*true|set \+e)'; then
          echo 'the antigravityHooks activation script must not swallow the merger exit status on ${hostName}' >&2
          failed=1
        fi

        hooksSettingsArg=$(printf '%s' ${esc hooksScript} \
          | tr '\n' ' ' | grep -oE -- '--settings[[:space:]]+[^[:space:]]+' \
          | head -1 | awk '{print $2}' || true)
        if [ "$hooksSettingsArg" != ${esc "${userConfig.home.homeDirectory or ""}/.gemini/config/hooks.json"} ]; then
          echo "the hooks merger must be pointed at ~/.gemini/config/hooks.json on ${hostName}, got: '$hooksSettingsArg'" >&2
          failed=1
        fi

        hooksDeclaredPath=$(printf '%s' ${esc hooksScript} \
          | tr '\n' ' ' | grep -oE -- '--declared[[:space:]]+/nix/store/[^[:space:]]+' \
          | head -1 | awk '{print $2}' || true)
        if [ -z "$hooksDeclaredPath" ]; then
          echo 'the antigravityHooks activation script passes no declared file on ${hostName}' >&2
          failed=1
        elif ! diff -u "$hooksDeclaredPath" ${hooksExpected} >&2; then
          echo 'the declared Antigravity hooks must only remove the retired orca-orchestration entry on ${hostName}' >&2
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
      ${hooksAbsent}${hooksPresent}
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
  ${configurations.guard}
  failed=0
  declaredExpected=${declaredExpected}

  ${lib.concatMapStringsSep "\n" assertHost configurations.entries}

  if [ "$failed" != "0" ]; then
    exit 1
  fi

  touch $out
''
