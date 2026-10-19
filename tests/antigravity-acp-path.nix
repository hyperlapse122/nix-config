/*
  Check interface:

    import ./tests/antigravity-acp-path.nix { inherit pkgs; pluginSource = inputs.compound-engineering-plugin; }

  Runs the Linux agy_acp_server.par wrapper from packages/antigravity-acp-path.nix,
  built against a stub runtime whose .par prints what it was started with. The
  real runtime needs network and a Google sign-in, so its behavior through the
  wrapper is verified by hand (docs/verification.md); this check proves what
  the wrapper itself does, and that the pinned Compound Engineering plugin
  still creates its scratch Antigravity homes under the five template prefixes
  the wrapper recognizes. The build sandbox has no /etc/ssl, so the CA bundle
  the runtime gets here is the nixpkgs fallback.

  Expected values come from the stub and test fixtures, never from the wrapper's
  own Nix expression, so a mutation of the wrapper cannot pass by changing both
  sides. Failures are collected and reported together.
*/
{
  pkgs,
  pluginSource ? null,
}:
let
  inherit (pkgs) lib;
  pluginDir = if pluginSource == null then "" else toString pluginSource;

  # A binary, not a script: the kernel replaces a script's argv[0] with the
  # interpreter, so only a binary can report the argv[0] the wrapper passed.
  stubSource = pkgs.writeText "stub-agy-acp-server.c" ''
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include <sys/stat.h>
    #include <unistd.h>

    int main(int argc, char **argv) {
      const char *cert = getenv("SSL_CERT_FILE");
      const char *home = getenv("GEMINI_HOME");
      char line[4096];
      printf("argv0=%s\n", argv[0]);
      printf("pid=%ld\n", (long)getpid());
      printf("cert=%s\n", cert ? cert : "<unset>");
      if (home && *home) {
        char path[4096];
        struct stat st;
        snprintf(path, sizeof path, "%s/antigravity-acp/acp_token.json", home);
        if (lstat(path, &st) == 0 && S_ISREG(st.st_mode)) {
          FILE *f = fopen(path, "r");
          if (f) {
            char tok[4096] = {0};
            size_t n = fread(tok, 1, sizeof tok - 1, f);
            while (n > 0 && (tok[n - 1] == '\n' || tok[n - 1] == '\r')) tok[--n] = '\0';
            printf("token=%s\n", tok);
            printf("tokenmode=%o\n", (unsigned)(st.st_mode & 07777));
            fclose(f);
          } else {
            printf("token=<unreadable>\n");
          }
        } else {
          printf("token=<none>\n");
        }
      } else {
        printf("token=<none>\n");
      }
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

  # Guard against drift in Compound Engineering's acpx_antigravity_home layout
  # and mktemp -d scratch prefixes.
  pluginDir=${lib.escapeShellArg pluginDir}
  if [ -z "$pluginDir" ] || [ ! -d "$pluginDir/skills" ]; then
    fail "compound-engineering-plugin source not passed to antigravity-acp-path check"
  else
    pluginPrefixes=$(
      for script in "$pluginDir"/skills/*/scripts/*.sh; do
        grep -qF 'acpx_antigravity_home' "$script" || continue
        grep -qF 'local home="$1/gemini-home"' "$script" \
          || fail "$script: acpx_antigravity_home no longer uses \$1/gemini-home"
        grep -qF 'mkdir -p "$home/antigravity-acp"' "$script" \
          || fail "$script: acpx_antigravity_home no longer creates \$home/antigravity-acp"
        vars=$(sed -n 's/.*acpx_antigravity_home "\$\([A-Za-z0-9_]*\)".*/\1/p' "$script")
        [ -n "$vars" ] || fail "$script: no acpx_antigravity_home \"\$VAR\" call matched"
        for var in $vars; do
          prefix=$(sed -n "s/.*''${var}=\"\$(mktemp -d \"[^\"]*\\/\\([a-z0-9-]*\\)-XXXXXX\")\".*/\\1/p" "$script")
          [ -n "$prefix" ] || fail "$script: could not read mktemp -d prefix for \$$var"
          printf '%s\n' "$prefix"
        done
      done | sort -u | tr '\n' ' '
    )
    expectedPrefixes='ce-work-adapter ce-work-model-check xmodel-cr-scratch xmodel-doc-scratch xmodel-pov-peer '
    [ "$pluginPrefixes" = "$expectedPrefixes" ] \
      || fail "compound-engineering scratch prefixes drifted: got '$pluginPrefixes', expected '$expectedPrefixes'"
  fi

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
  unexpected=$(grep -vE '^(outer|argv0|pid|cert|token|tokenmode|arg|stdin)=' out || true)
  [ -z "$unexpected" ] || fail "the wrapper wrote to stdout: $unexpected"
  [ ! -s stderr ] || fail "the wrapper wrote to stderr: $(cat stderr)"

  helper=$(readlink -f ${pathPackage}/bin/localharness_external)
  [ "$helper" = ${stubRuntime}/libexec/antigravity-acp/localharness_external ] \
    || fail "bin/localharness_external resolves to '$helper'"

  # Seeding scenarios.
  tmpdir=$PWD/tmp
  mkdir -p "$tmpdir"
  chmod 700 "$tmpdir"

  fakeHome=$PWD/fake-home
  sourceToken=$fakeHome/.gemini/antigravity-acp/acp_token.json
  expectedToken='{"fake":"source-token"}'
  expectedSettings='{"selectedAuthType":"oauth-personal"}'
  expectedStderr='agy_acp_server.par: could not copy the ~/.gemini sign-in into GEMINI_HOME'
  mkdir -p "$fakeHome/.gemini/antigravity-acp"
  printf '%s\n' "$expectedToken" > "$sourceToken"
  chmod 600 "$sourceToken"

  make_ce_home() {
    local parent
    case $1 in
      *XXXXXX) parent=$(mktemp -d "$1") ;;
      *) parent=$1; mkdir -p "$parent"; chmod 700 "$parent" ;;
    esac
    mkdir -p "$parent/gemini-home/antigravity-acp"
    printf '%s\n' "$expectedSettings" > "$parent/gemini-home/antigravity-acp/settings.json"
    printf '%s\n' "$parent/gemini-home"
  }

  check_invariants() {
    local label=$1
    local srcContent srcMode unexpectedOut strayTmp
    srcContent=$(cat "$sourceToken" 2>/dev/null || true)
    srcMode=$(stat -c %a "$sourceToken" 2>/dev/null || true)
    [ "$srcContent" = "$expectedToken" ] || fail "$label: source token contents changed to '$srcContent'"
    [ "$srcMode" = 600 ] || fail "$label: source token mode changed to '$srcMode'"
    unexpectedOut=$(grep -vE '^(outer|argv0|pid|cert|token|tokenmode|arg|stdin)=' out || true)
    [ -z "$unexpectedOut" ] || fail "$label: wrapper wrote to stdout: $unexpectedOut"
    strayTmp=$(find "$tmpdir" -name '.acp_token.*' 2>/dev/null || true)
    [ -z "$strayTmp" ] || fail "$label: temporary staging file left behind: $strayTmp"
  }

  run_seed() {
    local label=$1
    shift
    printf 'one line\n' | env -i PATH=/no-such-dir "$@" "$wrapper" > out 2> stderr \
      || fail "$label: wrapper exited $?"
    check_invariants "$label"
  }

  # 1. Home under xmodel-cr-scratch-abc123: runtime sees fake token, mode 600 (AE1).
  ce1=$(make_ce_home "$tmpdir/xmodel-cr-scratch-abc123")
  run_seed "xmodel-cr-scratch-abc123" TMPDIR="$tmpdir" HOME="$fakeHome" GEMINI_HOME="$ce1"
  [ "$(field token)" = "$expectedToken" ] || fail "xmodel-cr-scratch-abc123: runtime got token '$(field token)'"
  [ "$(field tokenmode)" = 600 ] || fail "xmodel-cr-scratch-abc123: token mode is '$(field tokenmode)', not 600"
  [ "$(cat "$ce1/antigravity-acp/settings.json")" = "$expectedSettings" ] || fail "xmodel-cr-scratch-abc123: settings.json changed"
  [ ! -s stderr ] || fail "xmodel-cr-scratch-abc123: unexpected stderr: $(cat stderr)"

  # 2. Same for the other four templates (built with mktemp -d).
  for prefix in xmodel-doc-scratch xmodel-pov-peer ce-work-model-check ce-work-adapter; do
    ce=$(make_ce_home "$tmpdir/$prefix-XXXXXX")
    run_seed "$prefix" TMPDIR="$tmpdir" HOME="$fakeHome" GEMINI_HOME="$ce"
    [ "$(field token)" = "$expectedToken" ] || fail "$prefix: runtime got token '$(field token)'"
    [ "$(field tokenmode)" = 600 ] || fail "$prefix: token mode is '$(field tokenmode)', not 600"
    [ "$(cat "$ce/antigravity-acp/settings.json")" = "$expectedSettings" ] || fail "$prefix: settings.json changed"
    [ ! -s stderr ] || fail "$prefix: unexpected stderr: $(cat stderr)"
  done

  # 3. Redundant slashes before gemini-home and trailing slashes on GEMINI_HOME: token seen.
  slashTmp=$PWD/tmp-slash
  mkdir -p "$slashTmp"
  chmod 700 "$slashTmp"
  ce3=$(make_ce_home "$slashTmp/xmodel-cr-scratch-abc123")
  ce3Double="$slashTmp//xmodel-cr-scratch-abc123//gemini-home"
  run_seed "TMPDIR trailing slash" TMPDIR="$slashTmp/" HOME="$fakeHome" GEMINI_HOME="$ce3Double"
  [ "$(field token)" = "$expectedToken" ] || fail "TMPDIR trailing slash: runtime got token '$(field token)'"
  [ "$(field tokenmode)" = 600 ] || fail "TMPDIR trailing slash: token mode is '$(field tokenmode)', not 600"
  [ ! -s stderr ] || fail "TMPDIR trailing slash: unexpected stderr: $(cat stderr)"

  ce3b=$(make_ce_home "$slashTmp/xmodel-cr-scratch-def456")
  run_seed "GEMINI_HOME trailing slash" TMPDIR="$slashTmp" HOME="$fakeHome" GEMINI_HOME="$ce3b/"
  [ "$(field token)" = "$expectedToken" ] || fail "GEMINI_HOME trailing slash: runtime got token '$(field token)'"
  [ "$(field tokenmode)" = 600 ] || fail "GEMINI_HOME trailing slash: token mode is '$(field tokenmode)', not 600"
  [ ! -s stderr ] || fail "GEMINI_HOME trailing slash: unexpected stderr: $(cat stderr)"

  # 4. ce-pov style: home under a nested scratch parent, not directly in TMPDIR: token seen.
  nestedParent=$(mktemp -d "$tmpdir/pov-outer-XXXXXX")
  ce4=$(make_ce_home "$nestedParent/xmodel-pov-peer-XXXXXX")
  run_seed "nested scratch parent" TMPDIR="$tmpdir" HOME="$fakeHome" GEMINI_HOME="$ce4"
  [ "$(field token)" = "$expectedToken" ] || fail "nested scratch parent: runtime got token '$(field token)'"
  [ "$(field tokenmode)" = 600 ] || fail "nested scratch parent: token mode is '$(field tokenmode)', not 600"
  [ ! -s stderr ] || fail "nested scratch parent: unexpected stderr: $(cat stderr)"

  # 5. Home already holds a different token: that token unchanged (AE3).
  ce5=$(make_ce_home "$tmpdir/xmodel-cr-scratch-XXXXXX")
  existingToken='{"existing":"keep-me"}'
  printf '%s\n' "$existingToken" > "$ce5/antigravity-acp/acp_token.json"
  chmod 600 "$ce5/antigravity-acp/acp_token.json"
  run_seed "existing token" TMPDIR="$tmpdir" HOME="$fakeHome" GEMINI_HOME="$ce5"
  [ "$(field token)" = "$existingToken" ] || fail "existing token: runtime got '$(field token)', expected '$existingToken'"
  [ ! -s stderr ] || fail "existing token: unexpected stderr: $(cat stderr)"

  # 6. T3-instance-shaped home $HOME/.t3/userdata/providers/antigravity/<hex> with antigravity-acp/: no token (AE2).
  t3Home=$fakeHome/.t3/userdata/providers/antigravity/ac0a3dfd6dddb20962cecff6ee5fe65e19d3923be20e52c5ab52ff877f7e4c32
  mkdir -p "$t3Home/antigravity-acp"
  chmod 700 "$t3Home"
  run_seed "T3 instance home" TMPDIR="$tmpdir" HOME="$fakeHome" GEMINI_HOME="$t3Home"
  [ "$(field token)" = "<none>" ] || fail "T3 instance home: runtime got token '$(field token)'"
  [ ! -e "$t3Home/antigravity-acp/acp_token.json" ] || fail "T3 instance home: token file created"
  [ ! -s stderr ] || fail "T3 instance home: unexpected stderr: $(cat stderr)"

  # 7. gemini-home under a parent with another name: no token.
  ce7=$(make_ce_home "$tmpdir/other-parent-XXXXXX")
  run_seed "wrong parent name" TMPDIR="$tmpdir" HOME="$fakeHome" GEMINI_HOME="$ce7"
  [ "$(field token)" = "<none>" ] || fail "wrong parent name: runtime got token '$(field token)'"
  [ ! -e "$ce7/antigravity-acp/acp_token.json" ] || fail "wrong parent name: token file created"
  [ ! -s stderr ] || fail "wrong parent name: unexpected stderr: $(cat stderr)"

  # 7b. A home that is itself named like a CE scratch directory, under a
  # gemini-home-like parent: the leaf must be gemini-home, so no token.
  leafHome=$tmpdir/gemini-homes/xmodel-cr-scratch-leaf
  mkdir -p "$leafHome/antigravity-acp"
  chmod 700 "$tmpdir/gemini-homes" "$leafHome"
  run_seed "wrong leaf name" TMPDIR="$tmpdir" HOME="$fakeHome" GEMINI_HOME="$leafHome"
  [ "$(field token)" = "<none>" ] || fail "wrong leaf name: runtime got token '$(field token)'"
  [ ! -e "$leafHome/antigravity-acp/acp_token.json" ] || fail "wrong leaf name: token file created"
  [ ! -s stderr ] || fail "wrong leaf name: unexpected stderr: $(cat stderr)"

  # 8a. Matching parent with mode 0755: no token.
  ce8a=$(make_ce_home "$tmpdir/xmodel-cr-scratch-XXXXXX")
  chmod 755 "$(dirname "$ce8a")"
  run_seed "parent mode 0755" TMPDIR="$tmpdir" HOME="$fakeHome" GEMINI_HOME="$ce8a"
  [ "$(field token)" = "<none>" ] || fail "parent mode 0755: runtime got token '$(field token)'"
  [ ! -e "$ce8a/antigravity-acp/acp_token.json" ] || fail "parent mode 0755: token file created"
  [ ! -s stderr ] || fail "parent mode 0755: unexpected stderr: $(cat stderr)"

  # 8b. gemini-home that is a symlink to a real dir: no token at either end.
  parent8b=$(mktemp -d "$tmpdir/xmodel-cr-scratch-XXXXXX")
  realGh8b=$(mktemp -d "$tmpdir/real-gh-XXXXXX")
  mkdir -p "$realGh8b/antigravity-acp"
  ln -s "$realGh8b" "$parent8b/gemini-home"
  run_seed "symlink gemini-home" TMPDIR="$tmpdir" HOME="$fakeHome" GEMINI_HOME="$parent8b/gemini-home"
  [ "$(field token)" = "<none>" ] || fail "symlink gemini-home: runtime got token '$(field token)'"
  [ ! -e "$parent8b/gemini-home/antigravity-acp/acp_token.json" ] || fail "symlink gemini-home: token at symlink path"
  [ ! -e "$realGh8b/antigravity-acp/acp_token.json" ] || fail "symlink gemini-home: token at real dir"
  [ ! -s stderr ] || fail "symlink gemini-home: unexpected stderr: $(cat stderr)"

  # 8c. antigravity-acp that is a symlink: no token at either end.
  parent8c=$(mktemp -d "$tmpdir/xmodel-cr-scratch-XXXXXX")
  mkdir -p "$parent8c/gemini-home"
  realAcp8c=$(mktemp -d "$tmpdir/real-acp-XXXXXX")
  ln -s "$realAcp8c" "$parent8c/gemini-home/antigravity-acp"
  run_seed "symlink antigravity-acp" TMPDIR="$tmpdir" HOME="$fakeHome" GEMINI_HOME="$parent8c/gemini-home"
  [ "$(field token)" = "<none>" ] || fail "symlink antigravity-acp: runtime got token '$(field token)'"
  [ ! -e "$parent8c/gemini-home/antigravity-acp/acp_token.json" ] || fail "symlink antigravity-acp: token at symlink path"
  [ ! -e "$realAcp8c/acp_token.json" ] || fail "symlink antigravity-acp: token at real dir"
  [ ! -s stderr ] || fail "symlink antigravity-acp: unexpected stderr: $(cat stderr)"

  # 8d. scratch parent itself is a symlink to a real 0700 dir: no token at either end.
  realParent8d=$(mktemp -d "$tmpdir/real-parent-XXXXXX")
  mkdir -p "$realParent8d/gemini-home/antigravity-acp"
  ln -s "$realParent8d" "$tmpdir/xmodel-cr-scratch-symlinkparent"
  run_seed "symlink parent" TMPDIR="$tmpdir" HOME="$fakeHome" GEMINI_HOME="$tmpdir/xmodel-cr-scratch-symlinkparent/gemini-home"
  [ "$(field token)" = "<none>" ] || fail "symlink parent: runtime got token '$(field token)'"
  [ ! -e "$tmpdir/xmodel-cr-scratch-symlinkparent/gemini-home/antigravity-acp/acp_token.json" ] || fail "symlink parent: token at symlink path"
  [ ! -e "$realParent8d/gemini-home/antigravity-acp/acp_token.json" ] || fail "symlink parent: token at real dir"
  [ ! -s stderr ] || fail "symlink parent: unexpected stderr: $(cat stderr)"

  # 9. Dangling symlink planted at the target path: link left as is, nothing written through it, stderr line appears.
  ce9=$(make_ce_home "$tmpdir/xmodel-cr-scratch-XXXXXX")
  danglingTarget=$tmpdir/dangling-target-file
  ln -s "$danglingTarget" "$ce9/antigravity-acp/acp_token.json"
  run_seed "dangling symlink target" TMPDIR="$tmpdir" HOME="$fakeHome" GEMINI_HOME="$ce9"
  [ "$(field token)" = "<none>" ] || fail "dangling symlink target: runtime got token '$(field token)'"
  [ -L "$ce9/antigravity-acp/acp_token.json" ] || fail "dangling symlink target: symlink was removed or replaced"
  [ ! -e "$danglingTarget" ] || fail "dangling symlink target: wrote through dangling symlink"
  [ "$(cat stderr)" = "$expectedStderr" ] || fail "dangling symlink target: stderr was '$(cat stderr)', expected '$expectedStderr'"

  # 9b. Symlink to an existing regular file outside the home planted at the target path:
  #     link and outside file left as is, stderr line appears.
  ce9b=$(make_ce_home "$tmpdir/xmodel-cr-scratch-XXXXXX")
  outsideTarget=$tmpdir/outside-target-file
  printf 'keep-outside\n' > "$outsideTarget"
  ln -s "$outsideTarget" "$ce9b/antigravity-acp/acp_token.json"
  run_seed "symlink to existing file target" TMPDIR="$tmpdir" HOME="$fakeHome" GEMINI_HOME="$ce9b"
  [ "$(field token)" = "<none>" ] || fail "symlink to existing file target: runtime got token '$(field token)'"
  [ -L "$ce9b/antigravity-acp/acp_token.json" ] || fail "symlink to existing file target: symlink was removed or replaced"
  [ "$(cat "$outsideTarget")" = "keep-outside" ] || fail "symlink to existing file target: outside file was overwritten"
  [ "$(cat stderr)" = "$expectedStderr" ] || fail "symlink to existing file target: stderr was '$(cat stderr)', expected '$expectedStderr'"

  # 9c. Symlink to /dev/null planted at the target path: link left as is, stderr line appears.
  ce9c=$(make_ce_home "$tmpdir/xmodel-cr-scratch-XXXXXX")
  ln -s /dev/null "$ce9c/antigravity-acp/acp_token.json"
  run_seed "symlink to /dev/null target" TMPDIR="$tmpdir" HOME="$fakeHome" GEMINI_HOME="$ce9c"
  [ "$(field token)" = "<none>" ] || fail "symlink to /dev/null target: runtime got token '$(field token)'"
  [ -L "$ce9c/antigravity-acp/acp_token.json" ] || fail "symlink to /dev/null target: symlink was removed or replaced"
  [ "$(cat stderr)" = "$expectedStderr" ] || fail "symlink to /dev/null target: stderr was '$(cat stderr)', expected '$expectedStderr'"

  # 9d. FIFO planted at the target path: wrapper does not block opening the FIFO,
  #     FIFO stays in place, stderr line appears.
  ce9d=$(make_ce_home "$tmpdir/xmodel-cr-scratch-XXXXXX")
  mkfifo -m 600 "$ce9d/antigravity-acp/acp_token.json"
  printf 'one line\n' | ${pkgs.coreutils}/bin/timeout 5s env -i PATH=/no-such-dir TMPDIR="$tmpdir" HOME="$fakeHome" GEMINI_HOME="$ce9d" "$wrapper" > out 2> stderr \
    || fail "FIFO target: wrapper timed out or exited $?"
  check_invariants "FIFO target"
  [ "$(field token)" = "<none>" ] || fail "FIFO target: runtime got token '$(field token)'"
  [ -p "$ce9d/antigravity-acp/acp_token.json" ] || fail "FIFO target: FIFO was removed or replaced"
  [ "$(cat stderr)" = "$expectedStderr" ] || fail "FIFO target: stderr was '$(cat stderr)', expected '$expectedStderr'"

  # 10. Home without antigravity-acp dir: nothing created.
  parent10=$(mktemp -d "$tmpdir/xmodel-cr-scratch-XXXXXX")
  mkdir -p "$parent10/gemini-home"
  run_seed "no antigravity-acp dir" TMPDIR="$tmpdir" HOME="$fakeHome" GEMINI_HOME="$parent10/gemini-home"
  [ "$(field token)" = "<none>" ] || fail "no antigravity-acp dir: runtime got token '$(field token)'"
  [ ! -e "$parent10/gemini-home/antigravity-acp" ] || fail "no antigravity-acp dir: antigravity-acp created"
  [ ! -s stderr ] || fail "no antigravity-acp dir: unexpected stderr: $(cat stderr)"

  # 11. GEMINI_HOME unset, and GEMINI_HOME=$HOME/.gemini: nothing created.
  run_seed "GEMINI_HOME unset" TMPDIR="$tmpdir" HOME="$fakeHome"
  [ "$(field token)" = "<none>" ] || fail "GEMINI_HOME unset: runtime got token '$(field token)'"
  [ ! -s stderr ] || fail "GEMINI_HOME unset: unexpected stderr: $(cat stderr)"

  emptyDotGeminiHome=$PWD/empty-dot-gemini-home
  mkdir -p "$emptyDotGeminiHome/.gemini/antigravity-acp"
  run_seed "GEMINI_HOME=HOME/.gemini" TMPDIR="$tmpdir" HOME="$fakeHome" GEMINI_HOME="$emptyDotGeminiHome/.gemini"
  [ "$(field token)" = "<none>" ] || fail "GEMINI_HOME=HOME/.gemini: runtime got token '$(field token)'"
  [ ! -e "$emptyDotGeminiHome/.gemini/antigravity-acp/acp_token.json" ] || fail "GEMINI_HOME=HOME/.gemini: token created"
  [ ! -s stderr ] || fail "GEMINI_HOME=HOME/.gemini: unexpected stderr: $(cat stderr)"

  run_seed "GEMINI_HOME=fakeHome/.gemini" TMPDIR="$tmpdir" HOME="$fakeHome" GEMINI_HOME="$fakeHome/.gemini"
  [ "$(field token)" = "$expectedToken" ] || fail "GEMINI_HOME=fakeHome/.gemini: source token missing"
  [ ! -s stderr ] || fail "GEMINI_HOME=fakeHome/.gemini: unexpected stderr: $(cat stderr)"

  # 12. No source token: runtime starts, no token, wrapper writes nothing to stdout or stderr (R5).
  noTokenHome=$PWD/no-token-home
  mkdir -p "$noTokenHome/.gemini/antigravity-acp"
  ce12=$(make_ce_home "$tmpdir/xmodel-cr-scratch-XXXXXX")
  run_seed "no source token" TMPDIR="$tmpdir" HOME="$noTokenHome" GEMINI_HOME="$ce12"
  [ "$(field token)" = "<none>" ] || fail "no source token: runtime got token '$(field token)'"
  [ ! -e "$ce12/antigravity-acp/acp_token.json" ] || fail "no source token: token file created"
  [ ! -s stderr ] || fail "no source token: unexpected stderr: $(cat stderr)"

  # 12b. Symlinked source token: rejected silently without seeding.
  symlinkSourceHome=$PWD/symlink-source-home
  mkdir -p "$symlinkSourceHome/.gemini/antigravity-acp"
  ln -s "$sourceToken" "$symlinkSourceHome/.gemini/antigravity-acp/acp_token.json"
  ce12b=$(make_ce_home "$tmpdir/xmodel-cr-scratch-XXXXXX")
  run_seed "symlink source token" TMPDIR="$tmpdir" HOME="$symlinkSourceHome" GEMINI_HOME="$ce12b"
  [ "$(field token)" = "<none>" ] || fail "symlink source token: runtime got token '$(field token)'"
  [ ! -e "$ce12b/antigravity-acp/acp_token.json" ] || fail "symlink source token: token file created"
  [ ! -s stderr ] || fail "symlink source token: unexpected stderr: $(cat stderr)"

  # 12c. Empty source token (0 bytes): rejected silently without seeding.
  emptySourceHome=$PWD/empty-source-home
  mkdir -p "$emptySourceHome/.gemini/antigravity-acp"
  : > "$emptySourceHome/.gemini/antigravity-acp/acp_token.json"
  chmod 600 "$emptySourceHome/.gemini/antigravity-acp/acp_token.json"
  ce12c=$(make_ce_home "$tmpdir/xmodel-cr-scratch-XXXXXX")
  run_seed "empty source token" TMPDIR="$tmpdir" HOME="$emptySourceHome" GEMINI_HOME="$ce12c"
  [ "$(field token)" = "<none>" ] || fail "empty source token: runtime got token '$(field token)'"
  [ ! -e "$ce12c/antigravity-acp/acp_token.json" ] || fail "empty source token: token file created"
  [ ! -s stderr ] || fail "empty source token: unexpected stderr: $(cat stderr)"

  # 13. Unreadable source token (chmod 000) in a recognized home: runtime starts, no partial target,
  #     exactly the stderr line, no token content.
  ce13=$(make_ce_home "$tmpdir/xmodel-cr-scratch-XXXXXX")
  chmod 000 "$sourceToken"
  printf 'one line\n' | env -i PATH=/no-such-dir TMPDIR="$tmpdir" HOME="$fakeHome" GEMINI_HOME="$ce13" "$wrapper" > out 2> stderr \
    || fail "unreadable source token: wrapper exited $?"
  chmod 600 "$sourceToken"
  check_invariants "unreadable source token"
  [ "$(field token)" = "<none>" ] || fail "unreadable source token: runtime got token '$(field token)'"
  [ ! -e "$ce13/antigravity-acp/acp_token.json" ] && [ ! -L "$ce13/antigravity-acp/acp_token.json" ] \
    || fail "unreadable source token: partial target left behind"
  [ "$(cat stderr)" = "$expectedStderr" ] \
    || fail "unreadable source token: stderr was '$(cat stderr)', expected '$expectedStderr'"
  case $(cat stderr) in
    *source-token*) fail "unreadable source token: stderr leaked token content" ;;
  esac

  # 14. HOME unset: runtime still starts.
  ce14=$(make_ce_home "$tmpdir/xmodel-cr-scratch-XXXXXX")
  run_seed "HOME unset" TMPDIR="$tmpdir" GEMINI_HOME="$ce14"
  [ "$(field token)" = "<none>" ] || fail "HOME unset: runtime got token '$(field token)'"
  [ ! -e "$ce14/antigravity-acp/acp_token.json" ] || fail "HOME unset: token file created"
  [ ! -s stderr ] || fail "HOME unset: unexpected stderr: $(cat stderr)"

  if [ -s "$failures" ]; then
    cat "$failures" >&2
    exit 1
  fi
  touch $out
''
