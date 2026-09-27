{ ... }:
{
  imports = [
    ./agent-plugins.nix
    ./claude.nix
    ./gemini.nix
    ./instructions
    ./orca-skills.nix
    ./tokscale.nix
  ];
}
