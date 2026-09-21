{ ... }:
{
  # Claude Code owns ~/.claude/settings.json: it rewrites that file whenever a
  # /config option such as the theme changes, so Home Manager cannot place a
  # read-only store symlink there.  Managed settings are the one tier Claude
  # Code only reads, and they outrank every user and project value, which is
  # what keeps implicit memory off declaratively.
  environment.etc."claude-code/managed-settings.json".text = builtins.toJSON {
    autoMemoryEnabled = false;
  };
}
