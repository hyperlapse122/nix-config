# The repository's Pi extension as a directory with a root index.js, the
# entrypoint Pi looks for in an extension directory, with the host's key-file
# paths in place of the placeholders. Callers pass the paths packages/pi.nix
# checked and exposes, so both read the same files.
{
  pkgs,
  syntheticKeyFile,
  exaKeyFile,
}:
pkgs.runCommand "pi-extension" { } ''
  mkdir -p $out
  cp ${./pi-extension/index.js} $out/index.js
  substituteInPlace $out/index.js \
    --replace-fail '"@SYNTHETIC_KEY_FILE@"' '"${syntheticKeyFile}"' \
    --replace-fail '"@EXA_KEY_FILE@"' '"${exaKeyFile}"'
''
