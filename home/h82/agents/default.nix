{ ... }:
{
  imports = [
    ./agent-plugins.nix
    ./claude.nix
    ./cross-model-peers.nix
    ./gemini.nix
    ./grok.nix
    ./instructions
    ./korean-skills.nix
    ./opencode.nix
    ./tokscale.nix
  ];
}
