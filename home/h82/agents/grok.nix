{ pkgs, ... }:
{
  # Grok Build reads the shared instructions through its Claude Code
  # compatibility (~/.claude/CLAUDE.md), and it writes its sign-in token,
  # logs, and config under ~/.grok, so no file is declared there.
  home.packages = [ (import ../../../packages/grok-build.nix { inherit pkgs; }) ];
}
