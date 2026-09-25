/*
  Check interface:

    import ./tests/repo-clones-hosts.nix { pkgs, self }

  Reads the built host outputs, not option values:

  - Production hosts put the packaged repo-clones command, with every @...@
    constant substituted, in the system path. Bootstrap hosts, which have no
    gh/glab tokens to clone with, put neither the command nor its unit there.
  - Production hosts give h82 ghq and a rendered git/config whose ghq.root is
    ~/src, so a hand-run `ghq get` lands where repo-clones clones.

  Every lookup carries an `or` fallback so a mutation that removes a
  declaration reaches the builder as a failing assertion rather than an
  evaluation error. Failures are collected so one red build names them all.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;
  esc = value: lib.escapeShellArg (toString value);

  production = [
    "ThinkPad-X1-Carbon-Gen-11"
    "MS-7D91"
  ];
  bootstrap = map (name: "${name}-bootstrap") production;

  checkProduction =
    name:
    let
      host = self.nixosConfigurations.${name};
      userConfig = host.config.home-manager.users.h82 or { };
    in
    ''
      checkProduction ${esc name} ${esc (host.config.system.path or "")} \
        ${esc (userConfig.home.path or "")} \
        ${esc (userConfig.xdg.configFile."git/config".source or "")}
    '';

  checkBootstrap =
    name:
    let
      host = self.nixosConfigurations.${name};
    in
    ''
      checkBootstrap ${esc name} ${esc (host.config.system.path or "")} \
        ${esc (host.config.system.build.toplevel or "")}
    '';
in
pkgs.runCommand "repo-clones-hosts-tests" { nativeBuildInputs = [ pkgs.git ]; } ''
  failures=$PWD/failures
  : > "$failures"

  checkProduction() (
    host=$1 systemPath=$2 homePath=$3 gitConfig=$4
    fail() { echo "$host: $*" >> "$failures"; }

    helper=$systemPath/bin/repo-clones
    if [ -z "$systemPath" ] || [ ! -x "$helper" ]; then
      fail "repo-clones is not in the system path"
    elif grep -q '@[A-Z]*@' "$helper"; then
      fail "repo-clones still carries an unsubstituted @...@ constant"
    fi

    if [ -z "$homePath" ] || [ ! -x "$homePath/bin/ghq" ]; then
      fail "ghq is not in home.path"
    fi
    if [ -z "$gitConfig" ] || [ ! -f "$gitConfig" ]; then
      fail "home-manager renders no git/config"
    else
      root=$(git config --file "$gitConfig" --get ghq.root || true)
      [ "$root" = "~/src" ] || fail "ghq.root is '$root', want ~/src"
    fi
  )

  checkBootstrap() (
    host=$1 systemPath=$2 toplevel=$3
    fail() { echo "$host: $*" >> "$failures"; }

    if [ -z "$systemPath" ] || [ -z "$toplevel" ]; then
      fail "host outputs are missing"
      exit
    fi
    if [ -e "$systemPath/bin/repo-clones" ]; then
      fail "bootstrap puts repo-clones in the system path"
    fi
    if [ -e "$toplevel/etc/systemd/system/repo-clones.service" ]; then
      fail "bootstrap renders a repo-clones unit"
    fi
  )

  ${lib.concatMapStrings checkProduction production}
  ${lib.concatMapStrings checkBootstrap bootstrap}

  if [ -s "$failures" ]; then
    cat "$failures" >&2
    exit 1
  fi
  touch $out
''
