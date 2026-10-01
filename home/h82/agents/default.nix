{ ... }:
{
  imports = [
    ./agent-plugins.nix
    ./claude.nix
    ./codex.nix
    ./gemini.nix
    ./instructions
    ./orca-skills.nix
    ./tokscale.nix
  ];
}
