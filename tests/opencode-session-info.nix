/*
  Check interface:

    import ./tests/opencode-session-info.nix { inherit pkgs self fixtures; }

  Asserts that the session-info OpenCode plugin behaves as
  tests/opencode-session-info.test.mjs states and that every Home Manager
  user `tests/lib/configurations.nix` yields, NixOS and non-NixOS Linux,
  production and bootstrap, gets it at ~/.config/opencode/plugins/session-info.

  Verifies:
  - the packaged plugin directory holds exactly one regular file, a root
    index.js byte-identical to packages/opencode-session-info/index.js, with
    no import or require: OpenCode runs it from the store, where no package
    resolves, and skips a plugin directory without a root index.js silently.
  - the fixture tests pass against the packaged index.js, under node --test.
  - per user, exactly one enabled Home Manager file targets
    .config/opencode/plugins/session-info, found by its resolved `target`,
    and the materialized `home-files` holds that directory with exactly the
    one index.js, byte-identical to the repository's. See
    .compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md

  Whether OpenCode loads the directory and the hook fires is settled only by
  the live run in docs/verification.md: OpenCode does not start inside a
  build sandbox. See
  .compound-engineering/artifacts/solutions/integration-issues/opencode-plugin-loading-verifiable-only-by-a-live-run.md

  The expected target and source are written here, not read from the module,
  so a mutation of the module turns this red. Every lookup carries an `or`
  fallback and each store path is interpolated only inside its present
  branch, so a removed declaration fails inside the builder rather than
  during evaluation. Directory contents are listed with `ls -A`, never a
  glob, because stdenv's nullglob makes a glob that matches nothing vanish.
  The builder collects every failure instead of exiting at the first.
*/
{
  pkgs,
  self,
  fixtures,
}:
let
  inherit (pkgs) lib;

  esc = value: lib.escapeShellArg (toString value);

  target = ".config/opencode/plugins/session-info";
  source = ../packages/opencode-session-info/index.js;
  plugin = import ../packages/opencode-session-info.nix { inherit pkgs; };

  configurations = import ./lib/configurations.nix { inherit pkgs self fixtures; };

  # The directory at `dir` holds exactly index.js, byte-identical to the
  # repository's.
  onlyIndex = label: dir: ''
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
      elif ! cmp -s ${dir}/index.js ${source}; then
        echo ${esc "the index.js of ${label} differs from packages/opencode-session-info/index.js"} >&2
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
    + lib.optionalString (homeFiles != null) (
      onlyIndex "~/${target} on ${label}" "${homeFiles}/${target}"
    );
in
pkgs.runCommand "opencode-session-info-tests" { nativeBuildInputs = [ pkgs.nodejs ]; } ''
  ${configurations.userGuard}
  failed=0

  ${onlyIndex "the packaged plugin" plugin}

  if grep -nE '^[[:space:]]*import[[:space:]{*"]|\bimport[[:space:]]*\(|\brequire[[:space:]]*\(' ${plugin}/index.js >&2; then
    echo 'the packaged index.js imports a module; OpenCode resolves none from the store' >&2
    failed=1
  fi

  cp ${./opencode-session-info.test.mjs} test.mjs
  if ! HOME=$TMPDIR PLUGIN=${plugin}/index.js node --test test.mjs >&2; then
    echo 'the session-info fixture tests failed' >&2
    failed=1
  fi

  ${lib.concatMapStringsSep "\n" assertEntry configurations.userEntries}

  if [ "$failed" != "0" ]; then
    exit 1
  fi
  touch $out
''
