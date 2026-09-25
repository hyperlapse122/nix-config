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

  # Single source of truth with home/h82/default.nix's package list, so this
  # command's --claude flag can never drift onto a different claude-code build.
  claudeCode = import ../../../packages/claude-code.nix { inherit pkgs; };

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
      tag = "compound-engineering-v3.29.0";
      expectedRev = "4043703d32c5df9e35f22757dee22f3a72a99c66";
      # Read from the source's own manifests, never invented here: the install
      # identifier is `<plugin>@<marketplace>`.
      plugin = "compound-engineering";
      marketplace = "compound-engineering-plugin";
      # Repository-relative path prefixes withheld from a given harness; an
      # empty list offers the whole tree. The field exists from the outset
      # because one harness can misclassify a tree another accepts.
      exclude = {
        claude = [ ];
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
  ];

  knownHarnesses = [ "claude" ];

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

  claudeRows = lib.filter (row: row.harness == "claude") checkedMembership;

  syncInvocation =
    row:
    let
      spec = sources.${row.name};
    in
    ''
      env ${claudeEnv} ${syncTool} \
        --claude ${claudeCode}/bin/claude \
        --source ${treeFor row.name spec row.harness} \
        --base ${lib.escapeShellArg "${baseDir}/${row.name}"} \
        --segment ${lib.escapeShellArg (segmentOf spec)} \
        --plugin ${lib.escapeShellArg spec.plugin} \
        --marketplace ${lib.escapeShellArg spec.marketplace}'';

  syncScript = lib.concatMapStringsSep "\n" (row: ''
    if [[ -v DRY_RUN ]]; then
      ${syncInvocation row} --dry-run
    else
      ${syncInvocation row}
    fi
  '') claudeRows;
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
    default = lib.mapAttrs (name: spec: {
      inherit (spec)
        upstream
        tagPrefix
        tag
        expectedRev
        plugin
        marketplace
        exclude
        ;
      segment = segmentOf spec;
      destination = "${baseDir}/${name}/${segmentOf spec}";
    }) sources;
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
