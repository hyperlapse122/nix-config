/*
  Check interface:

    import ./tests/antigravity-acp-path-profiles.nix { inherit pkgs self fixtures; }

  Asserts that the Antigravity ACP runtime is on PATH for Compound
  Engineering's Antigravity route on every Home Manager user
  `tests/lib/configurations.nix` yields (NixOS and non-NixOS hosts, production
  and bootstrap alike), by reading each user's built home.path. The expected
  runtime is the packages/antigravity-acp.nix expression home/h82/t3code.nix
  links into T3 Code's managed layout and tests/t3code-traits.nix compares
  against. tests/antigravity-acp-path.nix runs the wrapper; this check proves
  the profile holds it.

  macOS users are covered by tests/darwin-outputs.nix, which only a macOS
  builder can build.

  Every lookup carries an `or` fallback so a mutation that removes the package
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

  runtimeDir = "${
    import ../packages/antigravity-acp.nix {
      inherit pkgs;
      pins = (builtins.fromJSON (builtins.readFile ../packages/t3code-release.json)).antigravity;
    }
  }/libexec/antigravity-acp";

  esc = value: lib.escapeShellArg (toString value);

  assertEntry = entry: ''
    checkUser ${esc entry.name} ${esc (entry.user.home.path or "")}
  '';
in
pkgs.runCommand "antigravity-acp-path-profiles-tests" { } ''
  ${configurations.userGuard}
  failures=$PWD/failures
  : > "$failures"

  checkUser() (
    user=$1 homePath=$2
    fail() { echo "$user: $*" >> "$failures"; }

    if [ -z "$homePath" ] || [ ! -d "$homePath/bin" ]; then
      fail "home-manager renders no home.path"
      exit
    fi
    par=$homePath/bin/agy_acp_server.par
    helper=$homePath/bin/localharness_external

    if [ ! -x "$helper" ]; then
      fail "no executable localharness_external beside agy_acp_server.par"
    elif [ "$(readlink -f "$helper")" != ${runtimeDir}/localharness_external ]; then
      fail "localharness_external resolves to $(readlink -f "$helper"), not the pinned runtime"
    fi

    if [ ! -x "$par" ]; then
      fail "no executable agy_acp_server.par on PATH"
      exit
    fi
    wrapper=$(readlink -f "$par")
    if ! grep -qxF 'exec ${runtimeDir}/agy_acp_server.par "$@"' "$wrapper"; then
      fail "agy_acp_server.par does not exec the pinned runtime's .par"
    fi
    if ! grep -qF 'export SSL_CERT_FILE=' "$wrapper"; then
      fail "agy_acp_server.par sets no SSL_CERT_FILE default"
    fi
    # System bundles first, so a host's local CAs apply, and nixpkgs' last.
    if ! grep -qE '^ *for bundle in /etc/ssl/certs/ca-certificates\.crt .* /nix/store/[^ ]+-nss-cacert-[^ ]+/etc/ssl/certs/ca-bundle\.crt; do$' "$wrapper"; then
      fail "agy_acp_server.par does not try the system CA bundles before the nixpkgs one"
    fi
  )

  ${lib.concatMapStringsSep "\n" assertEntry configurations.userEntries}

  if [ -s "$failures" ]; then
    cat "$failures" >&2
    exit 1
  fi
  touch $out
''
