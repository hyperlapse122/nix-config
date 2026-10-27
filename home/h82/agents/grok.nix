{ pkgs, ... }:
{
  # Grok Build writes its sign-in token, logs, and config under ~/.grok itself.
  # Compound Engineering has no Grok review route, so it adds no peer token.
  home.packages = [ (import ../../../packages/grok-build.nix { inherit pkgs; }) ];
}
