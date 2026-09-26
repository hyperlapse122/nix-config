/*
  Check interface:

    import ./tests/mise-settings.nix { inherit pkgs self; }

  Asserts that mise uses precompiled runtime binaries for user `h82` on the
  ThinkPad and MS-7D91 production configurations. Bootstrap variants import the
  same Home Manager profile, so they add no coverage.

  On NixOS, mise defaults all_compile to true and builds runtimes from source.
  The build sandbox may not look like NixOS to mise, so comparing the value
  alone could pass without the declaration. The check therefore asks the
  packaged mise which file supplied the setting. Per host:

  - home.path carries bin/mise.
  - Home Manager renders mise/conf.d/50-home-manager.toml and leaves
    mise/config.toml unmanaged, so the hand-edited global file stays writable.
  - with that fragment installed under a sandboxed $XDG_CONFIG_HOME,
    `mise settings ls --json-extended` reports all_compile as false, sourced
    from the fragment.

  Every lookup carries an `or` fallback so a mutation that removes a declaration
  reaches the builder as a failing assertion rather than an evaluation error.
  See
  .compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md

  Each host runs in a subshell and records failures in a file, so one red build
  names every broken assertion across both hosts.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  esc = value: lib.escapeShellArg (toString value);

  assertHost =
    hostName: host:
    let
      userConfig = host.config.home-manager.users.h82;
      homePath = userConfig.home.path or "";
      configFiles = userConfig.xdg.configFile or { };
      fragment = configFiles."mise/conf.d/50-home-manager.toml".source or "";
      managesGlobal = if configFiles ? "mise/config.toml" then "1" else "0";
    in
    ''
      checkHost ${esc hostName} ${esc homePath} ${esc fragment} ${esc managesGlobal}
    '';
in
pkgs.runCommand "mise-settings-tests" { nativeBuildInputs = [ pkgs.jq ]; } ''
  failures=$PWD/failures
  : > "$failures"

  checkHost() (
    host=$1 homePath=$2 fragment=$3 managesGlobal=$4
    fail() { echo "$host: $*" >> "$failures"; }

    mise=$homePath/bin/mise
    if [ -z "$homePath" ] || [ ! -x "$mise" ]; then
      fail "mise is not in home.path"
      exit
    fi
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

  ${assertHost "ThinkPad-X1-Carbon-Gen-11" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11}
  ${assertHost "MS-7D91" self.nixosConfigurations.MS-7D91}

  if [ -s "$failures" ]; then
    cat "$failures" >&2
    exit 1
  fi

  touch $out
''
