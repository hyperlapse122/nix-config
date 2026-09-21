{ ... }:
{
  # Disable cross-session, implicit memory for the Gemini and Antigravity CLIs
  # to preserve declarative environment determinism.
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
