/*
  Check interface:

    import ./tests/claude.nix { inherit pkgs self; }

  Asserts that Claude Code's declared settings reach user `h82` through the
  right tier on both the production and bootstrap ThinkPad configurations.

  The declared set is split across two tiers. A setting whose persistent form
  is an environment variable is declared through session variables; everything
  else is written into ~/.claude/settings.json at activation, because Claude
  Code rewrites that file itself and a read-only store symlink cannot live
  there. The managed settings tier is deliberately unused: it blocks a change
  even inside a running session.

  Verifies, per host:
  - every environment-tier variable carries its declared value.
  - the JSON this repository renders for the settings tier carries every
    declared key at its declared value. Asserting the rendered file rather than
    the Nix attribute set keeps the check on what activation actually feeds the
    merger.
  - home.activation.claudeSettings exists, runs after writeBoundary, and its
    script names the packaged merger's store path.
  - that script does not swallow the merger's exit status, so a symlinked or
    malformed settings file fails the rebuild instead of passing silently.
  - no environment.etc entry declares claude-code/managed-settings.json.
  - no Home Manager file targets .claude/settings.json. An activation-time
    merge and a store symlink are mutually exclusive, so this assertion now
    guards the mechanism rather than contradicting it. Home Manager resolves a
    file's destination from `target`, which only defaults to the attribute
    name, so the lookup compares resolved targets rather than attribute names.

  Whether the merge preserves undeclared keys is not assertable from evaluated
  configuration at all -- it is behaviour of the packaged script. The
  `agent-settings` check in flake.nix runs that script against a seeded,
  divergent settings file instead.

  Every lookup carries an `or` fallback so a mutation that removes an entry or
  a key reaches the builder as shell rather than failing evaluation on a null
  interpolation. See
  .compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md

  The builder collects every failure instead of exiting at the first, so one
  red build names every broken assertion across both hosts.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  esc = value: lib.escapeShellArg (toString value);

  environmentTier = {
    DISABLE_AUTOUPDATER = "1";
    CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1";
    CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS = "20";
    CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH = "1";
  };

  settingsTier = {
    model = "sonnet";
    effortLevel = "xhigh";
    language = "korean";
    theme = "auto";
    preferredNotifChannel = "ghostty";
    agentPushNotifEnabled = false;
    inputNeededNotifEnabled = false;
    cleanupPeriodDays = 30;
  };

  assertHost =
    hostName: host:
    let
      userConfig = host.config.home-manager.users.h82;
      sessionVariables = userConfig.home.sessionVariables or { };

      activation = userConfig.home.activation.claudeSettings or null;
      script = if activation == null then "" else (activation.data or "");
      # After installPackages, so a refusal cannot strand linkGeneration and
      # installPackages behind it. Asserting writeBoundary instead would pass
      # the position that causes that, since installPackages is itself after
      # writeBoundary.
      runsAfterPackages = lib.elem "installPackages" (
        if activation == null then [ ] else (activation.after or [ ])
      );

      managed = host.config.environment.etc."claude-code/managed-settings.json" or null;

      # Home Manager resolves each entry's destination from `target`, which
      # defaults to the attribute name but can be set explicitly, so an
      # attribute-name test would miss a renamed entry.
      claudeSettingsTargeted = lib.any (file: (file.target or "") == ".claude/settings.json") (
        lib.attrValues (userConfig.home.file or { })
      );

      environmentChecks = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: value: ''
          actual=${esc (sessionVariables.${name} or "")}
          if [ "$actual" != ${esc value} ]; then
            echo "Expected ${name} to be ${value} on ${hostName}, got: '$actual'" >&2
            failed=1
          fi
        '') environmentTier
      );

      activationAbsent = lib.optionalString (activation == null) ''
        echo 'missing home.activation.claudeSettings on ${hostName}' >&2
        failed=1
      '';

      activationPresent = lib.optionalString (activation != null) ''
        if [ ${esc (lib.boolToString runsAfterPackages)} != "true" ]; then
          echo 'home.activation.claudeSettings must run after installPackages on ${hostName}' >&2
          failed=1
        fi

        if ! printf '%s' ${esc script} | grep -qF '/bin/agent-settings'; then
          echo 'the claudeSettings activation script must invoke the packaged merger on ${hostName}' >&2
          failed=1
        fi

        # Swallowing the merger's exit status turns a refusal into a silent
        # no-op, which is the failure mode the no-swallow rule exists for.
        # `|| true` is only the most obvious spelling, so this matches the
        # equivalents too -- a check that names one of them lets the others
        # through while reporting the guarantee as held. The merger invocation
        # spans several lines, so this looks anywhere in this single-purpose
        # block rather than on the line naming the binary; a line-anchored
        # pattern silently passes the mutation that adds the swallow. Comment
        # lines are stripped first, because the block documents why the swallow
        # is absent and matching that sentence would fail the honest script.
        if printf '%s' ${esc script} | grep -v '^[[:space:]]*#' \
          | grep -qE '(\|\|[[:space:]]*(true|:|echo)|;[[:space:]]*true|set \+e)'; then
          echo 'the claudeSettings activation script must not swallow the merger exit status on ${hostName}' >&2
          failed=1
        fi
      '';

      managedPresent = lib.optionalString (managed != null) ''
        echo 'the managed settings tier must stay unused, but ${hostName} declares claude-code/managed-settings.json' >&2
        failed=1
      '';
    in
    ''
      ${environmentChecks}
      ${activationAbsent}${activationPresent}${managedPresent}

      # Read the flags the merger is actually invoked with, not merely whether
      # the script mentions a path somewhere. A check that greps for the store
      # path anywhere in the text passes a script that names the right file in
      # a comment and hands the merger a different one, and a check that
      # re-derives the JSON from this file's own attribute set compares a
      # literal against itself, which no mutation of the module can turn red.
      # The builder runs under `set -e -o pipefail`, so a non-matching grep
      # would abort before the remaining assertions ran and leave one mutation
      # round with evidence about a single assertion.
      settingsArg=$(printf '%s' ${esc script} \
        | tr '\n' ' ' | grep -oE -- '--settings[[:space:]]+[^[:space:]]+' \
        | head -1 | awk '{print $2}' || true)
      if [ "$settingsArg" != ${esc "${userConfig.home.homeDirectory or ""}/.claude/settings.json"} ]; then
        echo "the merger must be pointed at the real settings file on ${hostName}, got: '$settingsArg'" >&2
        failed=1
      fi

      declaredPath=$(printf '%s' ${esc script} \
        | tr '\n' ' ' | grep -oE -- '--declared[[:space:]]+/nix/store/[^[:space:]]+' \
        | head -1 | awk '{print $2}' || true)
      if [ -z "$declaredPath" ]; then
        echo 'the claudeSettings activation script passes no declared-settings file on ${hostName}' >&2
        failed=1
      elif ! diff -u "$declaredPath" "$declaredExpected" >/dev/null; then
        echo 'the declared settings this repository renders drifted from the asserted values on ${hostName}' >&2
        failed=1
      fi

      if [ ${esc (lib.boolToString claudeSettingsTargeted)} != "false" ]; then
        echo 'Home Manager must not target ~/.claude/settings.json on ${hostName}; Claude Code owns it' >&2
        failed=1
      fi
    '';

  declaredExpected = pkgs.writeText "claude-expected-settings.json" (
    builtins.toJSON {
      set = settingsTier;
      remove = [ ];
    }
  );
in
pkgs.runCommand "claude-tests" { nativeBuildInputs = [ pkgs.diffutils ]; } ''
  set -x
  failed=0
  declaredExpected=${declaredExpected}

  ${assertHost "ThinkPad-X1-Carbon-Gen-11" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11}

  ${assertHost "ThinkPad-X1-Carbon-Gen-11-bootstrap" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap}

  if [ "$failed" != "0" ]; then
    exit 1
  fi

  touch $out
''
