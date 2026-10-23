/*
  Check interface:

    import ./tests/pi-extension.nix { inherit pkgs self fixtures; }

  Asserts that the repository's Pi extension behaves as
  tests/pi-extension.test.mjs states and that every Home Manager user
  `tests/lib/configurations.nix` yields, NixOS and non-NixOS Linux,
  production and bootstrap, gets it at ~/.pi/agent/extensions/nix-config with
  the key-file paths of its host kind.

  Verifies:
  - the packaged extension directory holds exactly one regular file, a root
    index.js equal to packages/pi-extension/index.js with only the three
    placeholders replaced by the paths it was given, and imports nothing but
    node:fs/promises: Pi runs it from the store, where no package resolves.
  - the fixture tests pass under node --test against the repository source,
    including the key-file table they run against the extension and
    scripts/pi-provider-key, so the two copies of the key rules cannot drift.
  - per user, exactly one enabled Home Manager file targets
    .pi/agent/extensions/nix-config, found by its resolved `target`, and the
    materialized `home-files` holds that directory with exactly the one
    index.js, carrying /run/secrets/cli-auth on NixOS and the user's
    my.secrets.stateDir elsewhere. See
    .compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md

  Whether Pi loads the directory and the tools reach the model is settled
  only by the live probe in docs/verification.md.

  The expected target and key-file paths are written here, not read from the
  module, so a mutation of the module turns this red. Every lookup carries an
  `or` fallback and each store path is interpolated only inside its present
  branch, so a removed declaration fails inside the builder rather than during
  evaluation. Directory contents are listed with `ls -A`, never a glob,
  because stdenv's nullglob makes a glob that matches nothing vanish. The
  builder collects every failure instead of exiting at the first.
*/
{
  pkgs,
  self,
  fixtures,
}:
let
  inherit (pkgs) lib;

  esc = value: lib.escapeShellArg (toString value);

  target = ".pi/agent/extensions/nix-config";
  source = ../packages/pi-extension/index.js;

  # The repository source with the placeholders replaced by `dir`'s key files.
  expected =
    dir:
    pkgs.writeText "pi-extension-expected-index.js" (
      builtins.replaceStrings
        [ ''"@SYNTHETIC_KEY_FILE@"'' ''"@EXA_KEY_FILE@"'' ''"@OPENROUTER_KEY_FILE@"'' ]
        [ ''"${dir}/synthetic_api_key"'' ''"${dir}/exa_api_key"'' ''"${dir}/openrouter_api_key"'' ]
        (builtins.readFile source)
    );

  fakeDir = "/fake/key-dir";
  packaged = import ../packages/pi-extension.nix {
    inherit pkgs;
    syntheticKeyFile = "${fakeDir}/synthetic_api_key";
    exaKeyFile = "${fakeDir}/exa_api_key";
    openrouterKeyFile = "${fakeDir}/openrouter_api_key";
  };

  configurations = import ./lib/configurations.nix { inherit pkgs self fixtures; };

  # The directory at `dir` holds exactly index.js, byte-identical to `want`.
  onlyIndex = label: dir: want: ''
    if [ ! -d ${dir} ]; then
      echo ${esc "${label} is not a directory"} >&2
      failed=1
    else
      listing=$(ls -A ${dir}/)
      if [ "$listing" != index.js ]; then
        echo ${esc "${label} must hold exactly index.js, got:"} "$listing" >&2
        failed=1
      fi
      if [ ! -f ${dir}/index.js ]; then
        echo ${esc "${label} holds no regular index.js"} >&2
        failed=1
      elif ! cmp -s ${dir}/index.js ${want}; then
        echo ${esc "the index.js of ${label} is not packages/pi-extension/index.js with the expected key-file paths"} >&2
        diff ${want} ${dir}/index.js >&2 || true
        failed=1
      fi
    fi
  '';

  assertEntry =
    entry:
    let
      label = entry.name;
      userConfig = entry.user;
      entries = lib.filter (file: (file.target or "") == target) (
        lib.attrValues (userConfig.home.file or { })
      );
      file = if lib.length entries == 1 then lib.head entries else null;
      homeFiles = userConfig.home-files or null;
      keyDir =
        if entry.kind == "nixos" then "/run/secrets/cli-auth" else userConfig.my.secrets.stateDir or null;
    in
    lib.optionalString (file == null) ''
      echo ${esc "expected 1 home.file for ~/${target} on ${label}, found ${toString (lib.length entries)}"} >&2
      failed=1
    ''
    + lib.optionalString (file != null && !(file.enable or false)) ''
      echo ${esc "home.file for ~/${target} on ${label} is not enabled"} >&2
      failed=1
    ''
    + lib.optionalString (homeFiles == null) ''
      echo ${esc "no materialized home-files on ${label}"} >&2
      failed=1
    ''
    + lib.optionalString (keyDir == null) ''
      echo ${esc "no my.secrets.stateDir on ${label}"} >&2
      failed=1
    ''
    + lib.optionalString (homeFiles != null && keyDir != null) (
      onlyIndex "~/${target} on ${label}" "${homeFiles}/${target}" (expected keyDir)
    );
in
pkgs.runCommand "pi-extension-tests" { nativeBuildInputs = [ pkgs.nodejs ]; } ''
  ${configurations.userGuard}
  failed=0

  ${onlyIndex "the packaged extension" packaged (expected fakeDir)}

  imports=$(grep -E '^[[:space:]]*import[[:space:]{*"]|\bimport[[:space:]]*\(|\brequire[[:space:]]*\(' ${packaged}/index.js || true)
  if [ "$imports" != 'import { readFile } from "node:fs/promises";' ]; then
    echo 'the packaged index.js must import only node:fs/promises; got:' >&2
    echo "$imports" >&2
    failed=1
  fi

  cp ${./pi-extension.test.mjs} test.mjs
  if ! HOME=$TMPDIR EXTENSION=${source} KEY_HELPER=${../scripts/pi-provider-key} node --test test.mjs >&2; then
    echo 'the Pi extension fixture tests failed' >&2
    failed=1
  fi

  ${lib.concatMapStringsSep "\n" assertEntry configurations.userEntries}

  if [ "$failed" != "0" ]; then
    exit 1
  fi
  touch $out
''
