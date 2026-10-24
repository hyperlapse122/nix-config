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
        builtins.toJSON ((hostFacts.of config.my) // { codex = delivery == "codex"; })
      );
    in
    pkgs.runCommand "agent-instructions-${delivery}.md" { nativeBuildInputs = [ renderer ]; } ''
      text-template ${./instructions.md.tmpl} ${context} > $out
    '';

  instructions = render "common";
in
{
  home.file = {
    agent-instructions-pi = {
      target = ".pi/agent/AGENTS.md";
      source = instructions;
    };
    agent-instructions-claude-code = {
      target = ".claude/CLAUDE.md";
      source = instructions;
    };
    agent-instructions-codex = {
      target = ".codex/AGENTS.md";
      source = render "codex";
    };
    agent-instructions-antigravity = {
      target = ".gemini/config/AGENTS.md";
      source = instructions;
    };
  };
}
