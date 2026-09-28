/*
  Check interface:

    import ./tests/mise-settings.nix { inherit pkgs self; }

  Asserts that mise uses precompiled runtime binaries for user `h82` on every
  configuration `tests/lib/configurations.nix` yields, bootstrap outputs
  included. The bootstrap outputs import the same Home Manager profile and the
  setting is meant to reach them too, so they are checked rather than assumed
  identical: a change that gates the profile on `my.bootstrap` fails here.

  On NixOS, mise defaults all_compile to true and builds runtimes from source.
  The build sandbox may not look like NixOS to mise, so comparing the value
  alone could pass without the declaration. The check therefore asks the
  packaged mise which file supplied the setting. Per configuration:

  - home.path carries bin/mise, and it resolves to the upstream release
    packages/mise.nix pins rather than to nixpkgs' mise. The package's own
    versionCheckHook already proves that binary reports the pinned version,
    so the check compares the materialized path instead of re-running it.
  - Home Manager renders mise/conf.d/50-home-manager.toml and leaves
    mise/config.toml unmanaged, so the hand-edited global file stays writable.
  - with that fragment installed under a sandboxed $XDG_CONFIG_HOME,
    `mise settings ls --json-extended` reports all_compile as false, sourced
    from the fragment.

  Every lookup carries an `or` fallback so a mutation that removes a declaration
  reaches the builder as a failing assertion rather than an evaluation error.
  See
  .compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md

  Each configuration runs in a subshell and records failures in a file, so one
  red build names every broken assertion across every configuration. The
  helper's guard runs first, so an empty configuration list fails the build
  instead of passing it.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self; };

  pinnedMise = "${import ../packages/mise.nix { inherit pkgs; }}/bin/mise";

  esc = value: lib.escapeShellArg (toString value);

  assertEntry =
    entry:
    let
      homePath = entry.user.home.path or "";
      configFiles = entry.user.xdg.configFile or { };
      fragment = configFiles."mise/conf.d/50-home-manager.toml".source or "";
      managesGlobal = if configFiles ? "mise/config.toml" then "1" else "0";
    in
    ''
      checkHost ${esc entry.name} ${esc homePath} ${esc fragment} ${esc managesGlobal} ${esc pinnedMise}
    '';
in
pkgs.runCommand "mise-settings-tests" { nativeBuildInputs = [ pkgs.jq ]; } ''
  ${configurations.guard}
  failures=$PWD/failures
  : > "$failures"

  checkHost() (
    host=$1 homePath=$2 fragment=$3 managesGlobal=$4 pinnedMise=$5
    fail() { echo "$host: $*" >> "$failures"; }

    mise=$homePath/bin/mise
    if [ -z "$homePath" ] || [ ! -x "$mise" ]; then
      fail "mise is not in home.path"
      exit
    fi
    resolved=$(readlink -f "$mise")
    [ "$resolved" = "$pinnedMise" ] || fail "bin/mise is '$resolved', expected the pinned upstream release '$pinnedMise'"
    if [ "$managesGlobal" != 0 ]; then
      fail "home-manager manages mise/config.toml; it must stay mutable"
    fi
    if [ -z "$fragment" ] || [ ! -f "$fragment" ]; then
      fail "home-manager renders no mise/conf.d/50-home-manager.toml"
      exit
    fi

    work=$(mktemp -d)
    export HOME=$work/home
    export XDG_CONFIG_HOME=$HOME/.config
    unset MISE_CONFIG_DIR MISE_GLOBAL_CONFIG_FILE MISE_ALL_COMPILE
    installed=$XDG_CONFIG_HOME/mise/conf.d/50-home-manager.toml
    mkdir -p "$(dirname "$installed")" "$HOME/project"
    cp "$fragment" "$installed"
    cd "$HOME/project"

    settings=$("$mise" settings ls --json-extended 2> /dev/null) || {
      fail "mise settings ls exited non-zero"
      exit
    }
    # jq's // treats false as missing, so test for null explicitly.
    value=$(jq -r '.all_compile.value | if . == null then "unset" else tostring end' <<< "$settings")
    source=$(jq -r '.all_compile.source // "unset"' <<< "$settings")
    [ "$value" = false ] || fail "all_compile is '$value', expected 'false'"
    [ "$source" = "$installed" ] || fail "all_compile comes from '$source', expected '$installed'"
  )

  ${lib.concatMapStringsSep "\n" assertEntry configurations.entries}

  if [ -s "$failures" ]; then
    cat "$failures" >&2
    exit 1
  fi

  touch $out
''
