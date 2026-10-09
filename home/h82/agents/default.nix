{ ... }:
{
  imports = [
    ./agent-plugins.nix
    ./claude.nix
    ./codex.nix
    ./gemini.nix
    ./instructions
    ./tokscale.nix
  ];
}
