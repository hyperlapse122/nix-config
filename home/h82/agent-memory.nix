{ ... }:
{
  # Disable cross-session, implicit memory across installed coding agents
  # to preserve declarative environment determinism.
  home.sessionVariables = {
    CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1";
  };

  home.file = {
    ".claude/settings.json".text = builtins.toJSON {
      autoMemoryEnabled = false;
      autoDreamEnabled = false;
    };

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
