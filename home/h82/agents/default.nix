{ ... }:
{
  imports = [
    ./agent-plugins.nix
    ./claude.nix
    ./codex.nix
    ./cross-model-peers.nix
    ./gemini.nix
    ./grok.nix
    ./instructions
    ./korean-skills.nix
    ./omp.nix
    ./retire-orca.nix
    ./skills.nix
    ./test-audit.nix
    ./tokscale.nix
    ./usage.nix
  ];
}
