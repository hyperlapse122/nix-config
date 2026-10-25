{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Each root is a directory one harness reads skills from. Claude Code reads
  # ~/.claude/skills. The Antigravity CLI and T3 Code's Antigravity instances
  # read ~/.gemini/antigravity-cli/skills; not ~/.gemini/config/skills, which
  # the CLI lists twice. Pi reads ~/.pi/agent/skills. Codex reads
  # ~/.codex/skills; not ~/.agents/skills, which no harness here owns. Codex
  # lists a skill it reaches through more than one root once, because every
  # root's link resolves to the same store directory.
  roots = [
    ".claude/skills"
    ".gemini/antigravity-cli/skills"
    ".pi/agent/skills"
    ".codex/skills"
  ];
in
{
  options.my.agentSkills = lib.mkOption {
    type = lib.types.attrsOf lib.types.path;
    internal = true;
    default = { };
    description = ''
      Skill directories by skill name, linked into every harness's skill root.
    '';
  };

  # One link per root and skill, to the skill directory itself: Codex skips a
  # SKILL.md that is a symlink, so the files inside must not be linked one by
  # one with `recursive = true`.
  config.home.file = {
    # Own the whole native root so removed contributed skills stop loading.
    # OMP's separate managed-skills history remains inactive and untouched.
    ".omp/agent/skills".source = pkgs.linkFarm "omp-contributed-skills" (
      lib.mapAttrsToList (name: path: { inherit name path; }) config.my.agentSkills
    );
  }
  // lib.listToAttrs (
    lib.concatMap (
      root:
      lib.mapAttrsToList (
        name: source: lib.nameValuePair "${root}/${name}" { inherit source; }
      ) config.my.agentSkills
    ) roots
  );
}
