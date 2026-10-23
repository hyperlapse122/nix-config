# The agent-settings declaration for Pi's models.json, built from the two
# committed catalog snapshots. A derivation rather than Nix evaluation over the
# snapshots, so evaluation needs no import-from-derivation for the list of
# OpenRouter models the pinned Pi bundles.
{ pkgs, pi }:
pkgs.runCommand "pi-declared-models.json"
  {
    nativeBuildInputs = [ pkgs.python3 ];
  }
  ''
    # Pi lists its bundled OpenRouter models only when it holds a key, and
    # PI_OFFLINE keeps it from fetching the live catalog.
    export HOME=$TMPDIR/home
    mkdir -p "$HOME"
    PI_OFFLINE=1 OPENROUTER_API_KEY=sk-fake ${pi}/bin/pi --list-models > listed
    awk '$1 == "openrouter" { print $2 }' listed > bundled
    if [ ! -s bundled ]; then
      echo "pi --list-models listed no bundled OpenRouter model" >&2
      exit 1
    fi

    python3 -I ${./pi-declarations.py} \
      ${./synthetic-catalog.json} \
      ${./openrouter-catalog.json} \
      bundled \
      ${pi}/bin/pi-synthetic-key \
      ${pi}/bin/pi-openrouter-key \
      $out
  ''
