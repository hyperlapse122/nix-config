#!/usr/bin/env bash
set -euo pipefail

script=${1:-}
if [[ $# -ne 1 || -z $script || ! -f $script ]]; then
  printf 'usage: %s NR_SCRIPT\n' "${0##*/}" >&2
  exit 2
fi
script=$(cd -- "$(dirname -- "$script")" && pwd -P)/$(basename -- "$script")

scratch=$(mktemp -d "${TMPDIR:-/tmp}/nr-tests.XXXXXX")
trap 'rm -rf -- "$scratch"' EXIT

fail() { printf 'nr: FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'nr: ok - %s\n' "$*"; }

git_bin=$(command -v git) || fail 'git is required'
# The production script reaches git and nvd through substituted store paths;
# the unbuilt source still carries the @...@ placeholders, so render a copy.
rendered=$scratch/nr
sed -e "s|@GIT@|$git_bin|" -e "s|@NVD@|/nonexistent/nvd|" "$script" >"$rendered"
chmod +x "$rendered"

export NR_DRY_RUN=1

make_repo() {
  local dir=$1
  mkdir -p "$dir"
  "$git_bin" -C "$dir" init -q
  "$git_bin" -C "$dir" config user.email t@example.invalid
  "$git_bin" -C "$dir" config user.name Test
  printf '{}\n' >"$dir/flake.nix"
  "$git_bin" -C "$dir" add flake.nix
  "$git_bin" -C "$dir" commit -qm init
}

repo=$scratch/repo
make_repo "$repo"

# --- resolution ------------------------------------------------------------

out=$("$rendered" build --flake-dir "$repo" --host testhost 2>/dev/null)
[[ $out == *"$repo#nixosConfigurations.testhost.config.system.build.toplevel"* ]] ||
  fail "build did not resolve the flake reference: $out"
pass 'build resolves the flake reference from --flake-dir and --host'

out=$("$rendered" switch --flake-dir "$repo" --host other-host 2>/dev/null)
[[ $out == *"$repo#other-host"* ]] || fail "--host override ignored: $out"
pass '--host overrides the detected hostname'

detected=$(uname -n)
out=$("$rendered" switch --flake-dir "$repo" 2>/dev/null)
[[ $out == *"$repo#$detected"* ]] || fail "hostname default not used: $out"
pass 'the target defaults to the running hostname'

# --- flake directory resolution -------------------------------------------

nonrepo=$scratch/plain
mkdir -p "$nonrepo"
if (cd "$nonrepo" && "$rendered" build >/dev/null 2>&1); then
  fail 'running outside a git repository should fail'
fi
err=$( (cd "$nonrepo" && "$rendered" build 2>&1 >/dev/null) || true)
[[ $err == *--flake-dir* ]] || fail "failure outside a repo does not name --flake-dir: $err"
pass 'outside a git repository it fails and names --flake-dir'

noflake=$scratch/noflake
make_repo "$noflake"
rm -f "$noflake/flake.nix"
err=$( (cd "$noflake" && "$rendered" build 2>&1 >/dev/null) || true)
[[ $err == *--flake-dir* ]] || fail "repo without flake.nix does not name --flake-dir: $err"
pass 'a git repository with no flake.nix fails and names --flake-dir'

# --- untracked warning -----------------------------------------------------

err=$("$rendered" build --flake-dir "$repo" --host testhost 2>&1 >/dev/null)
[[ -z $err ]] || fail "clean tree still warned: $err"
pass 'a clean tree produces no untracked warning'

printf 'x\n' >"$repo/new-module.nix"
err=$("$rendered" build --flake-dir "$repo" --host testhost 2>&1 >/dev/null)
[[ $err == *new-module.nix* ]] || fail "untracked file not reported: $err"
out=$("$rendered" build --flake-dir "$repo" --host testhost 2>/dev/null)
[[ $out == *nixosConfigurations* ]] || fail 'untracked warning aborted the run'
pass 'an untracked file is named on stderr and the run continues'
rm -f "$repo/new-module.nix"

# --- host-variant marker ---------------------------------------------------

marker=$scratch/variant
printf 'bootstrap\n' >"$marker"
export NR_VARIANT_FILE=$marker

for sub in switch boot test; do
  if "$rendered" "$sub" --flake-dir "$repo" >/dev/null 2>&1; then
    fail "$sub on a bootstrap generation should refuse without --host"
  fi
  err=$("$rendered" "$sub" --flake-dir "$repo" 2>&1 >/dev/null || true)
  [[ $err == *--host* ]] || fail "$sub refusal does not name --host: $err"
done
pass 'switch, boot and test refuse on a bootstrap generation without --host'

out=$("$rendered" switch --flake-dir "$repo" --host explicit 2>/dev/null)
[[ $out == *"$repo#explicit"* ]] || fail "explicit --host still refused: $out"
pass 'an explicit --host proceeds on a bootstrap generation'

out=$("$rendered" build --flake-dir "$repo" 2>/dev/null)
[[ $out == *nixosConfigurations* ]] || fail 'unprivileged build was refused'
pass 'build is unaffected by the bootstrap marker'

printf 'production\n' >"$marker"
out=$("$rendered" switch --flake-dir "$repo" 2>/dev/null)
[[ $out == *"$repo#"* ]] || fail 'production marker blocked the run'
pass 'a production marker does not stop the run'

export NR_VARIANT_FILE=$scratch/absent-marker
out=$("$rendered" switch --flake-dir "$repo" 2>/dev/null)
[[ $out == *"$repo#"* ]] || fail 'absent marker blocked the run'
pass 'an absent marker does not stop the run'

# --- generation diff target ------------------------------------------------

out=$("$rendered" switch --flake-dir "$repo" --host testhost 2>/dev/null)
[[ $out == *"diff-target: /run/current-system"* ]] ||
  fail "switch does not diff against /run/current-system: $out"
out=$("$rendered" test --flake-dir "$repo" --host testhost 2>/dev/null)
[[ $out == *"diff-target: /run/current-system"* ]] ||
  fail "test does not diff against /run/current-system: $out"
pass 'switch and test diff against /run/current-system'

out=$("$rendered" boot --flake-dir "$repo" --host testhost 2>/dev/null)
[[ $out == *"diff-target: /nix/var/nix/profiles/system"* ]] ||
  fail "boot does not diff against the system profile: $out"
pass 'boot diffs against /nix/var/nix/profiles/system, which it actually updates'

# --- usage -----------------------------------------------------------------

if "$rendered" frobnicate --flake-dir "$repo" >/dev/null 2>&1; then
  fail 'an unknown subcommand should fail'
fi
err=$("$rendered" frobnicate --flake-dir "$repo" 2>&1 >/dev/null || true)
[[ $err == *"unknown subcommand"* ]] || fail "unknown subcommand message missing: $err"
pass 'an unknown subcommand exits non-zero with usage'

printf 'nr: all checks passed\n'
