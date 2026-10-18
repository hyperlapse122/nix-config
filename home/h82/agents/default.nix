{ ... }:
{
  imports = [
    ./agent-plugins.nix
    ./claude.nix
    ./gemini.nix
    ./instructions
    ./opencode.nix
    ./tokscale.nix
  ];
}
