{ ... }:
{
  # Disable cross-session, implicit memory to preserve declarative environment
  # determinism.  The rest of Claude Code's declarative settings live in
  # modules/nixos/claude.nix, because its user settings file is writable state
  # the agent itself owns.
  home.sessionVariables = {
    CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1";
  };
}
