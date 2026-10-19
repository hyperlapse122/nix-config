/*
  Check interface:

    import ./tests/text-template.nix { inherit pkgs; }

  Runs packages/text-template.nix, the renderer of the shared agent
  instructions, against the fixtures in tests/text-template/ and asserts:

  - a template reading a string and two trait conditions renders exactly
    render.md, with shell-style `${...}` text passed through unchanged.
  - a missing key fails whether the template prints it or only reads it in an
    `if`, and the printed case names Go's missing-key error. The `if` case is
    what separates `missingkey=error` from the output scan, since Go's default
    renders it as empty.
  - a `null` value fails when printed directly (`<no value>`) and when printed
    through `printf` (`<nil>`).
  - a function the renderer does not define, such as gomplate's `env`, fails.
  - a wrong argument count fails.

  Every failure case must also leave stdout empty, so a failed render cannot
  leave a partial file behind a redirect. The builder collects every failure
  instead of exiting at the first.
*/
{ pkgs }:
let
  inherit (pkgs) lib;

  renderer = lib.getExe (import ../packages/text-template.nix { inherit pkgs; });
  fixtures = ./text-template;

  # Fails the build, naming the case, unless the renderer exits non-zero with
  # nothing on stdout, and, when `stderrPattern` is set, names it on stderr.
  expectFailure =
    {
      name,
      args,
      stderrPattern ? null,
    }:
    ''
      if ${renderer} ${args} > "$TMPDIR/out" 2> "$TMPDIR/err"; then
        echo ${lib.escapeShellArg "text-template accepted ${name}"} >&2
        failed=1
      elif [ -s "$TMPDIR/out" ]; then
        echo ${lib.escapeShellArg "text-template wrote stdout for ${name}"} >&2
        failed=1
      ${lib.optionalString (stderrPattern != null) ''
        elif ! grep -qF -- ${lib.escapeShellArg stderrPattern} "$TMPDIR/err"; then
          echo ${lib.escapeShellArg "text-template did not report '${stderrPattern}' for ${name}:"} >&2
          cat "$TMPDIR/err" >&2
          failed=1
      ''}
      fi
    '';

  failureCase =
    name: template: stderrPattern:
    expectFailure {
      inherit name stderrPattern;
      args = "${fixtures}/${template} ${fixtures}/context.json";
    };
in
pkgs.runCommand "text-template-tests" { } ''
  failed=0

  if ! ${renderer} ${fixtures}/render.md.tmpl ${fixtures}/context.json > "$TMPDIR/rendered"; then
    echo "text-template failed to render render.md.tmpl" >&2
    failed=1
  elif ! cmp -s "$TMPDIR/rendered" ${fixtures}/render.md; then
    echo "text-template rendered render.md.tmpl differently from render.md:" >&2
    diff ${fixtures}/render.md "$TMPDIR/rendered" >&2 || true
    failed=1
  fi

  ${failureCase "a printed missing key" "missing-printed.tmpl" "map has no entry for key"}
  ${failureCase "a missing key read in an if" "missing-read.tmpl" "map has no entry for key"}
  ${failureCase "a printed null" "null-printed.tmpl" "<no value>"}
  ${failureCase "a null printed through printf" "null-printf.tmpl" "<nil>"}
  ${failureCase "an undefined function" "undefined-function.tmpl" ''function "env" not defined''}
  ${expectFailure {
    name = "a missing data argument";
    args = "${fixtures}/render.md.tmpl";
  }}

  if [ "$failed" != "0" ]; then
    exit 1
  fi

  touch $out
''
