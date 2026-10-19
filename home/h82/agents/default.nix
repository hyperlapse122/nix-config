{ ... }:
{
  imports = [
    ./agent-plugins.nix
    ./claude.nix
    ./gemini.nix
    ./grok.nix
    ./instructions
    ./opencode.nix
    ./tokscale.nix
  ];
}
