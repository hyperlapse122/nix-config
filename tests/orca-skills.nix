/*
  Check interface:

    import ./tests/orca-skills.nix { inherit pkgs self; }

  Asserts that Orca's published agent skills reach every user-level skill root
  for user `h82` on every host this flake declares, at the revision matching
  the Orca build that host installs, in a form Orca itself recognizes.

  The host list is taken from `self.nixosConfigurations`, so a host added later
  is covered the day it is added.

  What the check reads, and why:

  - The materialized activation script, run against a fixture home, not the
    module's option values. Orca rejects a skill file whose link count is not
    1 and then reports the skill as unrecognized with no installed version;
    auto-optimise-store hardlinks store files, so a link into the store passes
    every content assertion while Orca still disowns it. Only running the
    installer shows what actually lands in a home. See
    .compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md
  - A fixture seeded with the state the previous design left behind: a
    store-linked skill, a stale copy carrying an extra file, a skill an older
    run installed that the source no longer ships, a staging copy a killed run
    left behind, and a user's own skill. A
    converged fixture would pass whether or not the installer replaces, prunes,
    or spares anything. See
    .compound-engineering/artifacts/solutions/best-practices/converged-fixture-state-defeats-nix-check-mutation-testing.md
  - The executable-bit comparison is latent: v1.4.206 ships no executable skill
    file, so it cannot go red until one does. Orca digests that bit, which is
    why it is compared at all.
  - The source's own `package.json` version, not its store name. The package
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

  storeLinkRoot = ".claude/skills";
  staleCopyRoot = ".gemini/config/skills";

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

      activation = userConfig.home.activation.orcaSkills or null;
      script = if activation == null then "" else (activation.data or "");
      after = if activation == null then [ ] else (activation.after or [ ]);

      homeFiles = userConfig.home-files or null;

      packageAbsent = lib.optionalString (orcaPkg == null) ''
        echo 'missing orca-ide in user packages on ${hostName}' >&2
        failed=1
      '';

      sourceAbsent = lib.optionalString (orcaPkg != null && skillsSrc == null) ''
        echo 'the orca-ide package exposes no pinned skills source on ${hostName}' >&2
        failed=1
      '';

      activationAbsent = lib.optionalString (activation == null) ''
        echo 'missing home.activation.orcaSkills on ${hostName}' >&2
        failed=1
      '';

      activationOrder = lib.optionalString (activation != null && !(lib.elem "linkGeneration" after)) ''
        echo 'home.activation.orcaSkills must run after linkGeneration on ${hostName}' >&2
        failed=1
      '';

      sourceVersion = lib.optionalString (skillsSrc != null) ''
        sourceVersion=$(jq -r '.version // empty' ${esc skillsSrc}/package.json 2>/dev/null || true)
        if [ "$sourceVersion" != ${esc orcaVersion} ]; then
          echo "the skills source is Orca '$sourceVersion', but ${hostName} installs Orca '${orcaVersion}'" >&2
          failed=1
        fi
      '';

      # A second owner of the same paths would put the store links back.
      declaredLinks = lib.optionalString (homeFiles != null) (
        lib.concatMapStringsSep "\n" (
          root:
          lib.concatMapStringsSep "\n" (name: ''
            if [ -e ${esc "${homeFiles}/${root}/${name}"} ]; then
              echo "${root}/${name} is still declared as a Home Manager file on ${hostName}" >&2
              failed=1
            fi
          '') expectedSkills
        ) roots
      );

      assertSkill =
        root: name:
        let
          source = "${skillsSrc}/skills/${name}";
        in
        ''
          target="$HOME"/${esc root}/${esc name}
          if [ -L "$target" ] || [ ! -d "$target" ]; then
            echo "${root}/${name} is not a plain directory on ${hostName}" >&2
            failed=1
          elif ! diff -r ${esc source} "$target" >/dev/null; then
            echo "${root}/${name} differs from the pinned source on ${hostName}" >&2
            failed=1
          else
            while IFS= read -r -d "" file; do
              rel=''${file#"$target"/}
              if [ -L "$file" ]; then
                echo "${root}/${name}/$rel is a symlink on ${hostName}" >&2
                failed=1
              elif [ -f "$file" ]; then
                if [ "$(stat -c %h "$file")" != 1 ]; then
                  echo "${root}/${name}/$rel has link count $(stat -c %h "$file"), which Orca rejects, on ${hostName}" >&2
                  failed=1
                fi
                if { [ -x "$file" ] && [ ! -x ${esc source}/"$rel" ]; } \
                  || { [ ! -x "$file" ] && [ -x ${esc source}/"$rel" ]; }; then
                  echo "${root}/${name}/$rel changed its executable bit on ${hostName}" >&2
                  failed=1
                fi
              fi
            done < <(find "$target" -mindepth 1 -print0)
            if ! head -n 20 "$target/SKILL.md" | grep -qxE 'name:[[:space:]]*${name}[[:space:]]*'; then
              echo "${root}/${name}/SKILL.md carries no 'name: ${name}' frontmatter on ${hostName}" >&2
              failed=1
            fi
          fi
        '';

      seedRoot = root: ''
        mkdir -p "$HOME"/${esc root}/mine "$HOME"/${esc root}/retired-skill
        echo mine >"$HOME"/${esc root}/mine/SKILL.md
        echo old >"$HOME"/${esc root}/retired-skill/SKILL.md
        printf '%s\n' retired-skill orca-cli >"$HOME"/${esc root}/.orca-skills
      '';

      # The previous design's link into the store, and a stale copy that must
      # be replaced rather than merged into.
      seedStale = lib.optionalString (skillsSrc != null) ''
        ln -s ${esc "${skillsSrc}/skills/orca-cli"} "$HOME"/${esc storeLinkRoot}/orca-cli
        mkdir -p "$HOME"/${esc staleCopyRoot}/orca-cli
        echo stale >"$HOME"/${esc staleCopyRoot}/orca-cli/stale.md
        mkdir -p "$HOME"/${esc staleCopyRoot}/.orca-cli.Abc123
        echo stale >"$HOME"/${esc staleCopyRoot}/.orca-cli.Abc123/SKILL.md
      '';

      assertRoot = root: ''
        if [ ! -f "$HOME"/${esc root}/mine/SKILL.md ]; then
          echo "the user's own skill in ${root} was removed on ${hostName}" >&2
          failed=1
        fi
        if [ -e "$HOME"/${esc root}/retired-skill ]; then
          echo "a skill the source no longer ships stayed in ${root} on ${hostName}" >&2
          failed=1
        fi
        if [ -n "$(find "$HOME"/${esc root} -mindepth 1 -maxdepth 1 -name '.*.??????')" ]; then
          echo "staging directories were left in ${root} on ${hostName}" >&2
          failed=1
        fi
        ${lib.concatMapStringsSep "\n" (assertSkill root) expectedSkills}
      '';

      runActivation = lib.optionalString (activation != null && skillsSrc != null) ''
        export HOME=$TMPDIR/home-${hostName}
        mkdir -p "$HOME"
        ${lib.concatMapStringsSep "\n" seedRoot roots}
        ${seedStale}

        # Twice: the second run starts from the first run's result, as a later
        # generation does.
        for pass in 1 2; do
          if ! (
            run() { "$@"; }
            ${script}
          ); then
            echo "home.activation.orcaSkills failed on pass $pass on ${hostName}" >&2
            failed=1
          fi
        done

        ${lib.concatMapStringsSep "\n" assertRoot roots}
      '';
    in
    ''
      ${packageAbsent}${sourceAbsent}${activationAbsent}${activationOrder}
      if [ -z ${esc orcaVersion} ]; then
        echo 'the orca-ide package carries no version on ${hostName}' >&2
        failed=1
      fi
      ${sourceVersion}
      ${declaredLinks}
      ${runActivation}
    '';
in
pkgs.runCommand "orca-skills-tests"
  {
    nativeBuildInputs = [
      pkgs.diffutils
      pkgs.findutils
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
