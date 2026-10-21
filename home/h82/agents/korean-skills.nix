{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  # `tag` is the pin; `expectedRev` is the revision that tag is expected to
  # name, because a git tag is mutable and a relock re-resolves the ref rather
  # than the revision. tests/korean-skills.nix compares expectedRev against what
  # flake.lock actually recorded, so a re-pointed upstream tag fails a check
  # instead of arriving as a lock diff.
  registry = {
    upstream = "DaleSeo/korean-skills";
    tag = "v1.0.0";
    expectedRev = "fe6432e95f6675f7e411eacb2e1c36f1de54f962";
    skills = [
      "humanizer"
      "grammar-checker"
      "style-guide"
    ];
  };

  # One skill directory per name, with the upstream license beside it: the
  # repository keeps a single LICENSE at its root, and an installed skill is
  # copied away from there.
  skillTree = pkgs.runCommand "korean-skills-${registry.tag}" { } ''
    ${lib.concatMapStringsSep "\n" (name: ''
      mkdir -p $out/${name}
      cp -r --no-preserve=mode ${inputs.korean-skills}/skills/${name}/. $out/${name}
      cp --no-preserve=mode ${inputs.korean-skills}/LICENSE $out/${name}/LICENSE
    '') registry.skills}
  '';

  # Each root is a directory one harness reads skills from. Claude Code reads
  # ~/.claude/skills. OpenCode ignores that directory under the wrapper's
  # OPENCODE_DISABLE_CLAUDE_CODE=true. The Antigravity CLI and T3 Code's
  # Antigravity instances read ~/.gemini/antigravity-cli/skills; not
  # ~/.gemini/config/skills, which the CLI lists twice.
  roots = [
    ".claude/skills"
    ".config/opencode/skills"
    ".gemini/antigravity-cli/skills"
  ];
in
{
  options.my.koreanSkills = lib.mkOption {
    type = lib.types.attrs;
    internal = true;
    readOnly = true;
    default = registry;
    description = "Korean skills registry, for repository checks.";
  };

  config.home.file = lib.listToAttrs (
    map
      (
        { root, name }:
        lib.nameValuePair "${root}/${name}" {
          source = "${skillTree}/${name}";
        }
      )
      (
        lib.cartesianProduct {
          root = roots;
          name = registry.skills;
        }
      )
  );
}
