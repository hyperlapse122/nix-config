/*
  Check interface:

    import ./tests/session-variables.nix { inherit pkgs self; }

  Asserts that every configuration renders the Testcontainers, Turborepo, and
  telemetry opt-out session variables into both files that carry the h82
  session environment: the Home Manager hm-session-vars.sh that login shells
  source, and ~/.config/environment.d/10-home-manager.conf that the systemd
  user manager reads.

  Verifies, on every configuration `tests/lib/configurations.nix` yields,
  production and bootstrap alike:
  - the h82 Home Manager generation exists.
  - environment.d/10-home-manager.conf is materialized in the generation's
    home-files, so a disabled or retargeted entry fails here rather than
    passing on its option text.
  - each file carries every expected variable as a whole line, so a longer
    value cannot satisfy the assertion.

  Store paths are interpolated only when the user generation exists, so a
  removed user fails inside the builder rather than during evaluation. The
  builder collects every failure before it exits, so one red build names
  every affected configuration.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self; };

  expectedVariables = {
    TESTCONTAINERS_RYUK_CONTAINER_PRIVILEGED = "true";
    TESTCONTAINERS_RYUK_PRIVILEGED = "true";
    TURBO_ENV_MODE = "loose";
    DOTNET_CLI_TELEMETRY_OPTOUT = "1";
    DOTNET_TELEMETRY_OPTOUT = "1";
    TURBO_TELEMETRY_DISABLED = "1";
    POWERSHELL_TELEMETRY_OPTOUT = "1";
  };

  assertPresent =
    entry:
    let
      environmentFile = "${entry.user.home-files}/.config/environment.d/10-home-manager.conf";
      shellFile = "${entry.user.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
    in
    ''
      if [ ! -f "${environmentFile}" ]; then
        echo "${entry.name}: home-files has no .config/environment.d/10-home-manager.conf" >&2
        failed=1
      fi
    ''
    + lib.concatStrings (
      lib.mapAttrsToList (name: value: ''
        if ! grep -Fxq -- '${name}=${value}' "${environmentFile}"; then
          echo "${entry.name}: environment.d/10-home-manager.conf is missing '${name}=${value}'" >&2
          failed=1
        fi
        if ! grep -Fxq -- 'export ${name}="${value}"' "${shellFile}"; then
          echo "${entry.name}: hm-session-vars.sh is missing 'export ${name}=\"${value}\"'" >&2
          failed=1
        fi
      '') expectedVariables
    );

  assertEntry =
    entry:
    if entry.user ? home-files then
      assertPresent entry
    else
      ''
        echo "${entry.name}: the h82 Home Manager generation is missing" >&2
        failed=1
      '';
in
pkgs.runCommand "session-variables-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
  set -x
  ${configurations.guard}
  failed=0

  ${lib.concatMapStringsSep "\n" assertEntry configurations.entries}

  if [ "$failed" != 0 ]; then
    exit 1
  fi
  touch $out
''
