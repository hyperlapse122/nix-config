{
  config,
  lib,
  pkgs,
  ...
}:
let
  hostFacts = import ../../../../lib/host-facts.nix { inherit lib; };
  renderer = import ../../../../packages/text-template.nix { inherit pkgs; };

  peerClaudeCode = {
    name = "Claude Code";
    instance = "claudeAgent";
    model = "`claude-opus-5-5`";
    provider = "Anthropic";
  };
  peerAntigravity = {
    name = "Antigravity";
    instance = "antigravity";
    model = "`gemini-4-argon` at thinking level `medium`";
    provider = "Google";
  };
  peerGrok = {
    name = "Grok";
    instance = "grok";
    model = "its default model";
    provider = "xAI";
  };

  facts = hostFacts.of config.my;

  render =
    name: peers:
    let
      context = pkgs.writeText "agent-instructions-${name}.json" (
        builtins.toJSON (facts // { inherit peers; })
      );
    in
    pkgs.runCommand "agent-instructions-${name}.md" { nativeBuildInputs = [ renderer ]; } ''
      text-template ${./instructions.md.tmpl} ${context} > $out
    '';

  claudeCode = render "claude-code" {
    first = peerAntigravity;
    second = peerGrok;
  };
  antigravity = render "antigravity" {
    first = peerClaudeCode;
    second = peerGrok;
  };
  grok = render "grok" {
    first = peerClaudeCode;
    second = peerAntigravity;
  };
in
{
  # One rendering per harness, as a plain store link no harness rewrites.
  # OpenCode loads the Claude Code rendering from its global AGENTS.md. The
  # Antigravity CLI reads ~/.gemini/config. Grok Build reads
  # ~/.grok/rules/instructions.md.
  home.file = {
    agent-instructions-claude-code = {
      target = ".claude/CLAUDE.md";
      source = claudeCode;
    };
    agent-instructions-opencode = {
      target = ".config/opencode/AGENTS.md";
      source = claudeCode;
    };
    agent-instructions-antigravity = {
      target = ".gemini/config/AGENTS.md";
      source = antigravity;
    };
    agent-instructions-grok = {
      target = ".grok/rules/instructions.md";
      source = grok;
    };
  };
}
