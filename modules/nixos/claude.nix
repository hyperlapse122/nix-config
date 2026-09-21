{ ... }:
{
  # Claude Code owns ~/.claude/settings.json: it rewrites that file whenever a
  # /config option such as the theme changes, so Home Manager cannot place a
  # read-only store symlink there.  Managed settings are the one tier Claude
  # Code only reads, and they outrank every user and project value, which is
  # what keeps these defaults declarative.  The same precedence means a model
  # or effort picked at runtime does not survive the session; drop the key
  # here to hand that choice back to the user.
  environment.etc."claude-code/managed-settings.json".text = builtins.toJSON {
    autoMemoryEnabled = false;
    model = "opus[1m]";
    # Top-level effortLevel applies to whichever model serves the session.  The
    # per-model modelSettings.<canonical>.effortLevel form silently stops
    # applying once the `opus` alias points at a later generation.
    effortLevel = "medium";
  };
}
