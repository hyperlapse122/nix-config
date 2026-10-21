{
  config,
  lib,
  pkgs,
  ...
}:
let
  hostFacts = import ../../../../lib/host-facts.nix { inherit lib; };
  renderer = import ../../../../packages/text-template.nix { inherit pkgs; };
  models = import ../synthetic-models.nix;

  context = pkgs.writeText "agent-instructions.json" (
    builtins.toJSON (hostFacts.of config.my // { inherit models; })
  );

  instructions = pkgs.runCommand "agent-instructions.md" { nativeBuildInputs = [ renderer ]; } ''
    text-template ${./instructions.md.tmpl} ${context} > $out
  '';
in
{
  # One rendering for every harness, as a plain store link no harness
  # rewrites. OpenCode loads it from its global AGENTS.md, and the
  # Antigravity CLI reads ~/.gemini/config.
  home.file = {
    agent-instructions-claude-code = {
      target = ".claude/CLAUDE.md";
      source = instructions;
    };
    agent-instructions-opencode = {
      target = ".config/opencode/AGENTS.md";
      source = instructions;
    };
    agent-instructions-antigravity = {
      target = ".gemini/config/AGENTS.md";
      source = instructions;
    };
  };
}
