/*
  Check interface:

    import ./tests/korean-skills.nix { inherit pkgs self fixtures; }

  Asserts that the three korean-skills skills reach every harness for user
  `h82` on every host this flake declares, and that their pin still names the
  revision this repository expects:

    Claude Code               ~/.claude/skills/<name>
    OpenCode                  ~/.config/opencode/skills/<name>
    Antigravity CLI, and T3 Code's Antigravity instances
                              ~/.gemini/antigravity-cli/skills/<name>

  The user list is `userEntries` from `tests/lib/configurations.nix`, so the
  NixOS and non-NixOS Linux user environments are both covered, and the
  helper's guard fails the build when that list is empty.

  Verifies, per Home Manager user:
  - each of the nine targets is exactly one enabled Home Manager file, found by
    its resolved `target` rather than its attribute name, because either can
    move the file without changing its text.
  - each target exists in the materialized `home-files`, holds a SKILL.md whose
    frontmatter `name` equals the directory name and whose `description` is
    not empty, holds a LICENSE that starts with "MIT License", and matches the
    pinned input byte for byte: the skill directory without LICENSE against
    `skills/<name>` (so `references/` and `examples/` are there too), and
    LICENSE against the input's root LICENSE. See
    .compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md
  - the enabled targets at or under each root are exactly the three skill
    directories, so a skill dropped from or added to the module, or a file
    declared inside a skill directory, turns this red.
  - nothing exists at ~/.agents/skills or ~/.gemini/config/skills in the
    materialized `home-files`: the Antigravity CLI lists skills under
    ~/.gemini/config/skills twice, and ~/.agents/skills is no harness's root
    here.

  The pin assertion compares two genuinely separate sources: `flake.lock`,
  which Nix writes, and the registry in home/h82/agents/korean-skills.nix, which
  a person writes. A tag is mutable and a relock re-resolves the ref, so the
  tag alone is not a pin -- if upstream moves it, the lock's revision changes
  and this assertion goes red instead of the change arriving as a lock diff.
  The registry's tag must equal the ref the lock recorded, and its skill list
  must equal the list written here.

  The expected names and roots are written here, not read from the module, so
  a mutation of the module turns this red. Every lookup carries an `or`
  fallback and each store path is interpolated only inside its present branch,
  so a removed declaration fails inside the builder rather than during
  evaluation. See
  .compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md

  Globs are never expanded in the builder: stdenv's nullglob would make an
  `ls <glob>` assertion succeed on no match. See
  .compound-engineering/artifacts/solutions/logic-errors/stdenv-nullglob-makes-ls-glob-assertions-vacuous.md

  The builder collects every failure instead of exiting at the first, so one
  red build names every broken assertion across every configuration.
*/
{
  pkgs,
  self,
  fixtures,
}:
let
  inherit (pkgs) lib;

  esc = value: lib.escapeShellArg (toString value);

  skillNames = [
    "humanizer"
    "grammar-checker"
    "style-guide"
  ];

  roots = [
    ".claude/skills"
    ".config/opencode/skills"
    ".gemini/antigravity-cli/skills"
  ];

  forbiddenRoots = [
    ".agents/skills"
    ".gemini/config/skills"
  ];

  lock = builtins.fromJSON (builtins.readFile ../flake.lock);
  lockNode = lock.nodes.korean-skills or { };
  lockedRev = lockNode.locked.rev or "";
  originalRef = lockNode.original.ref or "";

  configurations = import ./lib/configurations.nix { inherit pkgs self fixtures; };

  sorted = lib.sort lib.lessThan;

  upstream = self.inputs.korean-skills or null;

  # Every enabled target at or under `root`.
  targetsUnder =
    userConfig: root:
    sorted (
      map (file: file.target) (
        lib.filter (
          file:
          (file.enable or false)
          && ((file.target or "") == root || lib.hasPrefix "${root}/" (file.target or ""))
        ) (lib.attrValues (userConfig.home.file or { }))
      )
    );

  homeFile =
    label: userConfig: target:
    let
      entries = lib.filter (file: (file.target or "") == target) (
        lib.attrValues (userConfig.home.file or { })
      );
      entry = if lib.length entries == 1 then lib.head entries else null;
    in
    lib.optionalString (lib.length entries != 1) ''
      echo ${esc "expected 1 home.file for ~/${target} on ${label}, found ${toString (lib.length entries)}"} >&2
      failed=1
    ''
    + lib.optionalString (entry != null) ''
      if [ ${esc (lib.boolToString (entry.enable or false))} != "true" ]; then
        echo ${esc "home.file for ~/${target} on ${label} is not enabled"} >&2
        failed=1
      fi
    '';

  materialized =
    label: homeFiles: root: name:
    let
      target = "${root}/${name}";
    in
    ''
      dir=${homeFiles}/${target}
      if [ ! -f "$dir/SKILL.md" ]; then
        echo ${esc "~/${target} on ${label} holds no SKILL.md in home-files"} >&2
        failed=1
      else
        actual=$(awk '
          NR == 1 && $0 != "---" { exit }
          NR > 1 && $0 == "---" { exit }
          NR > 1 && /^name:/ { sub(/^name:[ ]*/, ""); print; exit }
        ' "$dir/SKILL.md")
        if [ "$actual" != ${esc name} ]; then
          echo ${esc "the SKILL.md of ~/${target} on ${label} must declare name ${name}, got:"} "'$actual'" >&2
          failed=1
        fi
        description=$(awk '
          NR == 1 && $0 != "---" { exit }
          NR > 1 && $0 == "---" { exit }
          NR > 1 && /^description:/ { sub(/^description:[ ]*/, ""); print; exit }
        ' "$dir/SKILL.md")
        if [ -z "$description" ]; then
          echo ${esc "the SKILL.md of ~/${target} on ${label} declares no description"} >&2
          failed=1
        fi
      fi
      if [ ! -f "$dir/LICENSE" ]; then
        echo ${esc "~/${target} on ${label} holds no LICENSE in home-files"} >&2
        failed=1
      elif [ "$(head -c 11 "$dir/LICENSE")" != "MIT License" ]; then
        echo ${esc "the LICENSE of ~/${target} on ${label} must start with MIT License"} >&2
        failed=1
      fi
    ''
    + lib.optionalString (upstream == null) ''
      echo ${esc "no korean-skills flake input to compare ~/${target} against"} >&2
      failed=1
    ''
    + lib.optionalString (upstream != null) ''
      if ! diff -r --exclude=LICENSE "$dir" ${upstream}/skills/${name} >&2; then
        echo ${esc "~/${target} on ${label} differs from skills/${name} of the pinned input"} >&2
        failed=1
      fi
      if [ -f "$dir/LICENSE" ] && ! cmp -s "$dir/LICENSE" ${upstream}/LICENSE; then
        echo ${esc "the LICENSE of ~/${target} on ${label} differs from the pinned input's LICENSE"} >&2
        failed=1
      fi
    '';

  assertEntry =
    entry:
    let
      label = entry.name;
      userConfig = entry.user;
      registry = userConfig.my.koreanSkills or null;
      homeFiles = userConfig.home-files or null;
    in
    lib.concatMapStrings (
      root: lib.concatMapStrings (name: homeFile label userConfig "${root}/${name}") skillNames
    ) roots
    + lib.concatMapStrings (
      root:
      let
        found = targetsUnder userConfig root;
        expected = sorted (map (name: "${root}/${name}") skillNames);
      in
      lib.optionalString (found != expected) ''
        echo ${esc "~/${root} on ${label} must hold exactly ${lib.concatStringsSep ", " expected}, got: ${lib.concatStringsSep ", " found}"} >&2
        failed=1
      ''
    ) roots
    + lib.optionalString (registry == null) ''
      echo ${esc "missing my.koreanSkills on ${label}"} >&2
      failed=1
    ''
    + lib.optionalString (registry != null) ''
      if [ ${esc (registry.expectedRev or "")} != ${esc lockedRev} ]; then
        echo ${esc "the pinned korean-skills revision drifted on ${label}: registry expects '${registry.expectedRev or ""}', flake.lock resolved '${lockedRev}'"} >&2
        failed=1
      fi
      if [ ${esc (registry.tag or "")} != ${esc originalRef} ]; then
        echo ${esc "the registry's tag '${registry.tag or ""}' does not match the tag '${originalRef}' flake.lock recorded on ${label}"} >&2
        failed=1
      fi
      if [ ${
        esc (lib.concatStringsSep " " (sorted (registry.skills or [ ])))
      } != ${esc (lib.concatStringsSep " " (sorted skillNames))} ]; then
        echo ${esc "the registry's skills on ${label} must be exactly ${lib.concatStringsSep ", " (sorted skillNames)}"} >&2
        failed=1
      fi
    ''
    + lib.optionalString (homeFiles == null) ''
      echo ${esc "no materialized home-files on ${label}"} >&2
      failed=1
    ''
    + lib.optionalString (homeFiles != null) (
      lib.concatMapStrings (
        root: lib.concatMapStrings (name: materialized label homeFiles root name) skillNames
      ) roots
      + lib.concatMapStrings (root: ''
        if [ -e ${homeFiles}/${root} ] || [ -L ${homeFiles}/${root} ]; then
          echo ${esc "~/${root} must not exist on ${label}"} >&2
          failed=1
        fi
      '') forbiddenRoots
    );
in
pkgs.runCommand "korean-skills-tests" { } ''
  set -x
  ${configurations.userGuard}
  failed=0

  if [ -z ${esc lockedRev} ]; then
    echo 'flake.lock records no revision for the korean-skills input' >&2
    failed=1
  fi

  if [ -z ${esc originalRef} ]; then
    echo 'flake.lock records no tag for the korean-skills input; the pin must name a release tag, not a branch' >&2
    failed=1
  fi

  ${lib.concatMapStringsSep "\n" assertEntry configurations.userEntries}

  if [ "$failed" != "0" ]; then
    exit 1
  fi

  touch $out
''
