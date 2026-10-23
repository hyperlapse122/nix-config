{ ... }:
{
  imports = [
    ./agent-plugins.nix
    ./claude.nix
    ./codex.nix
    ./cross-model-peers.nix
    ./gemini.nix
    ./instructions
    ./korean-skills.nix
    ./opencode.nix
    ./pi.nix
    ./skills.nix
    ./tokscale.nix
  ];
}
