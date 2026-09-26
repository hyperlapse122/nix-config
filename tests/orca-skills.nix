/*
  Check interface:

    import ./tests/orca-skills.nix { inherit pkgs self; }

  Asserts that Orca's published agent skills reach every user-level skill root
  for user `h82` on every host this flake declares, at the revision matching
  the Orca build that host installs.

  The host list is taken from `self.nixosConfigurations`, so a host added later
  is covered the day it is added.

  What the check reads, and why:

  - The materialized Home Manager files (`home-files`), not the `home.file`
    option. An entry disabled with `enable = false` or retargeted through
    `target` keeps its attribute name while nothing, or something else, lands
    at the path. See
    .compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md
  - The source's own `package.json` version, not its store name. The module
    names the fetch after the packaged version, so a name comparison holds by
    construction and cannot catch a fetch pointed at another release.
  - Expected skill names from the pinned source's `skills/` listing plus a fixed
    minimum. The listing keeps an upstream addition covered without editing
    this file; the minimum keeps an empty or wrong listing from passing
    vacuously.

  Every lookup carries an `or` fallback and every conditional block is behind
  `lib.optionalString`, so a mutation that removes a declaration reaches the
  builder as shell rather than failing evaluation. See
  .compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md

  The builder collects every failure instead of exiting at the first.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  esc = value: lib.escapeShellArg (toString value);

  roots = [
    ".claude/skills"
    ".gemini/config/skills"
    ".agents/skills"
  ];

  minimumSkills = [
    "orca-cli"
    "orchestration"
  ];

  assertHost =
    hostName: host:
    let
      userConfig = host.config.home-manager.users.h82;

      orcaPkg = lib.lists.findFirst (p: (p.pname or "") == "orca-ide") null (
        userConfig.home.packages or [ ]
      );
      orcaVersion = if orcaPkg == null then "" else (orcaPkg.version or "");
      skillsSrc = if orcaPkg == null then null else (orcaPkg.skills or null);

      listedSkills =
        if skillsSrc == null then
          [ ]
        else
          lib.attrNames (
            lib.filterAttrs (_: type: type == "directory") (builtins.readDir "${skillsSrc}/skills")
          );
      expectedSkills = lib.unique (minimumSkills ++ listedSkills);

      homeFiles = userConfig.home-files or null;

      packageAbsent = lib.optionalString (orcaPkg == null) ''
        echo 'missing orca-ide in user packages on ${hostName}' >&2
        failed=1
      '';

      sourceAbsent = lib.optionalString (orcaPkg != null && skillsSrc == null) ''
        echo 'the orca-ide package exposes no pinned skills source on ${hostName}' >&2
        failed=1
      '';

      filesAbsent = lib.optionalString (homeFiles == null) ''
        echo 'missing home-files for h82 on ${hostName}' >&2
        failed=1
      '';

      assertSkill =
        root: name:
        let
          link = "${homeFiles}/${root}/${name}";
        in
        ''
          skill=${esc link}/SKILL.md
          if [ ! -s "$skill" ]; then
            echo "missing or empty ${root}/${name}/SKILL.md on ${hostName}" >&2
            failed=1
          elif ! head -n 20 "$skill" | grep -qxE 'name:[[:space:]]*${name}[[:space:]]*'; then
            echo "${root}/${name}/SKILL.md carries no 'name: ${name}' frontmatter on ${hostName}" >&2
            failed=1
          else
            # SKILL.md resolves to <source>/skills/<name>/SKILL.md whether the
            # directory or each file is linked; the source root is three up.
            sourceRoot=$(dirname "$(dirname "$(dirname "$(readlink -f "$skill")")")")
            linkedVersion=$(jq -r '.version // empty' "$sourceRoot/package.json" 2>/dev/null || true)
            if [ "$linkedVersion" != ${esc orcaVersion} ]; then
              echo "${root}/${name} comes from Orca '$linkedVersion', but ${hostName} installs Orca '${orcaVersion}'" >&2
              failed=1
            fi
          fi
        '';

      filesPresent = lib.optionalString (homeFiles != null) (
        lib.concatMapStringsSep "\n" (
          root: lib.concatMapStringsSep "\n" (assertSkill root) expectedSkills
        ) roots
      );
    in
    ''
      ${packageAbsent}${sourceAbsent}${filesAbsent}
      if [ -z ${esc orcaVersion} ]; then
        echo 'the orca-ide package carries no version on ${hostName}' >&2
        failed=1
      fi
      ${filesPresent}
    '';
in
pkgs.runCommand "orca-skills-tests"
  {
    nativeBuildInputs = [
      pkgs.gnugrep
      pkgs.jq
    ];
  }
  ''
    failed=0

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList assertHost self.nixosConfigurations)}

    if [ "$failed" != "0" ]; then
      exit 1
    fi

    touch $out
  ''
