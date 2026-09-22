{
  config,
  pkgs,
  lib,
  ...
}:
let
  merger = "${
    (import ../../packages/claude-tools.nix { inherit pkgs; }).claudeSettings
  }/bin/claude-settings";

  # Declared through the environment because that is where these settings
  # persist.  A variable that only overrides one session -- ANTHROPIC_MODEL,
  # CLAUDE_CODE_EFFORT_LEVEL -- does not move its setting out of the file.
  environmentTier = {
    DISABLE_AUTOUPDATER = "1";
    CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1";
    CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS = "20";
    CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH = "1";
  };

  # Claude Code owns ~/.claude/settings.json and rewrites it whenever a /config
  # option changes, so Home Manager cannot place a read-only store symlink
  # there.  Activation assigns these keys instead and leaves every other key as
  # the agent wrote it.  A key listed here returns to its declared value on the
  # next rebuild; a key absent from here stays the user's permanently.  Note
  # that a project-level .claude/settings.json still outranks this tier.
  settingsTier = {
    model = "opus[1m]";
    # Top-level effortLevel applies to whichever model serves the session.  The
    # published settings schema carries no modelSettings property, so there is
    # no per-model form to use instead.
    effortLevel = "medium";
    language = "korean";
    # The ansi themes render from the terminal's own 16 colours instead of
    # pinning a palette of their own.
    theme = "dark-ansi";
    preferredNotifChannel = "ghostty";
    agentPushNotifEnabled = false;
    inputNeededNotifEnabled = false;
    cleanupPeriodDays = 30;
  };

  declared = pkgs.writeText "claude-declared-settings.json" (builtins.toJSON settingsTier);
in
{
  home.sessionVariables = environmentTier;

  home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -x "${merger}" ]; then
      # No `|| true` here: a symlinked or malformed settings file must stop the
      # rebuild loudly rather than leave the declared values unapplied.
      ${merger} \
        --settings ${config.home.homeDirectory}/.claude/settings.json \
        --declared ${declared}
    fi
  '';
}
