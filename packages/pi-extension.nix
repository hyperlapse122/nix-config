# The repository's Pi extension as a directory with a root index.js, the
# entrypoint Pi looks for in an extension directory, with the host's key-file
# paths in place of the placeholders.
{
  pkgs,
  syntheticKeyFile,
  exaKeyFile,
  openrouterKeyFile,
}:
pkgs.runCommand "pi-extension" { } ''
  mkdir -p $out
  cp ${./pi-extension/index.js} $out/index.js
  substituteInPlace $out/index.js \
    --replace-fail '"@SYNTHETIC_KEY_FILE@"' '"${syntheticKeyFile}"' \
    --replace-fail '"@EXA_KEY_FILE@"' '"${exaKeyFile}"' \
    --replace-fail '"@OPENROUTER_KEY_FILE@"' '"${openrouterKeyFile}"'
''
