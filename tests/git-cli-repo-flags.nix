/*
  Check interface:

    import ./tests/git-cli-repo-flags.nix { inherit pkgs; }

  Asserts that the gh and glab packages the profile installs
  (home/h82/default.nix) still accept every flag and variable the shared agent
  instructions name for a command run outside a checkout, where the CLI cannot
  read the host and repository from a remote:

    gh pr view --help      lists --repo
    gh api --help          lists --hostname
    gh help environment    lists GH_REPO
    glab mr view --help    lists --repo
    glab api --help        lists --hostname
    glab binary            contains GITLAB_REPO, which no glab help topic
                           documents; the check reads bin/glab and the
                           bin/.glab-wrapped Go binary nixpkgs wraps it around

  Each help text goes to a file first and grep reads that file, so no pipe can
  report a miss when grep stops early. See
  .compound-engineering/artifacts/solutions/logic-errors/printf-pipe-grep-q-under-pipefail-reports-a-miss.md

  A name matches only when no identifier character follows it, so `--repo`
  does not pass on `--repository`. Every missing item is recorded, so one red
  build names all of them, and a help command that exits nonzero still has its
  output inspected.
*/
{ pkgs }:
pkgs.runCommand "git-cli-repo-flags" { } ''
  export HOME="$(mktemp -d)"
  export NO_COLOR=1
  failures="$HOME/failures"
  : > "$failures"

  # help <name> <command...>: capture a help text, tolerating a nonzero exit
  help() {
    name=$1
    shift
    "$@" > "$HOME/$name" 2>&1 || true
  }

  # expect <file> <extended regex> <description>
  expect() {
    if ! grep -qE "$2" "$1"; then
      echo "missing: $3" >> "$failures"
    fi
  }

  help gh-pr-view ${pkgs.gh}/bin/gh pr view --help
  help gh-api ${pkgs.gh}/bin/gh api --help
  help gh-environment ${pkgs.gh}/bin/gh help environment
  help glab-mr-view ${pkgs.glab}/bin/glab mr view --help
  help glab-api ${pkgs.glab}/bin/glab api --help

  flag='(^|[^[:alnum:]_-])--repo([^[:alnum:]_-]|$)'
  host='(^|[^[:alnum:]_-])--hostname([^[:alnum:]_-]|$)'
  expect "$HOME/gh-pr-view" "$flag" "gh pr view --help does not list --repo"
  expect "$HOME/gh-api" "$host" "gh api --help does not list --hostname"
  expect "$HOME/gh-environment" '(^|[^[:alnum:]_])GH_REPO([^[:alnum:]_]|$)' \
    "gh help environment does not list GH_REPO"
  expect "$HOME/glab-mr-view" "$flag" "glab mr view --help does not list --repo"
  expect "$HOME/glab-api" "$host" "glab api --help does not list --hostname"

  # nixpkgs wraps glab, so the Go binary is bin/.glab-wrapped. Go packs string
  # literals back to back, so the match has no trailing boundary.
  found=
  for bin in ${pkgs.glab}/bin/glab ${pkgs.glab}/bin/.glab-wrapped; do
    if [ -e "$bin" ] && grep -a -F -q -e GITLAB_REPO "$bin"; then
      found=1
    fi
  done
  if [ -z "$found" ]; then
    echo "missing: the glab binary does not contain GITLAB_REPO" >> "$failures"
  fi

  if [ -s "$failures" ]; then
    cat "$failures" >&2
    exit 1
  fi

  touch $out
''
