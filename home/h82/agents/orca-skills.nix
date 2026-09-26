{ pkgs, lib, ... }:
let
  # The same import home/h82/default.nix installs, so the skills always come
  # from the release matching the installed Orca CLI.
  inherit (import ../../../packages/orca.nix { inherit pkgs; }) skills;

  # Read from the pinned tree rather than listed here, so a skill added or
  # removed upstream follows the next Orca bump without an edit.
  names = lib.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir "${skills}/skills")
  );

  # Claude Code, the Antigravity CLI's global discovery root, and the shared
  # root that Codex, the Gemini CLI, and Orca's own installer use. Only the
  # per-skill directories are managed: each root is also written by its agent.
  roots = [
    ".claude/skills"
    ".gemini/config/skills"
    ".agents/skills"
  ];

  # Orca rates an installed skill by reading its files, and it rejects any file
  # whose link count is not 1 as `skill-package-link`, reporting the skill as
  # unrecognized with no installed version. auto-optimise-store hardlinks
  # identical store files, so a Home Manager link into the store always reads
  # as a foreign skill. Plain per-user copies are what Orca recognizes.
  #
  # The per-root manifest records what this installer wrote, so a skill
  # removed upstream is removed here too while a user's own skill in the same
  # root is left alone.
  install = pkgs.writeShellApplication {
    name = "orca-skills-install";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      src=${skills}/skills
      names=(${lib.escapeShellArgs names})

      staging=
      trap '[ -z "$staging" ] || rm -rf -- "$staging"' EXIT

      for root in "$@"; do
        mkdir -p -- "$root"
        manifest=$root/.orca-skills

        if [ -f "$manifest" ]; then
          while IFS= read -r old; do
            case $old in "" | . | .. | */*) continue ;; esac
            keep=
            for name in "''${names[@]}"; do
              [ "$name" != "$old" ] || keep=1
            done
            [ -n "$keep" ] || rm -rf -- "''${root:?}/$old"
          done <"$manifest"
        fi

        for name in "''${names[@]}"; do
          # A run killed before its EXIT trap leaves its staging copy behind.
          rm -rf -- "''${root:?}/.$name".??????
          staging=$(mktemp -d "$root/.$name.XXXXXX")
          cp -R -- "$src/$name/." "$staging/"
          chmod -R u+w -- "$staging"
          chmod 0755 -- "$staging"
          rm -rf -- "''${root:?}/$name"
          mv -T -- "$staging" "$root/$name"
          staging=
        done

        printf '%s\n' "''${names[@]}" >"$manifest.tmp"
        mv -f -- "$manifest.tmp" "$manifest"
      done
    '';
  };
in
{
  # After linkGeneration, so the links an earlier generation declared at these
  # paths are already cleaned up before the copies take their place.
  home.activation.orcaSkills = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${lib.getExe install} ${lib.concatMapStringsSep " " (root: ''"$HOME"/${root}'') roots}
  '';
}
