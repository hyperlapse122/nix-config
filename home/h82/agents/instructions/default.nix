{ pkgs, lib, ... }:
let
  inherit (import ./render.nix { inherit pkgs lib; }) render;

  # The user-level instruction file each harness loads in every workspace, and
  # the parts it carries. A file whose harness has no added-system-prompt
  # channel on any path carries the system part merged in. The T3 Code part
  # never lands here: t3code.nix delivers it through T3 Code's settings.
  # OpenCode's file is not here either: packages/opencode.nix hands it to
  # standalone sessions only, so a reviewer run never loads it.
  terminalFiles = {
    claude-code = {
      target = ".claude/CLAUDE.md";
      parts = [
        "system"
        "user"
      ];
    };
  };
in
{
  # Plain store links: no harness rewrites these files, unlike the
  # settings files claude.nix and gemini.nix merge at activation.
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
