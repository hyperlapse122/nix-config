/*
  Check interface:

    import ./tests/codex.nix { inherit pkgs self; }

  Runs the pinned Codex package this flake builds and asserts what its wrapper
  and pin promise, from the built binary's own output rather than from the
  wrapper's text:

  - `codex --version` exits 0 and prints the pinned version. The version
    attribute is compared with the pin file for the reason given on the
    claude-code check: versionCheckHook already proves the binary reports that
    attribute.
  - under two different `CODEX_HOME`s, one standing for a T3 Code
    per-provider home whose config.toml never receives the declared keys,
    `codex features list` reports `in_app_updates` and `daemon_auto_start` as
    false. The unwrapped binary beside it reports both as true, so the
    assertion cannot pass on a default that already is false.
  - the wrapper carries `check_for_update_on_startup=false`, which has no
    feature listing to read, so its text is the only place to see it.
  - codex-code-mode-host, which Codex spawns from beside its own executable,
    starts.
  - the bundled model catalog lists `gpt-6.1-sol`, the model the cross-model
    review peer runs.

  The builder collects every failure instead of exiting at the first.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;
  codex = self.packages.${pkgs.stdenv.hostPlatform.system}.codex;
  pinnedVersion = (builtins.fromJSON (builtins.readFile ../packages/codex-release.json)).version;
  flags = [
    "check_for_update_on_startup=false"
    "--disable in_app_updates"
    "--disable daemon_auto_start"
  ];
in
pkgs.runCommand "codex-package-tests" { } ''
  fail=0
  export HOME="$PWD/home"
  mkdir -p "$HOME"
  wrapper=${codex}/bin/codex
  binary=${codex}/libexec/codex/codex

  if ! version=$("$wrapper" --version 2>/dev/null); then
    echo "codex --version did not exit 0" >&2
    fail=1
  fi
  if [ "$version" != "codex-cli ${pinnedVersion}" ]; then
    echo "codex --version printed '$version', expected 'codex-cli ${pinnedVersion}'" >&2
    fail=1
  fi

  for home in "$PWD/default-home" "$PWD/provider-home"; do
    mkdir -p "$home"
    listing=$(CODEX_HOME="$home" "$wrapper" features list 2>/dev/null) || {
      echo "codex features list failed under $home" >&2
      fail=1
    }
    for feature in in_app_updates daemon_auto_start; do
      if ! grep -Eq "^$feature +[a-z ]*false$" <<< "$listing"; then
        echo "the wrapper leaves $feature enabled under CODEX_HOME=$home" >&2
        fail=1
      fi
    done
  done

  raw=$(CODEX_HOME="$PWD/default-home" "$binary" features list 2>/dev/null) || true
  for feature in in_app_updates daemon_auto_start; do
    if ! grep -Eq "^$feature +[a-z ]*true$" <<< "$raw"; then
      echo "the unwrapped binary does not enable $feature, so the wrapper assertion proves nothing" >&2
      fail=1
    fi
  done

  for flag in ${lib.escapeShellArgs flags}; do
    if ! grep -qF -- "$flag" "$wrapper"; then
      echo "the codex wrapper lacks $flag" >&2
      fail=1
    fi
  done

  if ! ${codex}/libexec/codex/codex-code-mode-host --help > /dev/null 2>&1; then
    echo "codex-code-mode-host does not start" >&2
    fail=1
  fi

  models=$(CODEX_HOME="$PWD/default-home" "$wrapper" debug models 2>/dev/null) || {
    echo "codex debug models failed" >&2
    fail=1
  }
  if ! grep -qF '"slug":"gpt-6.1-sol"' <<< "$models"; then
    echo "the codex model catalog does not list gpt-6.1-sol" >&2
    fail=1
  fi

  [ "$fail" -eq 0 ]
  touch $out
''
