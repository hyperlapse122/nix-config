/*
  Check interface:

    import ./tests/baloo-extractor.nix { inherit pkgs self; }

  Asserts that the Baloo file extractor starts without a display.

  kde-baloo.service starts before KWin exports WAYLAND_DISPLAY and DISPLAY to
  the user manager, so baloo_file and every baloo_file_extractor it spawns
  run without them. The extractor builds a QGuiApplication, which then falls
  back to wayland-0; KWin 6.8 names its first socket wayland-1, so Qt finds no
  platform and aborts, and baloo_file respawns it in a loop.

  Verifies, on every configuration `tests/lib/configurations.nix` yields,
  production and bootstrap alike, by resolving kde-baloo.service the way the
  user manager does rather than reading the option that renders it:
  - the fragment is /etc/systemd/user/kde-baloo.service when the generation
    ships one, else the one under the system path, and its ExecStart runs
    baloo_file, so a missing, masked, or replaced unit fails.
  - the extractor beside that baloo_file, run with only HOME and the
    Environment= assignments of the fragment and of every drop-in under
    /etc/systemd/user/kde-baloo.service.d, exits 0 on empty input. No
    WAYLAND_DISPLAY or DISPLAY reaches it, as none reaches the service.

  Every failure is collected in one build.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self; };

  esc = value: lib.escapeShellArg (toString value);

  assertEntry =
    entry:
    let
      units = entry.config.environment.etc."systemd/user".source or null;
      packaged = "${entry.config.system.path}/share/systemd/user/kde-baloo.service";
    in
    if units == null then
      ''
        echo ${esc "${entry.name}: the built system declares no /etc/systemd/user tree"} >&2
        failed=1
      ''
    else
      ''
        check_entry ${esc entry.name} ${esc units} ${esc packaged}
      '';
in
pkgs.runCommand "baloo-extractor-tests"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
    ];
  }
  ''
    ${configurations.guard}
    failed=0

    # Prints the Environment= assignments of a unit file, one per line, with
    # an empty Environment= line resetting the list as systemd does.
    environment_of() {
      sed -n 's/^Environment=//p' "$1"
    }

    check_entry() {
      local name=$1 units=$2 packaged=$3
      local fragment="$units/kde-baloo.service"
      [ -e "$fragment" ] || fragment=$packaged

      local exec
      exec=$(sed -n 's/^ExecStart=//p' "$fragment" 2>/dev/null | tail -n 1)
      case "$exec" in
        /*/libexec/kf6/baloo_file) ;;
        *)
          echo "$name: kde-baloo.service is missing, masked, or does not run baloo_file (ExecStart='$exec')" >&2
          failed=1
          return
          ;;
      esac

      local extractor=''${exec%/baloo_file}/baloo_file_extractor
      local -a assignments=()
      local line
      while IFS= read -r line; do
        if [ -z "$line" ]; then
          assignments=()
        else
          eval "assignments+=($line)"
        fi
      done < <(
        environment_of "$fragment"
        for dropin in "$units"/kde-baloo.service.d/*.conf; do
          [ -f "$dropin" ] && environment_of "$dropin"
        done
      )

      local home="$TMPDIR/$name-home"
      mkdir -p "$home"
      local status=0
      timeout 60 env -i HOME="$home" "''${assignments[@]}" "$extractor" </dev/null >"$home/log" 2>&1 || status=$?
      if [ "$status" -ne 0 ]; then
        echo "$name: baloo_file_extractor exits $status without a display under kde-baloo.service's environment (134 is the Qt platform abort):" >&2
        sed 's/^/  /' "$home/log" >&2
        failed=1
      fi
    }

    ${lib.concatMapStringsSep "\n" assertEntry configurations.entries}

    if [ "$failed" -ne 0 ]; then
      exit 1
    fi
    touch $out
  ''
