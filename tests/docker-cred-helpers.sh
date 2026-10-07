#!/usr/bin/env bash
# Usage: bash tests/docker-cred-helpers.sh <docker-cred-helpers executable>
#
# Runs the macOS credHelpers merge against throwaway HOME directories: a
# missing config is created with every helper, an OrbStack config keeps its
# other keys and helpers, a second run leaves the file byte-identical, and a
# config that is not valid JSON is left untouched without failing.
set -euo pipefail

merge=$1
helpers='{"ghcr.io":"sops","https://index.docker.io/v1/":"sops","registry.gitlab.com":"sops","registry.jpi.app":"sops"}'
fail=0
bad() { echo "docker-cred-helpers: $*" >&2; fail=1; }

expect_helpers() {
  local file=$1 key
  for key in ghcr.io https://index.docker.io/v1/ registry.gitlab.com registry.jpi.app; do
    [ "$(jq -r --arg k "$key" '.credHelpers[$k] // empty' "$file")" = sops ] \
      || bad "$file: credHelpers lacks $key -> sops"
  done
}

home=$(mktemp -d)
HOME=$home "$merge" "$helpers"
expect_helpers "$home/.docker/config.json"
[ "$(stat -c %a "$home/.docker/config.json")" = 600 ] || bad "a new config is not mode 0600"

home=$(mktemp -d)
mkdir -p "$home/.docker"
printf '%s\n' '{"currentContext":"orbstack","credHelpers":{"other.io":"x"}}' > "$home/.docker/config.json"
HOME=$home "$merge" "$helpers"
expect_helpers "$home/.docker/config.json"
[ "$(jq -r .currentContext "$home/.docker/config.json")" = orbstack ] || bad "currentContext was not kept"
[ "$(jq -r '.credHelpers["other.io"]' "$home/.docker/config.json")" = x ] || bad "an unrelated helper was dropped"
cp "$home/.docker/config.json" "$home/first.json"
HOME=$home "$merge" "$helpers"
cmp -s "$home/first.json" "$home/.docker/config.json" || bad "a second run changed the file"

home=$(mktemp -d)
mkdir -p "$home/.docker"
printf 'not json' > "$home/.docker/config.json"
if ! HOME=$home "$merge" "$helpers" 2>/dev/null; then bad "invalid JSON failed the merge"; fi
[ "$(cat "$home/.docker/config.json")" = 'not json' ] || bad "invalid JSON was overwritten"

[ "$fail" = 0 ] || exit 1
echo "docker-cred-helpers: all scenarios passed"
