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

  # Pi reads the shared body alone, because the ACP section tells an agent
  # how to start Pi. Every other harness reads the body, a blank line, and
  # that section.
  shared = render "agent-instructions-shared.md" ./instructions.md.tmpl;
  acp = render "agent-instructions-acp.md" ./acp.md.tmpl;
  instructions = pkgs.runCommand "agent-instructions.md" { } ''
    { cat ${shared}; echo; cat ${acp}; } > $out
  '';
in
{
  # Plain store links no harness rewrites. Codex reads ~/.codex/AGENTS.md,
  # OpenCode loads its copy from its global AGENTS.md, the Antigravity CLI
  # reads ~/.gemini/config, and Pi reads ~/.pi/agent/AGENTS.md.
  home.file = {
    agent-instructions-pi = {
      target = ".pi/agent/AGENTS.md";
      source = shared;
    };
    agent-instructions-claude-code = {
      target = ".claude/CLAUDE.md";
      source = instructions;
    };
    agent-instructions-codex = {
      target = ".codex/AGENTS.md";
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
