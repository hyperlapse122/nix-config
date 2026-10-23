/*
  Check interface:

    import ./tests/pi-models-load.nix { inherit pkgs self fixtures; }

  Asserts that Pi loads the models.json every Home Manager user environment
  `tests/lib/configurations.nix` yields would write. For each user it takes
  the merger and the declared document from the rendered piModels activation
  script and the pi wrapper from home-path, applies the declaration to an
  empty home with that merger, and runs `pi --list-models` offline with fake
  keys (tests/pi_models_load.py). It fails when Pi reports a models.json
  problem or leaves out a model the declaration names, and when a copy of the
  merged file holding a null maxTokens passes the same test. Users sharing the
  same pi, merger, and declaration are run once.
*/
{
  pkgs,
  self,
  fixtures ? import ./lib/linux-fixtures.nix { inherit (self) inputs; },
}:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self fixtures; };

  esc = value: lib.escapeShellArg (toString value);

  assertEntry =
    entry:
    let
      host' = esc "${entry.name} (${entry.kind})";
      hm = entry.user;
      homePath = hm.home.path or "";
      script = hm.home.activation.piModels.data or "";
    in
    ''
      flat=$(printf '%s' ${esc script} | tr '\n' ' ')
      merger=$(printf '%s' "$flat" \
        | grep -oE -- '/nix/store/[^[:space:]]+/bin/agent-settings' | head -1 || true)
      declared=$(printf '%s' "$flat" \
        | grep -oE -- '--declared[[:space:]]+/nix/store/[^[:space:]]+' | head -1 | awk '{print $2}' || true)
      pi=${esc homePath}/bin/pi
      if [ -z "$merger" ] || [ -z "$declared" ]; then
        fail ${host'}": the piModels activation script names no merger or declared document"
      elif [ ! -x "$pi" ]; then
        fail ${host'}": home-path has no executable bin/pi"
      elif [ -z "''${checked["$pi $merger $declared"]:-}" ]; then
        checked["$pi $merger $declared"]=1
        runs=$((runs + 1))
        if ! output=$(python3 -I ${./pi_models_load.py} "$pi" "$merger" "$declared" "$TMPDIR/work-$runs" 2>&1); then
          fail ${host'}": Pi does not load the declared models.json:"$'\n'"$output"
        fi
      fi
    '';
in
pkgs.runCommand "pi-models-load-tests" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  ${configurations.userGuard}
  failed=0
  fail() {
    echo "$1" >&2
    failed=1
  }
  declare -A checked
  runs=0

  ${lib.concatMapStringsSep "\n" assertEntry configurations.userEntries}

  if [ "$runs" = 0 ]; then
    fail "no user's declared models.json was loaded"
  fi
  if [ "$failed" != 0 ]; then
    exit 1
  fi
  touch $out
''
