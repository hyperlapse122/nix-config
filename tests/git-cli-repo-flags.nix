/*
  Check interface:

    import ./tests/git-cli-repo-flags.nix { inherit pkgs; }

  Runs the gh and glab packages the profile installs (home/h82/default.nix)
  the way the shared agent instructions tell an agent to name a repository
  outside a checkout, and asserts that each request goes to the named host and
  repository rather than to github.com, gitlab.com, or the current directory:

    gh pr view 1 --repo HOST/OWNER/REPO
    gh repo view HOST/OWNER/REPO
    GH_REPO=HOST/OWNER/REPO gh api --hostname HOST 'repos/{owner}/{repo}'
    glab mr view 1 --repo https://HOST/GROUP/PROJECT
    glab repo view https://HOST/GROUP/PROJECT
    GITLAB_REPO=https://HOST/GROUP/PROJECT glab api 'projects/:fullpath'

  The build sandbox has no network, so every request fails to resolve its
  host. Each CLI prints the request it was about to send first (GH_DEBUG=api,
  GLAB_DEBUG_HTTP=1), and that is what the check reads. The hosts sit under
  the reserved .invalid zone, the tokens are fake, and HOME is empty, so no
  real configuration or credential takes part. A help-text check would stay
  green while glab sent a bare HOST/OWNER/REPO to gitlab.com, which it does.

  Each output goes to a file first and grep reads that file, so no pipe can
  report a miss when grep stops early. See
  .compound-engineering/artifacts/solutions/logic-errors/printf-pipe-grep-q-under-pipefail-reports-a-miss.md
  Every miss is recorded, so one red build names all of them.
*/
{ pkgs }:
pkgs.runCommand "git-cli-repo-flags" { } ''
  export HOME="$(mktemp -d)"
  export NO_COLOR=1 GH_TOKEN=fake-token GH_ENTERPRISE_TOKEN=fake-token
  export GH_DEBUG=api GLAB_DEBUG_HTTP=1
  failures="$HOME/failures"
  : > "$failures"
  cd "$HOME"

  gh=${pkgs.gh}/bin/gh
  glab=${pkgs.glab}/bin/glab
  ghHost=ghe.invalid
  glHost=gitlab.invalid

  # run <name> <command...>: capture a run that is expected to fail offline
  run() {
    name=$1
    shift
    timeout 60 "$@" > "$HOME/$name" 2>&1 || true
  }

  # expect <name> <fixed string> <description>
  expect() {
    if ! grep -qF -e "$2" "$HOME/$1"; then
      echo "missing: $3" >> "$failures"
      sed 's/^/  | /' "$HOME/$1" >> "$failures"
    fi
  }

  run gh-pr-view "$gh" pr view 1 --repo "$ghHost/owner/repo"
  expect gh-pr-view "Host: $ghHost" "gh pr view --repo HOST/OWNER/REPO does not reach HOST"

  run gh-repo-view "$gh" repo view "$ghHost/owner/repo"
  expect gh-repo-view "Host: $ghHost" "gh repo view HOST/OWNER/REPO does not reach HOST"

  run gh-api env GH_REPO="$ghHost/owner/repo" "$gh" api --hostname "$ghHost" 'repos/{owner}/{repo}'
  expect gh-api "Host: $ghHost" "gh api --hostname HOST does not reach HOST"
  expect gh-api "/repos/owner/repo " "gh api does not fill {owner}/{repo} from GH_REPO"

  run glab-mr-view "$glab" mr view 1 --repo "https://$glHost/group/project"
  expect glab-mr-view "Host: $glHost" "glab mr view --repo FULL_URL does not reach HOST"
  expect glab-mr-view "/projects/group%2Fproject/" "glab mr view --repo FULL_URL does not name the project"

  run glab-repo-view "$glab" repo view "https://$glHost/group/project"
  expect glab-repo-view "Host: $glHost" "glab repo view FULL_URL does not reach HOST"
  expect glab-repo-view "/projects/group%2Fproject" "glab repo view FULL_URL does not name the project"

  run glab-api env GITLAB_REPO="https://$glHost/group/project" "$glab" api 'projects/:fullpath'
  expect glab-api "Host: $glHost" "glab api with GITLAB_REPO=FULL_URL does not reach HOST"
  expect glab-api "/projects/group%2Fproject " "glab api does not fill :fullpath from GITLAB_REPO"

  if [ -s "$failures" ]; then
    cat "$failures" >&2
    exit 1
  fi

  touch $out
''
