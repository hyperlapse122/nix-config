{
  config,
  lib,
  pkgs,
  ...
}:
let
  hostFacts = import ../../../../lib/host-facts.nix { inherit lib; };
  renderer = import ../../../../packages/text-template.nix { inherit pkgs; };

  # The template reads the host facts and nothing else; a missing key or a
  # printed null fails this build.
  context = pkgs.writeText "agent-instructions-context.json" (
    builtins.toJSON (hostFacts.of config.my)
  );
  instructions = pkgs.runCommand "instructions.md" { nativeBuildInputs = [ renderer ]; } ''
    text-template ${./instructions.md.tmpl} ${context} > $out
  '';
in
{
  # Plain store links: no harness rewrites these files. OpenCode always loads
  # its global AGENTS.md, and the Antigravity CLI reads ~/.gemini/config, so
  # every run of every installed harness gets the same file.
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
