/*
  Check interface:

    import ./tests/agent-plugins.nix { inherit pkgs self; }

  Asserts that the Nix-owned agent plugin layer reaches user `h82` on both the
  production and bootstrap ThinkPad configurations, and that its pin still
  names the revision this repository expects.

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

  The pin assertion compares two genuinely separate sources: `flake.lock`,
  which Nix writes, and the registry in home/h82/agent-plugins.nix, which a
  person writes. A tag is mutable and a relock re-resolves the ref, so the tag
  alone is not a pin -- if upstream moves it, the lock's revision changes and
  this assertion goes red instead of the change arriving as a lock diff.
  Seeding both from the lock would compare a value with itself.

  Every lookup carries an `or` fallback and every conditional block is behind
  `lib.optionalString`, so a mutation that removes a declaration reaches the
  builder as shell rather than failing evaluation on a null interpolation. See
  .compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md

  The builder collects every failure instead of exiting at the first, so one
  red build names every broken assertion across both hosts.
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

  assertHost =
    hostName: host:
    let
      userConfig = host.config.home-manager.users.h82;

      registry = userConfig.my.agentPlugins.${pluginName} or null;

      activation = userConfig.home.activation.agentPlugins or null;
      script = if activation == null then "" else (activation.data or "");
      runsAfterPackages = lib.elem "installPackages" (
        if activation == null then [ ] else (activation.after or [ ])
      );

      # Home Manager resolves a file's destination from `target`, which only
      # defaults to the attribute name, so this compares resolved targets.
      destination = if registry == null then "" else (registry.destination or "");
      destinationTargeted = lib.any (
        file: destination != "" && (file.target or "") == destination
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

        if ! printf '%s' ${esc script} | grep -qF '/bin/agent-plugin-sync'; then
          echo 'the agentPlugins activation script must invoke the packaged sync helper on ${hostName}' >&2
          failed=1
        fi

        # Swallowing the exit status turns a refusal into a silent no-op.
        # Comment lines are stripped first, because the module documents why the
        # swallow is absent and matching that sentence would fail the honest
        # script.
        if printf '%s' ${esc script} | grep -v '^[[:space:]]*#' \
          | grep -qE '(\|\|[[:space:]]*(true|:|echo)|;[[:space:]]*true|set \+e)'; then
          echo 'the agentPlugins activation script must not swallow the helper exit status on ${hostName}' >&2
          failed=1
        fi

        # --accept-command would run upstream-authored shell during activation.
        if printf '%s' ${esc script} | grep -qF -- '--accept-command'; then
          echo 'the agentPlugins activation script must never pass --accept-command on ${hostName}' >&2
          failed=1
        fi

        # The activation unit carries no session variables, so the declared
        # environment tier has to be exported around the agent CLI.
        if ! printf '%s' ${esc script} | grep -qF 'DISABLE_AUTOUPDATER='; then
          echo 'the agentPlugins activation script must export the declared DISABLE_AUTOUPDATER on ${hostName}' >&2
          failed=1
        fi

        # Read the flags the helper is actually invoked with, not merely whether
        # the script mentions a path somewhere: a script naming the right source
        # in a comment and handing the helper a different one would pass.
        sourceArg=$(printf '%s' ${esc script} \
          | tr '\n' ' ' | grep -oE -- '--source[[:space:]]+[^[:space:]]+' \
          | head -1 | awk '{print $2}' || true)
        if [ "$sourceArg" != ${esc pinnedSource} ]; then
          echo "the helper must be handed the pinned plugin source on ${hostName}, got: '$sourceArg'" >&2
          failed=1
        fi

        segmentArg=$(printf '%s' ${esc script} \
          | tr '\n' ' ' | grep -oE -- '--segment[[:space:]]+[^[:space:]]+' \
          | head -1 | awk '{print $2}' || true)
        if [ "$segmentArg" != ${esc (lib.removePrefix (if registry == null then "" else (registry.tagPrefix or "")) originalRef)} ]; then
          echo "the helper must be handed the locked tag's version segment on ${hostName}, got: '$segmentArg'" >&2
          failed=1
        fi

        claudeArg=$(printf '%s' ${esc script} \
          | tr '\n' ' ' | grep -oE -- '--claude[[:space:]]+[^[:space:]]+' \
          | head -1 | awk '{print $2}' || true)
        case "$claudeArg" in
          /nix/store/*/bin/claude) ;;
          *)
            echo "the agent CLI must be named by store path on ${hostName}, got: '$claudeArg'" >&2
            failed=1
            ;;
        esac
      '';

      symlinkPresent = lib.optionalString destinationTargeted ''
        echo 'Home Manager must not link ${destination} on ${hostName}; the activation entry owns it' >&2
        failed=1
      '';
    in
    ''
      ${registryAbsent}${registryPresent}
      ${activationAbsent}${activationPresent}${symlinkPresent}
    '';
in
pkgs.runCommand "agent-plugins-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
  set -x
  failed=0

  if [ -z ${esc lockedRev} ]; then
    echo 'flake.lock records no revision for the compound-engineering-plugin input' >&2
    failed=1
  fi

  if [ -z ${esc originalRef} ]; then
    echo 'flake.lock records no tag for the compound-engineering-plugin input; the pin must name a release tag, not a branch' >&2
    failed=1
  fi

  # R17: this work leaves the project-scope dotagents declaration alone.
  if ! printf '%s' ${esc agentsToml} | grep -qF 'EveryInc/compound-engineering-plugin'; then
    echo 'agents.toml no longer declares the plugin for the project scope' >&2
    failed=1
  fi

  ${assertHost "ThinkPad-X1-Carbon-Gen-11" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11}

  ${assertHost "ThinkPad-X1-Carbon-Gen-11-bootstrap" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap}

  if [ "$failed" != "0" ]; then
    exit 1
  fi

  touch $out
''
