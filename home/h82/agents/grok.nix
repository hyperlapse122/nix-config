{ pkgs, ... }:
{
  # Grok Build reads its own rendering of the shared instructions from
  # ~/.grok/rules/. It writes its sign-in token, logs, and config under
  # ~/.grok itself.
  home.packages = [ (import ../../../packages/grok-build.nix { inherit pkgs; }) ];

  my.agents.crossModelPeers = [ "grok" ];
}
