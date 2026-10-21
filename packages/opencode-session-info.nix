# The session-info OpenCode plugin as a directory with a root index.js, the
# entrypoint OpenCode looks for in a plugin directory.
{ pkgs }:
pkgs.runCommand "opencode-session-info" { } ''
  mkdir -p $out
  cp ${./opencode-session-info/index.js} $out/index.js
''
