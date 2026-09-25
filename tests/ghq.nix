/*
  Check interface:

    import ./tests/ghq.nix { inherit pkgs self; }

  Asserts that ghq organizes repositories under ~/src for user `h82` on the
  ThinkPad and MS-7D91 production configurations. Bootstrap variants import the
  same Home Manager profile, so they add no coverage.

  ghq reads its root with `git config --path ghq.root`, so this check runs the
  packaged binary against the rendered Git config rather than matching config
  text. Per host:

  - home.path carries bin/ghq.
  - with the rendered git/config installed at $XDG_CONFIG_HOME/git/config,
    `ghq root` prints $HOME/src, not ghq's ~/ghq default.
  - `ghq create github.com/example/project` initializes the repository at
    $HOME/src/github.com/example/project, and `ghq list --full-path` reports it.

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
      gitConfig = userConfig.xdg.configFile."git/config".source or "";
    in
    ''
      checkHost ${esc hostName} ${esc homePath} ${esc gitConfig}
    '';
in
pkgs.runCommand "ghq-tests" { nativeBuildInputs = [ pkgs.git ]; } ''
  failures=$PWD/failures
  : > "$failures"

  checkHost() (
    host=$1 homePath=$2 gitConfig=$3
    fail() { echo "$host: $*" >> "$failures"; }

    ghq=$homePath/bin/ghq
    if [ -z "$homePath" ] || [ ! -x "$ghq" ]; then
      fail "ghq is not in home.path"
      exit
    fi
    if [ -z "$gitConfig" ] || [ ! -f "$gitConfig" ]; then
      fail "home-manager renders no git/config"
      exit
    fi

    work=$(mktemp -d)
    export HOME=$work/home
    export XDG_CONFIG_HOME=$HOME/.config
    unset GHQ_ROOT
    mkdir -p "$XDG_CONFIG_HOME/git"
    cp "$gitConfig" "$XDG_CONFIG_HOME/git/config"

    root=$("$ghq" root) || fail "ghq root exited non-zero"
    [ "$root" = "$HOME/src" ] || fail "ghq root is '$root', expected '$HOME/src'"

    project=$HOME/src/github.com/example/project
    "$ghq" create github.com/example/project > /dev/null 2>&1 || fail "ghq create exited non-zero"
    [ -d "$project/.git" ] || fail "ghq create did not initialize $project"
    listed=$("$ghq" list --full-path || true)
    [ "$listed" = "$project" ] || fail "ghq list reports '$listed', expected '$project'"
  )

  ${assertHost "ThinkPad-X1-Carbon-Gen-11" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11}
  ${assertHost "MS-7D91" self.nixosConfigurations.MS-7D91}

  if [ -s "$failures" ]; then
    cat "$failures" >&2
    exit 1
  fi

  touch $out
''
