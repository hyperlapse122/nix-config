{
  config,
  pkgs,
  lib,
  ...
}:
let
  merger = "${
    (import ../../../packages/agent-tools.nix { inherit pkgs; }).agentSettings
  }/bin/agent-settings";

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
    # `auto` follows the background the terminal reports, so the palette
    # tracks whichever theme Ghostty is running rather than pinning one here.
    theme = "auto";
    preferredNotifChannel = "ghostty";
    agentPushNotifEnabled = false;
    inputNeededNotifEnabled = false;
    cleanupPeriodDays = 30;
    # The advisor must be at least as capable as the main model, and `fable`
    # as advisor bills to usage credits, so `opus` is the alias that serves
    # the `opus[1m]` main model without either.
    advisorModel = "opus";
  };

  # Keys Claude Code reads only from its global config, ~/.claude.json, and
  # never from settings.json.  That file is Claude Code's own runtime state too,
  # so the same merge assigns these keys and leaves the rest untouched.
  globalConfigTier = {
    leftArrowOpensAgents = false;
  };

  # Keys this repository used to declare and has since retired. The merge only
  # assigns, so dropping a key from settingsTier alone would leave its last
  # written value on every machine forever. Move it here instead, and delete
  # the entry once every host has rebuilt past it.
  retiredKeys = [ ];

  declared = pkgs.writeText "claude-declared-settings.json" (
    builtins.toJSON {
      set = settingsTier;
      remove = retiredKeys;
    }
  );

  declaredGlobalConfig = pkgs.writeText "claude-declared-global-config.json" (
    builtins.toJSON {
      set = globalConfigTier;
      remove = [ ];
    }
  );
in
{
  home.sessionVariables = environmentTier;

  # Unguarded on purpose, unlike the KDE activation blocks. Those test their
  # tool with `[ -x ]` because it comes from a package that may be absent; this
  # merger is a store path built from this module, so the test could only ever
  # be true -- and if it somehow were not, the false branch would skip the
  # merge silently, which is the opposite of what the merge must do. A refusal
  # or a missing binary both have to stop the rebuild loudly.
  # After installPackages, not merely after writeBoundary. A refusal has to
  # fail the rebuild, and an activation entry that fails stops every entry
  # ordered behind it -- from writeBoundary that would strand linkGeneration
  # and installPackages, leaving the system generation switched while the home
  # generation is not linked and packages are missing. A file another program
  # owns should not be able to do that.
  home.activation.claudeSettings = lib.hm.dag.entryAfter [ "installPackages" ] ''
    ${merger} \
      --label 'Claude Code' \
      --settings ${config.home.homeDirectory}/.claude/settings.json \
      --declared ${declared}
  '';

  # A separate entry rather than a second call in claudeSettings, ordered the
  # same way and unguarded for the same reasons.
  home.activation.claudeGlobalConfig = lib.hm.dag.entryAfter [ "installPackages" ] ''
    ${merger} \
      --label 'Claude Code' \
      --settings ${config.home.homeDirectory}/.claude.json \
      --declared ${declaredGlobalConfig}
  '';
}
