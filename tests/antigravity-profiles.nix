/*
  Check interface:

    import ./tests/antigravity-profiles.nix { inherit pkgs self fixtures; }

  Asserts that every Home Manager user `tests/lib/configurations.nix` yields
  (NixOS and non-NixOS hosts, production and bootstrap alike) has the
  Antigravity CLI and the Antigravity ACP runtime on PATH, by reading each
  user's built home.path rather than the home.packages option:

  - bin/agy resolves to packages/antigravity-cli.nix, built from its pin;
  - bin/agy_acp_server.par execs the runtime built from
    packages/antigravity-acp-release.json, never T3 Code's pin, and links the
    skills the user's my.agentSkills declares into Compound Engineering run
    homes;
  - bin/localharness_external, beside it, is that runtime's executable helper.

  tests/antigravity-acp-path.nix runs the wrapper itself. macOS users are
  covered by tests/darwin-outputs.nix, which only a macOS builder can build.
  Every lookup carries an `or` fallback so a mutation that removes a package
  reaches the builder as a failing assertion rather than an evaluation error.
*/
{
  pkgs,
  self,
  fixtures,
}:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self fixtures; };

  agy = "${import ../packages/antigravity-cli.nix { inherit pkgs; }}/bin/agy";
  runtimeDir = "${
    import ../packages/antigravity-acp.nix {
      inherit pkgs;
      pins = (builtins.fromJSON (builtins.readFile ../packages/antigravity-acp-release.json)).platforms;
    }
  }/libexec/antigravity-acp";

  esc = value: lib.escapeShellArg (toString value);

  assertEntry =
    entry:
    let
      skills = lib.attrNames (entry.user.my.agentSkills or { });
    in
    ''
      checkUser ${esc entry.name} ${
        esc (entry.user.home.path or "")
      } ${esc "for skill in ${lib.escapeShellArgs skills}; do"}
    '';
in
pkgs.runCommand "antigravity-profiles-tests" { } ''
  ${configurations.userGuard}
  failures=$PWD/failures
  : > "$failures"

  checkUser() (
    user=$1 homePath=$2 skillLoop=$3
    fail() { echo "$user: $*" >> "$failures"; }

    if [ -z "$homePath" ] || [ ! -d "$homePath/bin" ]; then
      fail "home-manager renders no home.path"
      exit
    fi

    [ "$(readlink -f "$homePath/bin/agy" || true)" = ${agy} ] \
      || fail "agy on PATH is not the pinned Antigravity CLI"

    helper=$homePath/bin/localharness_external
    if [ ! -x "$helper" ]; then
      fail "no executable localharness_external beside agy_acp_server.par"
    elif [ "$(readlink -f "$helper")" != ${runtimeDir}/localharness_external ]; then
      fail "localharness_external resolves to $(readlink -f "$helper"), not the PATH-pinned runtime"
    fi

    par=$homePath/bin/agy_acp_server.par
    if [ ! -x "$par" ]; then
      fail "no executable agy_acp_server.par on PATH"
      exit
    fi
    wrapper=$(readlink -f "$par")
    grep -qxF 'exec ${runtimeDir}/agy_acp_server.par "$@"' "$wrapper" \
      || fail "agy_acp_server.par does not exec the PATH-pinned runtime's .par"
    grep -qF -- "$skillLoop" "$wrapper" \
      || fail "agy_acp_server.par does not link the user's agent skills: no '$skillLoop'"
  )

  ${lib.concatMapStringsSep "\n" assertEntry configurations.userEntries}

  if [ -s "$failures" ]; then
    cat "$failures" >&2
    exit 1
  fi
  touch $out
''
