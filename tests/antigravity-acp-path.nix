/*
  Check interface:

    import ./tests/antigravity-acp-path.nix { inherit pkgs; }

  Runs the Linux agy_acp_server.par wrapper from packages/antigravity-acp-path.nix,
  built against a stub runtime whose .par prints what it was started with. The
  real runtime needs network and a Google sign-in, so its behavior through the
  wrapper is verified by hand (docs/verification.md); this check proves what
  the wrapper itself does. The build sandbox has no /etc/ssl, so the CA bundle
  the runtime gets here is the nixpkgs fallback.

  Expected values come from the stub, never from the wrapper's own Nix
  expression, so a mutation of the wrapper cannot pass by changing both sides.
  Failures are collected and reported together.
*/
{ pkgs }:
let
  # A binary, not a script: the kernel replaces a script's argv[0] with the
  # interpreter, so only a binary can report the argv[0] the wrapper passed.
  stubSource = pkgs.writeText "stub-agy-acp-server.c" ''
    #include <stdio.h>
    #include <stdlib.h>
    #include <unistd.h>

    int main(int argc, char **argv) {
      const char *cert = getenv("SSL_CERT_FILE");
      char line[4096];
      printf("argv0=%s\n", argv[0]);
      printf("pid=%ld\n", (long)getpid());
      printf("cert=%s\n", cert ? cert : "<unset>");
      for (int i = 1; i < argc; i++) printf("arg=%s\n", argv[i]);
      while (fgets(line, sizeof line, stdin)) printf("stdin=%s", line);
      return 0;
    }
  '';

  stubRuntime =
    pkgs.runCommandCC "stub-antigravity-acp"
      {
        version = "0.0.0-stub";
        passthru.pin = {
          executable.name = "agy_acp_server.par";
          harness.name = "localharness_external";
        };
        # The fields packages/antigravity-acp-path.nix copies from the runtime.
        meta = {
          homepage = "https://antigravity.google";
          license = pkgs.lib.licenses.unfree;
          platforms = pkgs.lib.platforms.all;
        };
      }
      ''
        mkdir -p $out/libexec/antigravity-acp
        $CC -o $out/libexec/antigravity-acp/agy_acp_server.par ${stubSource}
        printf 'helper\n' > $out/libexec/antigravity-acp/localharness_external
        chmod 555 $out/libexec/antigravity-acp/localharness_external
      '';

  pathPackage = import ../packages/antigravity-acp-path.nix {
    inherit pkgs;
    runtime = stubRuntime;
  };

  # The sandbox has no /etc/ssl, so the real list always falls through to its
  # last entry. This one proves the wrapper takes the first bundle that exists.
  firstBundle = pkgs.writeText "first-bundle.pem" "first\n";
  secondBundle = pkgs.writeText "second-bundle.pem" "second\n";
  orderedPackage = import ../packages/antigravity-acp-path.nix {
    inherit pkgs;
    runtime = stubRuntime;
    caBundles = [
      "/no-such-dir/bundle.pem"
      "${firstBundle}"
      "${secondBundle}"
    ];
  };
in
pkgs.runCommand "antigravity-acp-path-tests" { } ''
  failures=$PWD/failures
  : > "$failures"
  fail() { echo "$*" >> "$failures"; }

  wrapper=${pathPackage}/bin/agy_acp_server.par
  runtimePar=${stubRuntime}/libexec/antigravity-acp/agy_acp_server.par

  run() {
    case $1 in
      unset) set -- env -i PATH=/no-such-dir ;;
      empty) set -- env -i PATH=/no-such-dir SSL_CERT_FILE= ;;
      *) set -- env -i PATH=/no-such-dir SSL_CERT_FILE="$1" ;;
    esac
    printf 'one line\n' | ${pkgs.bash}/bin/bash -c 'echo "outer=$$"; exec "$@"' run "$@" "$wrapper" --uid= 'a b' 2> stderr
  }

  field() { sed -n "s/^$1=//p" out; }

  for mode in unset empty; do
    run $mode > out || fail "$mode SSL_CERT_FILE: the wrapper exited $?"
    cert=$(field cert)
    if [ -z "$cert" ] || [ "$cert" = '<unset>' ]; then
      fail "$mode SSL_CERT_FILE: the runtime got no CA bundle"
    elif [ ! -f "$cert" ]; then
      fail "$mode SSL_CERT_FILE: the runtime got $cert, which is not a file"
    fi
  done

  printf 'one line\n' | env -i PATH=/no-such-dir ${orderedPackage}/bin/agy_acp_server.par > out \
    || fail "ordered bundles: the wrapper exited $?"
  cert=$(field cert)
  [ "$cert" = ${firstBundle} ] || fail "ordered bundles: the runtime got '$cert', not the first bundle that exists"

  preset=$PWD/preset.pem
  printf 'fixture\n' > "$preset"
  run "$preset" > out || fail "preset SSL_CERT_FILE: the wrapper exited $?"
  cert=$(field cert)
  [ "$cert" = "$preset" ] || fail "preset SSL_CERT_FILE became '$cert'"

  outer=$(field outer)
  [ "$(field pid)" = "$outer" ] || fail "the runtime ran as pid $(field pid), not the wrapper's $outer: the wrapper does not exec"
  [ "$(field argv0)" = "$runtimePar" ] || fail "argv[0] is '$(field argv0)', not $runtimePar"

  expected=$(printf 'arg=--uid=\narg=a b\nstdin=one line')
  actual=$(grep -E '^(arg|stdin)=' out || true)
  [ "$actual" = "$expected" ] || fail "arguments or stdin changed on the way: $actual"
  unexpected=$(grep -vE '^(outer|argv0|pid|cert|arg|stdin)=' out || true)
  [ -z "$unexpected" ] || fail "the wrapper wrote to stdout: $unexpected"
  [ ! -s stderr ] || fail "the wrapper wrote to stderr: $(cat stderr)"

  helper=$(readlink -f ${pathPackage}/bin/localharness_external)
  [ "$helper" = ${stubRuntime}/libexec/antigravity-acp/localharness_external ] \
    || fail "bin/localharness_external resolves to '$helper'"

  if [ -s "$failures" ]; then
    cat "$failures" >&2
    exit 1
  fi
  touch $out
''
