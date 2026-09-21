{ ... }:
{
  # Disable cross-session, implicit memory across installed coding agents
  # to preserve declarative environment determinism.  Claude Code is handled
  # in modules/nixos/agent-memory.nix, because its user settings file is
  # writable state the agent itself owns.
  home.sessionVariables = {
    CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1";
  };

  home.file = {
    ".gemini/antigravity-cli/settings.json".text = builtins.toJSON {
      disableAutoGenerateMemories = true;
    };

    ".gemini/settings.json".text = builtins.toJSON {
      experimental = {
        autoMemory = false;
      };
    };
  };
}
