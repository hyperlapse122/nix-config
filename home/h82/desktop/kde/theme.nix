{ pkgs, lib, ... }:
let
  kwrite = "${pkgs.kdePackages.kconfig}/bin/kwriteconfig6";

  # One "group<TAB>key<TAB>value" line per color entry of the packaged scheme.
  # A nested group such as [Colors:Header][Inactive] becomes "Colors:Header/Inactive".
  lightColors = pkgs.runCommand "breeze-light-color-entries" { nativeBuildInputs = [ pkgs.gawk ]; } ''
    awk '
      /^\[/ {
        keep = ($0 ~ /^\[(Colors|ColorEffects):/ || $0 == "[WM]")
        group = substr($0, 2, length($0) - 2)
        gsub(/\]\[/, "/", group)
        next
      }
      keep && index($0, "=") > 1 {
        eq = index($0, "=")
        printf "%s\t%s\t%s\n", group, substr($0, 1, eq - 1), substr($0, eq + 1)
      }
    ' ${pkgs.kdePackages.breeze}/share/color-schemes/BreezeLight.colors > $out
  '';
in
{
  # ~/.config/kdeglobals may carry color groups from an earlier scheme, and they
  # override the defaults in /etc/xdg/kdeglobals, so write the scheme's values
  # here.
  # plasma-apply-colorscheme cannot do this: it reads the cascaded
  # ColorScheme=BreezeLight as already applied and writes nothing. This runs only
  # when the Home Manager generation changes, not on every rebuild.
  home.activation.kdeTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -x "${kwrite}" ]; then
      ${kwrite} --file kdeglobals --group General --key ColorScheme BreezeLight
      ${kwrite} --file kdeglobals --group KDE --key LookAndFeelPackage org.kde.breeze.desktop
      ${kwrite} --file kdeglobals --group Icons --key Theme breeze

      while IFS=$'\t' read -r group key value; do
        group_args=()
        IFS=/ read -ra groups <<< "$group"
        for g in "''${groups[@]}"; do
          group_args+=(--group "$g")
        done
        ${kwrite} --file kdeglobals "''${group_args[@]}" --key "$key" -- "$value"
      done < ${lightColors}
    fi
  '';
}
