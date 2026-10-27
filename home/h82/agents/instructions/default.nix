{
  config,
  lib,
  pkgs,
  ...
}:
let
  hostFacts = import ../../../../lib/host-facts.nix { inherit lib; };
  renderer = import ../../../../packages/text-template.nix { inherit pkgs; };

  render =
    delivery:
    let
      context = pkgs.writeText "agent-instructions-${delivery}.json" (
        builtins.toJSON (
          (hostFacts.of config.my)
          // {
            claude = delivery == "claude";
            codex = delivery == "codex";
            omp = delivery == "omp";
          }
        )
      );
    in
    pkgs.runCommand "agent-instructions-${delivery}.md" { nativeBuildInputs = [ renderer ]; } ''
      text-template ${./instructions.md.tmpl} ${context} > $out
    '';
in
{
  home.file = {
    agent-instructions-omp = {
      target = ".omp/agent/AGENTS.md";
      source = render "omp";
    };
    agent-instructions-claude-code = {
      target = ".claude/CLAUDE.md";
      source = render "claude";
    };
    agent-instructions-codex = {
      target = ".codex/AGENTS.md";
      source = render "codex";
    };
  };
}
