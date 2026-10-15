{ pkgs, lib, ... }:
let
  inherit (import ./render.nix { inherit pkgs lib; }) render;

  # The user-level instruction file each harness loads in every workspace, and
  # the parts it carries. A file whose harness has no added-system-prompt
  # channel on any path carries the system part merged in; Codex takes its
  # system part through `developer_instructions` (codex.nix). The T3 Code part
  # never lands here: t3code.nix delivers it through T3 Code's settings.
  #
  # The Antigravity CLI loads both ~/.gemini/GEMINI.md and
  # ~/.gemini/config/AGENTS.md as global rules. The first is also the Gemini
  # CLI's global context file, which would hand Antigravity's tool names to a
  # different harness, so this uses the second.
  terminalFiles = {
    claude-code = {
      target = ".claude/CLAUDE.md";
      parts = [
        "system"
        "user"
      ];
    };
    antigravity = {
      target = ".gemini/config/AGENTS.md";
      parts = [
        "system"
        "user"
      ];
    };
    codex = {
      target = ".codex/AGENTS.md";
      parts = [ "user" ];
    };
  };
in
{
  # Plain store links: no harness rewrites these files, unlike the
  # settings files claude.nix, codex.nix, and gemini.nix merge at activation.
  home.file = lib.mapAttrs' (
    harness: file:
    lib.nameValuePair "agent-instructions-${harness}" {
      inherit (file) target;
      source = render {
        inherit harness;
        inherit (file) parts;
      };
    }
  ) terminalFiles;
}
