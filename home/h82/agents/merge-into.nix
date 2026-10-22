# The activation entry that merges a declared document into one settings file
# of an agent under the home directory.
{
  config,
  pkgs,
  lib,
}:
let
  merger = "${
    (import ../../../packages/agent-tools.nix { inherit pkgs; }).agentSettings
  }/bin/agent-settings";
in
directory: label: file: document:
lib.hm.dag.entryAfter [ "installPackages" ] ''
  ${merger} \
    --label ${lib.escapeShellArg label} \
    --settings ${config.home.homeDirectory}/${directory}/${file} \
    --declared ${document}
''
