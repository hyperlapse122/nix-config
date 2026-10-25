{ pkgs, self }:

let
  inherit (pkgs) lib stdenv;
  omp = self.packages.${stdenv.hostPlatform.system}.omp;
  pin = builtins.fromJSON (builtins.readFile ../packages/omp-release.json);
in
pkgs.runCommand "omp-package-tests"
  {
    nativeBuildInputs = lib.optional stdenv.hostPlatform.isLinux pkgs.patchelf;
  }
  ''
    export HOME="$PWD/home"
    mkdir -p "$HOME" work
    cd work
    wrapper=${omp}/bin/omp
    binary=${omp}/libexec/omp/omp

    version=$("$wrapper" --version)
    test "$version" = ${lib.escapeShellArg "omp/${pin.version}"}
    "$wrapper" --help > /dev/null

    # Enter print mode without credentials or a network request. The expected
    # model-resolution failure proves the bundled application starts headlessly.
    if "$wrapper" --no-extensions --no-session \
      --model u1-nonexistent-provider/u1-nonexistent-model -p smoke > stdout 2> stderr; then
      echo "omp unexpectedly accepted the nonexistent smoke-test model" >&2
      exit 1
    fi
    grep -F 'Model "u1-nonexistent-provider/u1-nonexistent-model" not found' stderr

    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      test "$(patchelf --print-interpreter "$binary")" = ${lib.escapeShellArg stdenv.cc.bintools.dynamicLinker}
    ''}
    ${lib.optionalString stdenv.hostPlatform.isDarwin ''
      # A byte-identical installed executable preserves the upstream signature.
      cmp ${omp.src} "$binary"
    ''}
    touch $out
  ''
