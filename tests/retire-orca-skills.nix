/*
  Check interface:

    import ./tests/retire-orca-skills.nix { inherit pkgs self; }

  Asserts that every Home Manager user environment the flake builds, on NixOS
  and non-NixOS hosts alike, no longer installs Orca's agent skills and
  removes the copies the old installer wrote: each name a root's
  `.orca-skills` manifest lists, then the manifest, and nothing else.

  The user list comes from `tests/lib/configurations.nix`, whose guard fails
  the build when it holds no user of either host kind.

  What the check reads, and why:

  - The materialized activation entry, run under Home Manager's own
    `set -euo pipefail` against fixture homes, not the module's option values.
    GNU rm refuses `root/.` and `root/..` with a nonzero status instead of
    removing anything, so a dropped name guard shows only as a failed
    activation, which errexit makes visible. See
    .compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md
  - Homes seeded with the state the old installer left: Orca skill copies and
    manifests in all three roots beside a user's own skill. A home that starts
    clean passes whether or not anything is removed. See
    .compound-engineering/artifacts/solutions/best-practices/converged-fixture-state-defeats-nix-check-mutation-testing.md
  - One home per malformed manifest line, so a red build names the line whose
    guard broke.

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

  userRoot = ".claude/skills";

  orcaNames = [
    "orca-cli"
    "orchestration"
  ];

  # Manifest lines the old installer's guard skipped. Each is paired with a
  # valid name, so its home also proves the valid removal still happens.
  malformedLines = {
    empty = "";
    dot = ".";
    dotdot = "..";
    slash = "a/b";
  };

  configurations = import ./lib/configurations.nix { inherit pkgs self; };

  assertEntry =
    entry:
    let
      name = "${entry.name} (${entry.kind})";
      userConfig = entry.user;

      activation = userConfig.home.activation.retireOrcaSkills or null;
      script = if activation == null then "" else (activation.data or "");
      after = if activation == null then [ ] else (activation.after or [ ]);

      installer = userConfig.home.activation.orcaSkills or null;

      activationAbsent = lib.optionalString (activation == null) ''
        echo ${esc "missing home.activation.retireOrcaSkills on ${name}"} >&2
        failed=1
      '';

      activationOrder = lib.optionalString (activation != null && !(lib.elem "linkGeneration" after)) ''
        echo ${esc "home.activation.retireOrcaSkills must run after linkGeneration on ${name}"} >&2
        failed=1
      '';

      installerPresent = lib.optionalString (installer != null) ''
        echo ${esc "home.activation.orcaSkills still installs Orca skills on ${name}"} >&2
        failed=1
      '';

      # Runs the entry as Home Manager does: errexit, nounset, pipefail, and
      # its `run` helper.
      activate = scenario: ''
        if ! (
          set -euo pipefail
          run() { "$@"; }
          ${script}
        ); then
          echo ${esc "home.activation.retireOrcaSkills failed"} "(${scenario}, pass $pass) on "${esc name} >&2
          failed=1
        fi
      '';

      newHome = scenario: ''
        export HOME="$TMPDIR"/${esc "home-${entry.kind}-${entry.name}-${scenario}"}
        mkdir -p "$HOME"
      '';

      seedOrcaRoot = root: ''
        ${lib.concatMapStringsSep "\n" (skill: ''
          mkdir -p "$HOME"/${esc root}/${esc skill}
          echo orca >"$HOME"/${esc root}/${esc skill}/SKILL.md
        '') orcaNames}
        printf '%s\n' ${lib.escapeShellArgs orcaNames} >"$HOME"/${esc root}/.orca-skills
      '';

      seedUserSkill = root: ''
        mkdir -p "$HOME"/${esc root}/mine
        echo mine >"$HOME"/${esc root}/mine/SKILL.md
      '';

      assertUserSkill = scenario: root: ''
        if [ ! -f "$HOME"/${esc root}/mine/SKILL.md ]; then
          echo ${esc "the user's own skill in ${root} was removed (${scenario}) on ${name}"} >&2
          failed=1
        fi
      '';

      assertRetired = scenario: root: ''
        ${lib.concatMapStringsSep "\n" (skill: ''
          if [ -e "$HOME"/${esc root}/${esc skill} ]; then
            echo ${esc "${root}/${skill} survived (${scenario}) on ${name}"} >&2
            failed=1
          fi
        '') orcaNames}
        if [ -e "$HOME"/${esc root}/.orca-skills ]; then
          echo ${esc "${root}/.orca-skills survived (${scenario}) on ${name}"} >&2
          failed=1
        fi
      '';

      # AE6: copies and manifests in every root, a user skill beside them.
      # The second pass starts from the first one's result, as a later
      # generation does, and must change nothing.
      seededHome = ''
        ${newHome "seeded"}
        ${lib.concatMapStringsSep "\n" seedOrcaRoot roots}
        ${seedUserSkill userRoot}
        pass=1
        ${activate "seeded home"}
        snapshot >"$TMPDIR/first"
        pass=2
        ${activate "seeded home"}
        snapshot >"$TMPDIR/second"
        if ! diff -u "$TMPDIR/first" "$TMPDIR/second" >&2; then
          echo ${esc "a second activation changed the seeded home on ${name}"} >&2
          failed=1
        fi
        ${lib.concatMapStringsSep "\n" (assertRetired "seeded home") roots}
        ${assertUserSkill "seeded home" userRoot}
      '';

      # No manifest: a root holding skill directories stays as it is, and a
      # root that does not exist is not created.
      unmanagedHome = ''
        ${newHome "unmanaged"}
        ${lib.concatMapStringsSep "\n" (skill: ''
          mkdir -p "$HOME"/${esc userRoot}/${esc skill}
          echo orca >"$HOME"/${esc userRoot}/${esc skill}/SKILL.md
        '') orcaNames}
        ${seedUserSkill userRoot}
        mkdir -p "$HOME"/${esc (lib.elemAt roots 1)}
        snapshot >"$TMPDIR/before"
        pass=1
        ${activate "no manifest"}
        snapshot >"$TMPDIR/after"
        if ! diff -u "$TMPDIR/before" "$TMPDIR/after" >&2; then
          echo ${esc "activation changed a home holding no .orca-skills manifest on ${name}"} >&2
          failed=1
        fi
      '';

      malformedHome = label: line: ''
        ${newHome label}
        ${seedOrcaRoot userRoot}
        ${seedUserSkill userRoot}
        mkdir -p "$HOME"/${esc userRoot}/a/b
        echo mine >"$HOME"/${esc userRoot}/a/b/SKILL.md
        echo keep >"$HOME"/.claude/keep
        printf '%s\n' ${esc line} >>"$HOME"/${esc userRoot}/.orca-skills
        pass=1
        ${activate "manifest line '${line}'"}
        ${assertRetired "manifest line '${line}'" userRoot}
        ${assertUserSkill "manifest line '${line}'" userRoot}
        if [ ! -f "$HOME"/${esc userRoot}/a/b/SKILL.md ]; then
          echo ${esc "manifest line '${line}' removed ${userRoot}/a/b on ${name}"} >&2
          failed=1
        fi
        if [ ! -f "$HOME"/.claude/keep ]; then
          echo ${esc "manifest line '${line}' removed a file outside ${userRoot} on ${name}"} >&2
          failed=1
        fi
      '';

      runActivation = lib.optionalString (activation != null) ''
        ${seededHome}
        ${unmanagedHome}
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList malformedHome malformedLines)}
      '';
    in
    ''
      ${activationAbsent}${activationOrder}${installerPresent}
      ${runActivation}
    '';
in
pkgs.runCommand "retire-orca-skills-tests"
  {
    nativeBuildInputs = [
      pkgs.diffutils
      pkgs.findutils
    ];
  }
  ''
    ${configurations.userGuard}
    failed=0

    snapshot() {
      find "$HOME" -mindepth 1 -printf '%P %y\n' | sort
    }

    ${lib.concatMapStringsSep "\n" assertEntry configurations.userEntries}

    if [ "$failed" != "0" ]; then
      exit 1
    fi

    touch $out
  ''
