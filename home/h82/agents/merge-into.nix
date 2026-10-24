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
# The ledger mirrors the settings file's path under the state directory, so
# each settings file has its own. Evaluated rather than read from
# XDG_STATE_HOME at activation, so an apply started from a shell that sets it
# and one started without it find the same ledger. The merger only opens it
# when the document declares ownEntries or a migration.
lib.hm.dag.entryAfter [ "installPackages" ] ''
  if [[ ! -v DRY_RUN ]]; then
    ${merger} \
      --label ${lib.escapeShellArg label} \
      --settings ${config.home.homeDirectory}/${directory}/${file} \
      --declared ${document} \
      --ledger ${lib.escapeShellArg "${config.xdg.stateHome}/nix-config/agent-settings-ledger/${directory}/${file}"}
  fi
''
