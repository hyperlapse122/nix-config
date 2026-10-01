/*
  Check interface:

    import ./tests/codex.nix { inherit pkgs self; }

  Asserts that the Codex declared set reaches user `h82` on every host this
  flake declares, through the shared settings merger in TOML mode.

  The configuration list comes from `tests/lib/configurations.nix`, so a host
  added later is covered the day it is added, and the helper's guard fails the
  build when that list is empty instead of letting it pass.

  Verifies, per host:
  - `home.activation.codexSettings` exists and runs after installPackages, so a
    refusal cannot strand linkGeneration and installPackages behind it.
  - its script invokes the packaged merger with `--format toml`; without the
    flag the merger parses config.toml as JSON and refuses every run.
  - it does not swallow the merger's exit status.
  - `--settings` is exactly ~/.codex/config.toml, read from the flags the
    merger is invoked with rather than from anywhere in the text.
  - the `--declared` store file is identical to the declaration restated as
    literals here, so a dropped or changed key turns this red.
  - no Home Manager file targets ~/.codex/config.toml, which Codex rewrites.

  Every lookup carries an `or` fallback and every conditional block sits behind
  `lib.optionalString`, so a removed declaration fails inside the builder
  rather than during evaluation. See
  .compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md

  The builder collects every failure instead of exiting at the first.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self; };

  esc = value: lib.escapeShellArg (toString value);

  settingsFile = ".codex/config.toml";

  expected = pkgs.writeText "codex-expected-settings.json" (
    builtins.toJSON {
      setPaths = [
        {
          path = [ "check_for_update_on_startup" ];
          value = false;
        }
        {
          path = [
            "features"
            "in_app_updates"
          ];
          value = false;
        }
        {
          path = [
            "features"
            "daemon_auto_start"
          ];
          value = false;
        }
        {
          path = [
            "features"
            "memories"
          ];
          value = false;
        }
      ];
      remove = [ ];
    }
  );

  assertHost =
    entry:
    let
      hostName = entry.name;
      userConfig = entry.user;
      activation = userConfig.home.activation.codexSettings or null;
      script = if activation == null then "" else (activation.data or "");
      runsAfterPackages = lib.elem "installPackages" (
        if activation == null then [ ] else (activation.after or [ ])
      );
      targeted = lib.any (file: (file.target or "") == settingsFile) (
        lib.attrValues (userConfig.home.file or { })
      );

      activationAbsent = lib.optionalString (activation == null) ''
        echo 'missing home.activation.codexSettings on ${hostName}' >&2
        failed=1
      '';

      activationPresent = lib.optionalString (activation != null) ''
        if [ ${esc (lib.boolToString runsAfterPackages)} != "true" ]; then
          echo 'home.activation.codexSettings must run after installPackages on ${hostName}' >&2
          failed=1
        fi

        if ! printf '%s' ${esc script} | grep -qF '/bin/agent-settings'; then
          echo 'the codexSettings activation script must invoke the packaged merger on ${hostName}' >&2
          failed=1
        fi

        formatArg=$(printf '%s' ${esc script} \
          | tr '\n' ' ' | grep -oE -- '--format[[:space:]]+[^[:space:]]+' \
          | head -1 | awk '{print $2}' || true)
        if [ "$formatArg" != toml ]; then
          echo "codexSettings must run the merger with --format toml on ${hostName}, got: '$formatArg'" >&2
          failed=1
        fi

        # Comment lines are stripped first, as in tests/claude.nix, so a comment
        # explaining why the swallow is absent cannot fail the honest script.
        if printf '%s' ${esc script} | grep -v '^[[:space:]]*#' \
          | grep -qE '(\|\|[[:space:]]*(true|:|echo)|;[[:space:]]*true|set \+e)'; then
          echo 'the codexSettings activation script must not swallow the merger exit status on ${hostName}' >&2
          failed=1
        fi

        settingsArg=$(printf '%s' ${esc script} \
          | tr '\n' ' ' | grep -oE -- '--settings[[:space:]]+[^[:space:]]+' \
          | head -1 | awk '{print $2}' || true)
        if [ "$settingsArg" != ${esc "${userConfig.home.homeDirectory or ""}/${settingsFile}"} ]; then
          echo "codexSettings must point the merger at ~/${settingsFile} on ${hostName}, got: '$settingsArg'" >&2
          failed=1
        fi

        declaredPath=$(printf '%s' ${esc script} \
          | tr '\n' ' ' | grep -oE -- '--declared[[:space:]]+/nix/store/[^[:space:]]+' \
          | head -1 | awk '{print $2}' || true)
        if [ -z "$declaredPath" ]; then
          echo 'the codexSettings activation script passes no declared-settings file on ${hostName}' >&2
          failed=1
        elif ! diff -u "$declaredPath" ${expected} >/dev/null; then
          echo 'the declared keys codexSettings renders drifted from the asserted values on ${hostName}' >&2
          failed=1
        fi
      '';
    in
    ''
      ${activationAbsent}${activationPresent}
      if [ ${esc (lib.boolToString targeted)} != "false" ]; then
        echo 'Home Manager must not target ~/${settingsFile} on ${hostName}; Codex owns it' >&2
        failed=1
      fi
    '';
in
pkgs.runCommand "codex-settings-tests" { nativeBuildInputs = [ pkgs.diffutils ]; } ''
  ${configurations.guard}
  failed=0

  ${lib.concatMapStringsSep "\n" assertHost configurations.entries}

  if [ "$failed" != "0" ]; then
    exit 1
  fi

  touch $out
''
