{
  ...
}:
{
  # Disable cross-session, implicit memory for the Gemini CLI
  # to preserve declarative environment determinism.
  home.file.".gemini/settings.json".text = builtins.toJSON {
    experimental = {
      autoMemory = false;
    };
  };
}
