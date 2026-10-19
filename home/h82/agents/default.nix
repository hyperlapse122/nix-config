{ ... }:
{
  imports = [
    ./agent-plugins.nix
    ./claude.nix
    ./cross-model-peers.nix
    ./gemini.nix
    ./grok.nix
    ./instructions
    ./opencode.nix
    ./tokscale.nix
  ];
}
