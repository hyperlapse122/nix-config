{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  syncTool = "${
    (import ../../../packages/agent-tools.nix { inherit pkgs; }).agentPluginSync
  }/bin/agent-plugin-sync";

  # Single source of truth with home/h82/default.nix's package list, so each
  # command's --cli flag can never drift onto a different agent build.
  claudeCode = import ../../../packages/claude-code.nix { inherit pkgs; };
  codex = import ../../../packages/codex.nix { inherit pkgs; };

  # Neutral source registry: what a plugin is and where it comes from, with no
  # opinion about which agent gets it. `tag` is the pin; `expectedRev` is the
  # revision that tag is expected to name, because a git tag is mutable and a
  # relock re-resolves the ref rather than the revision. tests/agent-plugins.nix
  # compares expectedRev against what flake.lock actually recorded, so a
  # re-pointed upstream tag fails a check instead of arriving as a lock diff.
  sources = {
    compound-engineering = {
      src = inputs.compound-engineering-plugin;
      upstream = "EveryInc/compound-engineering-plugin";
      # Upstream interleaves several tag trains in one namespace, so resolution
      # filters on this prefix. Stripping it from `tag` also yields the version
      # segment the materialized path is keyed by.
      tagPrefix = "compound-engineering-";
      tag = "compound-engineering-v3.30.1";
      expectedRev = "0bad48863a53a9eb0c996dbf0a6d2bfe243c9689";
      # Read from the source's own manifests, never invented here: the install
      # identifier is `<plugin>@<marketplace>`.
      plugin = "compound-engineering";
      marketplace = "compound-engineering-plugin";
      # Repository-relative path prefixes withheld from a given harness; an
      # empty list offers the whole tree. The field exists from the outset
      # because one harness can misclassify a tree another accepts.
      exclude = {
        claude = [ ];
        codex = [ ];
      };
    };
  };

  # Harness membership is declared separately from the source, so adding a
  # plugin to another agent is a row rather than a second source entry.
  membership = [
    {
      name = "compound-engineering";
      harness = "claude";
    }
    {
      name = "compound-engineering";
      harness = "codex";
    }
  ];

  # The CLI each harness is driven through, and the environment it runs with.
  # Activation carries neither home.packages on PATH nor
  # home.sessionVariables, so Claude Code's declared tier is exported around
  # it; Codex's update overrides travel inside its wrapper instead.
  harnesses = {
    claude = {
      cli = "${claudeCode}/bin/claude";
      env = claudeEnv;
    };
    codex = {
      cli = "${codex}/bin/codex";
      env = "";
    };
  };

  knownHarnesses = lib.attrNames harnesses;

  badHarness = lib.filter (row: !(lib.elem row.harness knownHarnesses)) membership;
  badName = lib.filter (row: !(sources ? ${row.name})) membership;

  # An unknown harness or plugin name stops evaluation rather than silently
  # installing nothing, which would look identical to a working configuration.
  checkedMembership =
    lib.throwIf (badHarness != [ ])
      "agent-plugins: membership names unknown harness(es): ${
        lib.concatMapStringsSep ", " (row: row.harness) badHarness
      }"
      (
        lib.throwIf (badName != [ ]) "agent-plugins: membership names undeclared plugin(s): ${
          lib.concatMapStringsSep ", " (row: row.name) badName
        }" membership
      );

  baseDir = "${config.home.homeDirectory}/.local/share/agent-plugins";

  # A source's segment is its tag without the train prefix, the same version
  # the materialized path is keyed by.
  segmentOf = spec: lib.removePrefix spec.tagPrefix spec.tag;

  # A harness with exclusions gets its own pruned tree; one without reads the
  # pinned source directly, so the ordinary case adds no derivation.
  treeFor =
    name: spec: harness:
    let
      excluded = spec.exclude.${harness} or [ ];
    in
    if excluded == [ ] then
      spec.src
    else
      pkgs.runCommand "${name}-${harness}-tree" { } ''
        cp -r ${spec.src} $out
        chmod -R u+w $out
        ${lib.concatMapStringsSep "\n" (path: "rm -rf $out/${path}") excluded}
      '';

  # Read the declared values rather than restating them: claude.nix owns this
  # tier, and the activation unit carries neither home.packages on PATH nor
  # home.sessionVariables, so the CLI would otherwise run on upstream defaults.
  claudeEnvKeys = [
    "DISABLE_AUTOUPDATER"
    "CLAUDE_CODE_DISABLE_AUTO_MEMORY"
  ];
  claudeEnv = lib.concatMapStringsSep " " (
    key: "${key}=${lib.escapeShellArg (toString config.home.sessionVariables.${key})}"
  ) (lib.filter (key: config.home.sessionVariables ? ${key}) claudeEnvKeys);

  syncInvocation =
    row:
    let
      spec = sources.${row.name};
      harness = harnesses.${row.harness};
    in
    ''
      env ${harness.env} ${syncTool} \
        --harness ${row.harness} \
        --cli ${harness.cli} \
        --source ${treeFor row.name spec row.harness} \
        --base ${lib.escapeShellArg "${baseDir}/${row.name}"} \
        --segment ${lib.escapeShellArg (segmentOf spec)} \
        --plugin ${lib.escapeShellArg spec.plugin} \
        --marketplace ${lib.escapeShellArg spec.marketplace}'';

  # Plugins this repository used to install and has since dropped. Removing a
  # row from `sources` alone leaves the plugin registered with its agent, and
  # its hooks keep firing, on every machine that ran an earlier generation.
  # Move it here instead, and delete the entry once every host has rebuilt
  # past it.
  retired = [
    {
      name = "orca-orchestration";
      harness = "claude";
      plugin = "orca-orchestration";
      marketplace = "orca-orchestration";
    }
  ];

  retireInvocation =
    row:
    let
      harness = harnesses.${row.harness};
    in
    ''
      env ${harness.env} ${syncTool} --retire \
        --harness ${row.harness} \
        --cli ${harness.cli} \
        --base ${lib.escapeShellArg "${baseDir}/${row.name}"} \
        --plugin ${lib.escapeShellArg row.plugin} \
        --marketplace ${lib.escapeShellArg row.marketplace}'';

  withDryRun = invocation: ''
    if [[ -v DRY_RUN ]]; then
      ${invocation} --dry-run
    else
      ${invocation}
    fi
  '';

  syncScript = lib.concatStringsSep "\n" (
    map (row: withDryRun (syncInvocation row)) checkedMembership
    ++ map (row: withDryRun (retireInvocation row)) retired
  );
in
{
  # Exposed so tests/agent-plugins.nix can compare the recorded expectation
  # against what flake.lock actually resolved. The two are genuinely separate
  # sources: this registry is hand-written, the lock is produced by Nix, and a
  # mutation of either turns the check red.
  options.my.agentPlugins = lib.mkOption {
    type = lib.types.attrs;
    internal = true;
    readOnly = true;
    # Every declared field except the source tree itself, so each source keeps
    # its pin bookkeeping.
    default = lib.mapAttrs (
      name: spec:
      removeAttrs spec [ "src" ]
      // {
        segment = segmentOf spec;
        destination = "${baseDir}/${name}/${segmentOf spec}";
      }
    ) sources;
    description = "Resolved agent plugin registry, for repository checks.";
  };

  # Unguarded and after installPackages for the same reasons as the merges in
  # claude.nix and gemini.nix: the tool is a store path built from this module,
  # so a guard could only ever be true, and a refusal ordered before
  # installPackages would strand it. Note that linkGeneration sits behind these
  # entries in the built activation script, so this position keeps a refusal
  # from stranding installPackages but not from stranding linkGeneration.
  #
  # The version-keyed path is created here rather than declared as a Home
  # Manager file: this entry runs before linkGeneration, so a declared link
  # would not yet exist when the wiring reads it, and creating it here also
  # keeps the superseded version present until the new one is wired.
  config.home.activation.agentPlugins = lib.hm.dag.entryAfter [ "installPackages" ] syncScript;
}
