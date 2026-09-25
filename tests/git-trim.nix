/*
  Check interface:

    import ./tests/git-trim.nix { inherit pkgs self; }

  Asserts that `git trim` only deletes local branches for user `h82` on the
  ThinkPad and MS-7D91 production configurations. Bootstrap variants import the
  same Home Manager profile, so they add no coverage.

  Upstream git-trim defaults to `--delete merged:origin`, which also deletes
  merged branches on origin. The profile narrows that to `merged-local`, and
  this check proves it by running the packaged binary against a fixture rather
  than matching config text. Per host:

  - home.path carries bin/git-trim.
  - with the rendered git/config installed at $XDG_CONFIG_HOME/git/config, a
    merged tracking branch is deleted locally but survives on the bare origin,
    and an unmerged tracking branch survives in both places.

  git-trim reads trim.* through a vendored libgit2 that only finds global
  config at ~/.gitconfig and $XDG_CONFIG_HOME/git/config; it ignores
  GIT_CONFIG_GLOBAL. The fixture therefore installs the file where Home Manager
  puts it on the hosts, and never passes --delete, which would bypass the
  config under test.

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
      checkHost ${esc hostName} ${esc homePath} ${esc gitConfig} \
        || echo ${esc hostName}": fixture setup failed" >> "$failures"
    '';
in
pkgs.runCommand "git-trim-tests" { nativeBuildInputs = [ pkgs.git ]; } ''
  failures=$PWD/failures
  : > "$failures"

  checkHost() (
    host=$1 homePath=$2 gitConfig=$3
    fail() { echo "$host: $*" >> "$failures"; }

    trim=$homePath/bin/git-trim
    if [ -z "$homePath" ] || [ ! -x "$trim" ]; then
      fail "git-trim is not in home.path"
      exit
    fi
    if [ -z "$gitConfig" ] || [ ! -f "$gitConfig" ]; then
      fail "home-manager renders no git/config"
      exit
    fi

    work=$(mktemp -d)
    export HOME=$work/home
    export XDG_CONFIG_HOME=$HOME/.config
    mkdir -p "$XDG_CONFIG_HOME/git"
    cp "$gitConfig" "$XDG_CONFIG_HOME/git/config"
    # The rendered config signs every commit; the sandbox has no key.
    export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=commit.gpgSign GIT_CONFIG_VALUE_0=false

    git init -q --bare "$work/origin.git"
    git clone -q "$work/origin.git" "$work/clone" 2>/dev/null
    cd "$work/clone"
    git commit -q --allow-empty -m base
    git push -q -u origin main
    git remote set-head origin main

    git switch -q -c feature
    git commit -q --allow-empty -m feature
    git push -q -u origin feature
    git switch -q main
    git merge -q --no-ff -m "merge feature" feature
    git push -q origin main

    git switch -q -c wip
    git commit -q --allow-empty -m wip
    git push -q -u origin wip
    git switch -q main

    if ! "$trim" --no-confirm; then
      fail "git trim exited non-zero"
    fi

    local_has() { git show-ref --verify --quiet "refs/heads/$1"; }
    origin_has() { git --git-dir="$work/origin.git" show-ref --verify --quiet "refs/heads/$1"; }

    local_has feature && fail "merged local branch 'feature' was not deleted"
    origin_has feature || fail "merged branch 'feature' was deleted on origin"
    local_has wip || fail "unmerged local branch 'wip' was deleted"
    origin_has wip || fail "unmerged branch 'wip' was deleted on origin"
    origin_has main || fail "'main' was deleted on origin"
  )

  ${assertHost "ThinkPad-X1-Carbon-Gen-11" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11}
  ${assertHost "MS-7D91" self.nixosConfigurations.MS-7D91}

  if [ -s "$failures" ]; then
    cat "$failures" >&2
    exit 1
  fi

  touch $out
''
