{ ... }:
{
  home.file.agent-instructions-claude-code = {
    target = ".claude/CLAUDE.md";
    source = ./instructions.md;
  };
}
