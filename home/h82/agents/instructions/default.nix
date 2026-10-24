{
  config,
  lib,
  pkgs,
  ...
}:
let
  hostFacts = import ../../../../lib/host-facts.nix { inherit lib; };
  renderer = import ../../../../packages/text-template.nix { inherit pkgs; };

  context = pkgs.writeText "agent-instructions.json" (builtins.toJSON (hostFacts.of config.my));

  render =
    name: template:
    pkgs.runCommand name { nativeBuildInputs = [ renderer ]; } ''
      text-template ${template} ${context} > $out
    '';

  instructions = render "agent-instructions.md" ./instructions.md.tmpl;
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
      source = instructions;
    };
    agent-instructions-antigravity = {
      target = ".gemini/config/AGENTS.md";
      source = instructions;
    };
  };
}
