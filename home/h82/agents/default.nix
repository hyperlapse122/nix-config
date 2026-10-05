{ ... }:
{
  imports = [
    ./agent-plugins.nix
    ./claude.nix
    ./codex.nix
    ./gemini.nix
    ./instructions
    ./retire-orca-skills.nix
    ./tokscale.nix
  ];
}
