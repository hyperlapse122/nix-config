{ pkgs, lib, ... }:
let
  # The same import home/h82/default.nix installs, so the skills always come
  # from the release matching the installed Orca CLI.
  inherit ((import ../../../packages/orca.nix { inherit pkgs; })) skills;

  # Read from the pinned tree rather than listed here, so a skill added or
  # removed upstream follows the next Orca bump without an edit.
  names = lib.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir "${skills}/skills")
  );

  # Claude Code, the Antigravity CLI's global discovery root, and the shared
  # root that Codex, the Gemini CLI, and Orca's own installer use. Only the
  # per-skill directories are declared: each root is also written by its agent.
  roots = [
    ".claude/skills"
    ".gemini/config/skills"
    ".agents/skills"
  ];
in
{
  home.file = lib.listToAttrs (
    lib.concatMap (
      root:
      map (name: {
        name = "${root}/${name}";
        value.source = "${skills}/skills/${name}";
      }) names
    ) roots
  );
}
