{ ... }:
{
  # A plain store link: Claude Code never rewrites this file, unlike the
  # settings files claude.nix and gemini.nix merge at activation. OpenCode's
  # copy is not here: packages/opencode.nix hands the same file to standalone
  # sessions only, so a reviewer run never loads it.
  home.file.agent-instructions-claude-code = {
    target = ".claude/CLAUDE.md";
    source = ./instructions.md;
  };
}
