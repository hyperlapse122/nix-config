/*
  Check interface:

    import ./tests/agent-memory.nix { inherit pkgs self; }

  Asserts that coding-agent memory is disabled declaratively for user `h82`
  on the ThinkPad host configuration.

  Verifies:
  - CLAUDE_CODE_DISABLE_AUTO_MEMORY is exported as "1" in session variables.
  - ~/.claude/settings.json sets autoMemoryEnabled = false and autoDreamEnabled = false.
  - ~/.gemini/antigravity-cli/settings.json sets disableAutoGenerateMemories = true.
  - ~/.gemini/settings.json sets experimental.autoMemory = false.
*/
{ pkgs, self }:
let
  host = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11;
  userConfig = host.config.home-manager.users.h82;

  sessionVars = userConfig.home.sessionVariables;
  claudeSettingsJson = userConfig.home.file.".claude/settings.json".text;
  agySettingsJson = userConfig.home.file.".gemini/antigravity-cli/settings.json".text;
  geminiSettingsJson = userConfig.home.file.".gemini/settings.json".text;
in
pkgs.runCommand "agent-memory-tests"
  {
    nativeBuildInputs = [
      pkgs.jq
      pkgs.gnugrep
    ];
  }
  ''
    set -x

    # 1. Verify Claude Code session variable kill switch
    claudeEnv='${sessionVars.CLAUDE_CODE_DISABLE_AUTO_MEMORY or ""}'
    if [ "$claudeEnv" != "1" ]; then
      echo "Expected CLAUDE_CODE_DISABLE_AUTO_MEMORY to be '1', got: '$claudeEnv'" >&2
      exit 1
    fi

    # 2. Verify Claude Code settings.json
    echo '${claudeSettingsJson}' > claude-settings.json
    claudeAutoMem=$(jq -r '.autoMemoryEnabled' claude-settings.json)
    if [ "$claudeAutoMem" != "false" ]; then
      echo "Expected autoMemoryEnabled to be false in claude settings, got: '$claudeAutoMem'" >&2
      exit 1
    fi

    claudeDream=$(jq -r '.autoDreamEnabled' claude-settings.json)
    if [ "$claudeDream" != "false" ]; then
      echo "Expected autoDreamEnabled to be false in claude settings, got: '$claudeDream'" >&2
      exit 1
    fi

    # 3. Verify Antigravity CLI settings.json
    echo '${agySettingsJson}' > agy-settings.json
    agyDisableAutoMem=$(jq -r '.disableAutoGenerateMemories' agy-settings.json)
    if [ "$agyDisableAutoMem" != "true" ]; then
      echo "Expected disableAutoGenerateMemories to be true in agy settings, got: '$agyDisableAutoMem'" >&2
      exit 1
    fi

    # 4. Verify Gemini CLI settings.json
    echo '${geminiSettingsJson}' > gemini-settings.json
    geminiAutoMem=$(jq -r '.experimental.autoMemory' gemini-settings.json)
    if [ "$geminiAutoMem" != "false" ]; then
      echo "Expected experimental.autoMemory to be false in gemini settings, got: '$geminiAutoMem'" >&2
      exit 1
    fi

    touch $out
  ''
