{ pkgs, lib, ... }:
let
  # The roots an earlier installer copied Orca's skills into, each with a
  # `.orca-skills` manifest of the names it wrote.
  roots = [
    ".claude/skills"
    ".gemini/config/skills"
    ".agents/skills"
  ];

  # Removes only the names a manifest lists, so skills installed any other way
  # stay, then the manifest itself. A root without a manifest is left alone,
  # which makes repeated runs a no-op.
  retire = pkgs.writeShellApplication {
    name = "retire-orca-skills";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      for root in "$@"; do
        manifest=$root/.orca-skills
        [ -f "$manifest" ] || continue

        while IFS= read -r old; do
          case $old in "" | . | .. | */*) continue ;; esac
          rm -rf -- "''${root:?}/$old"
        done <"$manifest"

        rm -f -- "$manifest"
      done
    '';
  };
in
{
  # Kept while any home may still hold the old copies. It runs only when a
  # rebuild produces a new Home Manager generation (and on every standalone
  # `home-manager switch`), and costs nothing once the manifests are gone.
  home.activation.retireOrcaSkills = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${lib.getExe retire} ${lib.concatMapStringsSep " " (root: ''"$HOME"/${root}'') roots}
  '';
}
