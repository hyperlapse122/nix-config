{ lib, ... }:
let
  provenance = {
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
    default = provenance;
    description = "test-audit skill provenance, for repository checks.";
  };

  config.my.agentSkills.test-audit = ./skills/test-audit;
}
