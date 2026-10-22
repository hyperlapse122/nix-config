/*
  Check interface:

    import ./tests/agent-plugins.nix { inherit pkgs self; }

  Asserts that the Nix-owned agent plugin layer reaches user `h82` on every
  host this flake declares, and that its pin still names the revision this
  repository expects.

  The configuration list comes from `tests/lib/configurations.nix` rather than
  being written out, so a host added later is covered the day it is added
  instead of silently escaping the assertions, and the helper's guard fails the
  build when that list is empty. Every configuration shares `home/h82`, so the
  layer holds on all of them.

  What this check can and cannot reach:

  - The wiring's command sequence lives in the packaged `agent-plugin-sync`
    helper, not in the activation script, so its order, rollback, readback and
    pruning are proven by the `agent-plugin-sync` check in flake.nix, which
    drives the real script against a fake agent CLI. Asserting the order here
    would only re-read a string this check also builds.
  - What activation *materializes* is this check's job: that the entry exists,
    is ordered so a refusal cannot strand installPackages, hands the helper the
    pinned source rather than some other path, and names the version segment
    the lock actually resolved.
  - The OpenCode and Pi rows need no agent CLI, so this check runs them: the
    packaged helper, with the flags the activation script hands it, against a
    scratch home seeded with user entries (a string and a non-string plugin
    for OpenCode, a skills path for Pi). Only --base is moved into the scratch
    directory, because the rendered one sits under /home/h82. Each row must
    share Claude's base and run before Claude's, whose prune would otherwise
    delete a link they still name. Pi's row lists the plugin's `skills`
    directory in ~/.pi/agent/settings.json.

  The pin assertion compares two genuinely separate sources: `flake.lock`,
  which Nix writes, and the registry in home/h82/agents/agent-plugins.nix, which a
  person writes. A tag is mutable and a relock re-resolves the ref, so the tag
  alone is not a pin -- if upstream moves it, the lock's revision changes and
  this assertion goes red instead of the change arriving as a lock diff.
  Seeding both from the lock would compare a value with itself.

  What the segment comparison does and does not catch, established by mutation
  rounds rather than by reading it: changing the registry's `tag` without
  relocking turns it red for its own reason on every configuration, which is
  the drift it exists for. Changing `tagPrefix` leaves it green, because the prefix is
  stripped from both the registry's tag and the lock's ref -- both sides move
  together, so that axis is consistent by construction rather than guarded.
  Do not read the prefix as protected here.

  Every lookup carries an `or` fallback and every conditional block is behind
  `lib.optionalString`, so a mutation that removes a declaration reaches the
  builder as shell rather than failing evaluation on a null interpolation. See
  .compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md

  The builder collects every failure instead of exiting at the first, so one
  red build names every broken assertion across every configuration.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  esc = value: lib.escapeShellArg (toString value);

  pluginName = "compound-engineering";

  lock = builtins.fromJSON (builtins.readFile ../flake.lock);
  lockNode = lock.nodes.compound-engineering-plugin or { };
  lockedRev = lockNode.locked.rev or "";
  originalRef = lockNode.original.ref or "";

  agentsToml = builtins.readFile ../agents.toml;

  pinnedSource = toString (self.inputs.compound-engineering-plugin or "");

  configurations = import ./lib/configurations.nix { inherit pkgs self; };

  assertEntry =
    entry:
    let
      hostName = entry.name;
      userConfig = entry.user;

      registry = userConfig.my.agentPlugins.${pluginName} or null;

      # Compared against below so each harness's --cli flag can never silently
      # drift onto a different build than the one installed for the user.
      packagePath =
        pname: executable:
        let
          found = lib.lists.findFirst (p: (p.pname or "") == pname) null (userConfig.home.packages or [ ]);
        in
        if found == null then "" else "${found}/bin/${executable}";
      claudeCli = packagePath "claude-code" "claude";
      harnessChecks = [
        {
          name = "claude";
          pname = "claude-code";
          expectedCli = claudeCli;
        }
        {
          name = "codex";
          pname = "codex";
          expectedCli = packagePath "codex" "codex";
        }
        {
          name = "antigravity";
          pname = "antigravity-cli";
          expectedCli = packagePath "antigravity-cli" "agy";
        }
      ];

      # OpenCode's row is driven through the merger OpenCode's own settings
      # merge runs, read from that activation script.
      opencodeSettingsScript = userConfig.home.activation.opencodeSettings.data or "";
      piSettingsScript = userConfig.home.activation.piSettings.data or "";

      activation = userConfig.home.activation.agentPlugins or null;
      script = if activation == null then "" else (activation.data or "");
      runsAfterPackages = lib.elem "installPackages" (
        if activation == null then [ ] else (activation.after or [ ])
      );

      # Home Manager resolves a file's destination from `target`, which only
      # defaults to the attribute name, so this compares resolved targets.
      destination = if registry == null then "" else (registry.destination or "");
      destinationTargeted = lib.any (file: destination != "" && (file.target or "") == destination) (
        lib.attrValues (userConfig.home.file or { })
      );

      # agy copies the plugin there and replaces the whole tree on each
      # install, so a Home Manager link there would be overwritten or block
      # the install. Targets are relative to the home directory.
      agyInstallDir = ".gemini/config/plugins/${pluginName}";
      agyInstallTargeted = lib.any (
        file:
        let
          target = file.target or "";
        in
        # A link on the directory, inside it, or on an ancestor such as
        # ~/.gemini/config/plugins all put a store path where agy installs.
        target == agyInstallDir
        || lib.hasPrefix "${agyInstallDir}/" target
        || (target != "" && lib.hasPrefix "${target}/" agyInstallDir)
      ) (lib.attrValues (userConfig.home.file or { }));

      registryAbsent = lib.optionalString (registry == null) ''
        echo 'missing my.agentPlugins.${pluginName} on ${hostName}' >&2
        failed=1
      '';

      registryPresent = lib.optionalString (registry != null) ''
        # The lock is written by Nix; the expected revision is written by hand.
        expectedRev=${esc (registry.expectedRev or "")}
        if [ "$expectedRev" != ${esc lockedRev} ]; then
          echo "the pinned plugin revision drifted on ${hostName}: registry expects '$expectedRev', flake.lock resolved '${lockedRev}'" >&2
          failed=1
        fi

        # The segment must come from the tag the lock records, not from the
        # registry's own tag, or the comparison reads one source twice.
        segment=${esc (registry.segment or "")}
        lockSegment=${esc (lib.removePrefix (registry.tagPrefix or "") originalRef)}
        if [ "$segment" != "$lockSegment" ]; then
          echo "the materialized version segment '$segment' does not match the locked tag's '$lockSegment' on ${hostName}" >&2
          failed=1
        fi

        case ${esc destination} in
          *"/$segment") ;;
          *)
            echo "the materialized destination must end in the version segment on ${hostName}, got: ${destination}" >&2
            failed=1
            ;;
        esac
      '';

      activationAbsent = lib.optionalString (activation == null) ''
        echo 'missing home.activation.agentPlugins on ${hostName}' >&2
        failed=1
      '';

      activationPresent = lib.optionalString (activation != null) ''
        if [ ${esc (lib.boolToString runsAfterPackages)} != "true" ]; then
          echo 'home.activation.agentPlugins must run after installPackages on ${hostName}' >&2
          failed=1
        fi

        # The script is fed as a here-string, never piped from printf: grep -q
        # exits on its first match, and under the builder's pipefail the
        # writer's SIGPIPE then fails a pipeline that matched.
        if ! grep -qF '/bin/agent-plugin-sync' <<< ${esc script}; then
          echo 'the agentPlugins activation script must invoke the packaged sync helper on ${hostName}' >&2
          failed=1
        fi

        # Swallowing the exit status turns a refusal into a silent no-op.
        # Comment lines are stripped first, because the module documents why the
        # swallow is absent and matching that sentence would fail the honest
        # script.
        if grep -v '^[[:space:]]*#' <<< ${esc script} \
          | grep -E '(\|\|[[:space:]]*(true|:|echo)|;[[:space:]]*true|set \+e)' > /dev/null; then
          echo 'the agentPlugins activation script must not swallow the helper exit status on ${hostName}' >&2
          failed=1
        fi

        # --accept-command would run upstream-authored shell during activation.
        if grep -qF -- '--accept-command' <<< ${esc script}; then
          echo 'the agentPlugins activation script must never pass --accept-command on ${hostName}' >&2
          failed=1
        fi

        # Each harness's invocation is read separately: with a Claude, a Codex
        # and an Antigravity row for the same plugin, a block chosen by plugin name
        # alone would check whichever came first and let the other drift.
        ${lib.concatMapStrings (harness: ''
          block=$(blockForHarness ${esc script} ${esc pluginName} ${esc harness.name})
          if [ -z "$block" ]; then
            echo "the agentPlugins activation script never syncs ${pluginName} for ${harness.name} on ${hostName}" >&2
            failed=1
          fi

          # Read the flags the helper is actually invoked with, not merely
          # whether the script mentions a path somewhere: a script naming the
          # right source in a comment and handing the helper a different one
          # would pass.
          sourceArg=$(argValue "$block" source)
          if [ "$sourceArg" != ${esc pinnedSource} ]; then
            echo "the ${harness.name} helper must be handed the pinned plugin source on ${hostName}, got: '$sourceArg'" >&2
            failed=1
          fi

          segmentArg=$(argValue "$block" segment)
          if [ "$segmentArg" != ${
            esc (lib.removePrefix (if registry == null then "" else (registry.tagPrefix or "")) originalRef)
          } ]; then
            echo "the ${harness.name} helper must be handed the locked tag's version segment on ${hostName}, got: '$segmentArg'" >&2
            failed=1
          fi

          cliArg=$(argValue "$block" cli)
          if [ -z ${esc harness.expectedCli} ]; then
            echo 'missing ${harness.pname} in user packages on ${hostName}' >&2
            failed=1
          elif [ "$cliArg" != ${esc harness.expectedCli} ]; then
            echo "the ${harness.name} CLI's store path must match the ${harness.pname} package in home.packages on ${hostName}, got: '$cliArg'" >&2
            failed=1
          fi
        '') harnessChecks}

        opencodeBlock=$(blockForHarness ${esc script} ${esc pluginName} opencode)
        claudeBlock=$(blockForHarness ${esc script} ${esc pluginName} claude)
        if [ -z "$opencodeBlock" ]; then
          echo "the agentPlugins activation script never syncs ${pluginName} for opencode on ${hostName}" >&2
          failed=1
        else
          sourceArg=$(argValue "$opencodeBlock" source)
          if [ "$sourceArg" != ${esc pinnedSource} ]; then
            echo "the opencode helper must be handed the pinned plugin source on ${hostName}, got: '$sourceArg'" >&2
            failed=1
          fi
          segmentArg=$(argValue "$opencodeBlock" segment)
          if [ "$segmentArg" != ${
            esc (lib.removePrefix (if registry == null then "" else (registry.tagPrefix or "")) originalRef)
          } ]; then
            echo "the opencode helper must be handed the locked tag's version segment on ${hostName}, got: '$segmentArg'" >&2
            failed=1
          fi
          cliArg=$(argValue "$opencodeBlock" cli)
          merger=$(tr '\n' ' ' <<< ${esc opencodeSettingsScript} \
            | grep -oE -- '/nix/store/[^[:space:]]+/bin/agent-settings' | head -1 || true)
          if [ -z "$merger" ]; then
            echo 'home.activation.opencodeSettings invokes no packaged merger on ${hostName}' >&2
            failed=1
          elif [ "$cliArg" != "$merger" ]; then
            echo "the opencode helper must be handed the merger OpenCode's settings merge runs on ${hostName}, got: '$cliArg'" >&2
            failed=1
          fi
          baseArg=$(argValue "$opencodeBlock" base)
          if [ "$baseArg" != "$(argValue "$claudeBlock" base)" ]; then
            echo "the opencode and claude rows must share one base on ${hostName}, got: '$baseArg'" >&2
            failed=1
          fi
          flat=$(tr '\n' ' ' <<< ${esc script})
          beforeOpencode=''${flat%%--harness opencode*}
          beforeClaude=''${flat%%--harness claude*}
          if [ "''${#beforeOpencode}" -ge "''${#beforeClaude}" ]; then
            echo 'the opencode row must run before the claude row on ${hostName}' >&2
            failed=1
          fi

          helper=$(grep -oE -- '/nix/store/[^[:space:]]+/bin/agent-plugin-sync' <<< "$flat" | head -1 || true)
          scratch=$(mktemp -d)
          mkdir -p "$scratch/home/.config/opencode"
          printf '%s\n' '{"plugins": ["opencode-user-plugin@1.2.0", ["opencode-tuple-plugin", {"x": 1}]]}' \
            > "$scratch/home/.config/opencode/opencode.json"
          if ! HOME="$scratch/home" "$helper" --harness opencode --cli "$cliArg" \
            --source "$sourceArg" --base "$scratch/base" --segment "$segmentArg" \
            --plugin "$(argValue "$opencodeBlock" plugin | tr -d "'")" \
            --marketplace "$(argValue "$opencodeBlock" marketplace | tr -d "'")"; then
            echo "the rendered opencode invocation failed on ${hostName}" >&2
            failed=1
          fi
          listed=$(jq -c '.plugins' "$scratch/home/.config/opencode/opencode.json" 2>/dev/null || true)
          want=$(jq -cn --arg link "$scratch/base/$segmentArg" '["opencode-user-plugin@1.2.0", ["opencode-tuple-plugin", {"x": 1}], $link]')
          if [ "$listed" != "$want" ]; then
            echo "opencode.json must list the user plugins and the pinned link on ${hostName}, got: '$listed'" >&2
            failed=1
          elif [ "$(readlink "$scratch/base/$segmentArg")" != ${esc pinnedSource} ]; then
            echo "the link opencode.json names must point at the pinned source on ${hostName}" >&2
            failed=1
          fi
          rm -rf "$scratch"
        fi

        piBlock=$(blockForHarness ${esc script} ${esc pluginName} pi)
        if [ -z "$piBlock" ]; then
          echo "the agentPlugins activation script never syncs ${pluginName} for pi on ${hostName}" >&2
          failed=1
        else
          sourceArg=$(argValue "$piBlock" source)
          if [ "$sourceArg" != ${esc pinnedSource} ]; then
            echo "the pi helper must be handed the pinned plugin source on ${hostName}, got: '$sourceArg'" >&2
            failed=1
          fi
          segmentArg=$(argValue "$piBlock" segment)
          if [ "$segmentArg" != ${
            esc (lib.removePrefix (if registry == null then "" else (registry.tagPrefix or "")) originalRef)
          } ]; then
            echo "the pi helper must be handed the locked tag's version segment on ${hostName}, got: '$segmentArg'" >&2
            failed=1
          fi
          cliArg=$(argValue "$piBlock" cli)
          merger=$(tr '\n' ' ' <<< ${esc piSettingsScript} \
            | grep -oE -- '/nix/store/[^[:space:]]+/bin/agent-settings' | head -1 || true)
          if [ -z "$merger" ]; then
            echo 'home.activation.piSettings invokes no packaged merger on ${hostName}' >&2
            failed=1
          elif [ "$cliArg" != "$merger" ]; then
            echo "the pi helper must be handed the merger Pi's settings merge runs on ${hostName}, got: '$cliArg'" >&2
            failed=1
          fi
          baseArg=$(argValue "$piBlock" base)
          if [ "$baseArg" != "$(argValue "$claudeBlock" base)" ]; then
            echo "the pi and claude rows must share one base on ${hostName}, got: '$baseArg'" >&2
            failed=1
          fi
          flat=$(tr '\n' ' ' <<< ${esc script})
          beforePi=''${flat%%--harness pi*}
          beforeClaude=''${flat%%--harness claude*}
          if [ "''${#beforePi}" -ge "''${#beforeClaude}" ]; then
            echo 'the pi row must run before the claude row on ${hostName}' >&2
            failed=1
          fi

          helper=$(grep -oE -- '/nix/store/[^[:space:]]+/bin/agent-plugin-sync' <<< "$flat" | head -1 || true)
          scratch=$(mktemp -d)
          mkdir -p "$scratch/home/.pi/agent"
          printf '%s\n' '{"skills": ["/home/user/skills/mine"], "theme": "dark"}' \
            > "$scratch/home/.pi/agent/settings.json"
          if ! HOME="$scratch/home" "$helper" --harness pi --cli "$cliArg" \
            --source "$sourceArg" --base "$scratch/base" --segment "$segmentArg" \
            --plugin "$(argValue "$piBlock" plugin | tr -d "'")" \
            --marketplace "$(argValue "$piBlock" marketplace | tr -d "'")"; then
            echo "the rendered pi invocation failed on ${hostName}" >&2
            failed=1
          fi
          listed=$(jq -c '.skills' "$scratch/home/.pi/agent/settings.json" 2>/dev/null || true)
          want=$(jq -cn --arg link "$scratch/base/$segmentArg/skills" '["/home/user/skills/mine", $link]')
          if [ "$listed" != "$want" ]; then
            echo "settings.json must list the user skills and the pinned skills directory on ${hostName}, got: '$listed'" >&2
            failed=1
          elif [ "$(jq -r '.theme' "$scratch/home/.pi/agent/settings.json")" != dark ]; then
            echo "the pi sync must keep the other settings keys on ${hostName}" >&2
            failed=1
          elif [ "$(readlink "$scratch/base/$segmentArg")" != ${esc pinnedSource} ]; then
            echo "the link settings.json names must point at the pinned source on ${hostName}" >&2
            failed=1
          fi
          rm -rf "$scratch"
        fi

        # The activation unit carries no session variables, so Claude Code's
        # declared environment tier has to be exported around its CLI.
        if ! grep -qF 'DISABLE_AUTOUPDATER=' <<< "$(blockForHarness ${esc script} ${esc pluginName} claude)"; then
          echo 'the Claude plugin sync must export the declared DISABLE_AUTOUPDATER on ${hostName}' >&2
          failed=1
        fi
      '';

      symlinkPresent = lib.optionalString destinationTargeted ''
        echo 'Home Manager must not link ${destination} on ${hostName}; the activation entry owns it' >&2
        failed=1
      '';
      agyLinkPresent = lib.optionalString agyInstallTargeted ''
        echo 'Home Manager must not link ~/${agyInstallDir} on ${hostName}; agy owns its installed copy' >&2
        failed=1
      '';
    in
    ''
      ${registryAbsent}${registryPresent}
      ${activationAbsent}${activationPresent}${symlinkPresent}${agyLinkPresent}
    '';
in
pkgs.runCommand "agent-plugins-tests"
  {
    nativeBuildInputs = [
      pkgs.gnugrep
      pkgs.jq
    ];
  }
  ''
    set -x
    ${configurations.guard}
    failed=0

    # Reads one flag's value out of a rendered activation script. The `|| true`
    # keeps a non-matching grep from aborting the builder under pipefail, so an
    # absent flag reaches its own assertion as an empty string.
    argValue() {
      printf '%s' "$1" | tr '\n' ' ' \
        | grep -oE -- "--$2[[:space:]]+[^[:space:]]+" | head -1 | awk '{print $2}' || true
    }

    # The activation script runs the helper once per plugin, so each plugin's
    # flags are read from the one invocation whose --plugin names it. An absent
    # invocation yields an empty block, which every flag assertion then reports.
    blocksFor() {
      printf '%s' "$1" | tr '\n' ' ' | sed 's|/bin/agent-plugin-sync|\n&|g' \
        | grep -E -- "--plugin[[:space:]]+'?$2'?([[:space:]]|$)" || true
    }
    blockForHarness() {
      blocksFor "$1" "$2" | grep -E -- "--harness[[:space:]]+'?$3'?([[:space:]]|$)" | head -1 || true
    }

    if [ -z ${esc lockedRev} ]; then
      echo 'flake.lock records no revision for the compound-engineering-plugin input' >&2
      failed=1
    fi

    if [ -z ${esc originalRef} ]; then
      echo 'flake.lock records no tag for the compound-engineering-plugin input; the pin must name a release tag, not a branch' >&2
      failed=1
    fi

    # This work installs the plugin for the user; the project-scope dotagents
    # declaration is a separate layer and stays exactly as it was.
    if ! grep -qF 'EveryInc/compound-engineering-plugin' <<< ${esc agentsToml}; then
      echo 'agents.toml no longer declares the plugin for the project scope' >&2
      failed=1
    fi

    ${lib.concatMapStringsSep "\n" assertEntry configurations.entries}

    if [ "$failed" != "0" ]; then
      exit 1
    fi

    touch $out
  ''
