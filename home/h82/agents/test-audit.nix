{ lib, ... }:
let
  # Where the vendored skill came from. The text under ./skills/test-audit is a
  # generalized rewrite, not a copy, so this is a record rather than a flake
  # input; tests/test-audit-skill.nix checks that SKILL.md's attribution line
  # names this revision.
  registry = {
    upstream = "openclaw/openclaw";
    path = ".agents/skills/test-audit";
    rev = "3195fba90643c3897c538f2f6891c405331bee9c";
  };
in
{
  options.my.testAuditSkill = lib.mkOption {
    type = lib.types.attrs;
    internal = true;
    readOnly = true;
    default = registry;
    description = "test-audit skill registry, for repository checks.";
  };

  config.my.agentSkills.test-audit = ./skills/test-audit;
}
