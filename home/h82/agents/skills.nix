{ config, lib, ... }:
let
  # Each root is a directory one harness reads skills from. Claude Code reads
  # ~/.claude/skills. OpenCode ignores that directory under the wrapper's
  # OPENCODE_DISABLE_CLAUDE_CODE=true. The Antigravity CLI and T3 Code's
  # Antigravity instances read ~/.gemini/antigravity-cli/skills; not
  # ~/.gemini/config/skills, which the CLI lists twice. Pi reads
  # ~/.pi/agent/skills. Codex reads ~/.codex/skills; not ~/.agents/skills,
  # which no harness here owns. Codex lists a skill it reaches through more
  # than one root once, because every root's link resolves to the same store
  # directory.
  roots = [
    ".claude/skills"
    ".config/opencode/skills"
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
  config.home.file = lib.listToAttrs (
    map
      ({ root, name }: lib.nameValuePair "${root}/${name}" { source = config.my.agentSkills.${name}; })
      (
        lib.cartesianProduct {
          root = roots;
          name = lib.attrNames config.my.agentSkills;
        }
      )
  );
}
