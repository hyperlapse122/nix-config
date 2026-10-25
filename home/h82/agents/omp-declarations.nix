{ pkgs, omp }:
pkgs.runCommand "omp-declared-models.json" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  export HOME=$TMPDIR/home
  mkdir -p "$HOME"
  # The sandbox has no network or real credentials. OMP falls back to its
  # bundled catalog; only the two API providers participate in this render.
  SYNTHETIC_API_KEY=sk-fake-synthetic OPENROUTER_API_KEY=sk-fake-openrouter \
    ${omp}/bin/omp models --json > bundled.json
  python3 -I ${./omp-declarations.py} \
    ${./synthetic-catalog.json} ${./openrouter-catalog.json} bundled.json \
    ${omp}/bin/omp-synthetic-key ${omp}/bin/omp-openrouter-key $out
''
