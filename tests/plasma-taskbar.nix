/*
  Check interface:

    import ./tests/plasma-taskbar.nix { inherit pkgs self; }

  Asserts that the KDE Plasma applets activation script declares the pinned taskbar
  launchers in the specified order (Google Chrome, Dolphin, Ghostty, then
  T3 Code when its desktop app is installed).

  Verifies, on every configuration `tests/lib/configurations.nix` yields,
  production and bootstrap alike (home/h82/desktop/kde/plasma.nix is not
  gated on my.bootstrap, so the bootstrap desktop gets the same taskbar), and
  on each production configuration re-evaluated with my.t3.desktop.enable
  forced off:
  - h82's Home Manager generation defines a non-empty kdePlasmaApplets
    activation script.
  - Pinned applications are ordered as: preferred://browser, preferred://filemanager,
    applications:com.mitchellh.ghostty.desktop, followed by
    applications:t3code.desktop exactly when my.t3.desktop.enable is on, so
    no host pins a launcher whose desktop file is not installed.
  - Task grouping stays disabled (groupingStrategy 0).

  Every configuration enables the T3 Code desktop trait today, so the
  forced-off configurations keep the trait-off list from passing untested.

  The builder collects every failure before it exits, so one red build names
  every affected configuration.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self; };

  desktopEnabled = config: config.my.t3.desktop.enable;
  desktopTrait = configurations.withTrait "my.t3.desktop.enable" desktopEnabled;

  expectedLaunchers =
    entry:
    lib.concatStringsSep "," (
      [
        "preferred://browser"
        "preferred://filemanager"
        "applications:com.mitchellh.ghostty.desktop"
      ]
      ++ lib.optional (desktopEnabled entry.config) "applications:t3code.desktop"
    );

  assertEntry =
    entry:
    let
      activationData = entry.user.home.activation.kdePlasmaApplets.data or null;
      scriptFile = pkgs.writeText "${entry.name}-kde-plasma-applets.sh" (
        if activationData != null then activationData else ""
      );
    in
    ''
      if [ ! -s "${scriptFile}" ]; then
        echo "kdePlasmaApplets activation script is missing or empty on ${entry.name}" >&2
        failed=1
      else
        if ! grep -Fq -- '--key launchers "${expectedLaunchers entry}"' "${scriptFile}"; then
          echo "kdePlasmaApplets activation script is missing expected launchers on ${entry.name}" >&2
          failed=1
        fi

        if ! grep -Fq -- '--key groupingStrategy 0' "${scriptFile}"; then
          echo "kdePlasmaApplets activation script lost groupingStrategy configuration on ${entry.name}" >&2
          failed=1
        fi
      fi
    '';
in
pkgs.runCommand "plasma-taskbar-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
  set -x
  ${configurations.guard}
  ${desktopTrait.guard}
  failed=0

  ${lib.concatMapStringsSep "\n" assertEntry (configurations.entries ++ desktopTrait.disabled)}

  if [ "$failed" != 0 ]; then
    exit 1
  fi
  touch $out
''
