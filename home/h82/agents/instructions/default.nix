{ config, pkgs, ... }:
let
  # The one substitution is the card key; replaceVars fails the build if any
  # @name@ placeholder is left unrendered.
  instructions = pkgs.replaceVars ./instructions.md {
    inherit (config.my.user) gpgKey;
  };
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
