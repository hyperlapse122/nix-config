/*
  Check interface:

    import ./tests/plasma-taskbar.nix { inherit pkgs self; }

  Asserts that the KDE Plasma applets activation script declares the pinned taskbar
  launchers in the specified order (Google Chrome, Dolphin, Ghostty, T3 Code).

  Verifies, on every configuration `tests/lib/configurations.nix` yields,
  production and bootstrap alike (home/h82/desktop/kde/plasma.nix is not
  gated on my.bootstrap, so the bootstrap desktop gets the same taskbar):
  - h82's Home Manager generation defines a non-empty kdePlasmaApplets
    activation script.
  - Pinned applications are ordered as: preferred://browser, preferred://filemanager,
    applications:com.mitchellh.ghostty.desktop, applications:t3code.desktop.
  - Orca (orca.desktop) is not pinned.
  - Task grouping stays disabled (groupingStrategy 0).

  The builder collects every failure before it exits, so one red build names
  every affected configuration.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self; };

  expectedLaunchers = "preferred://browser,preferred://filemanager,applications:com.mitchellh.ghostty.desktop,applications:t3code.desktop";

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
        if ! grep -Fq -- '--key launchers "${expectedLaunchers}"' "${scriptFile}"; then
          echo "kdePlasmaApplets activation script is missing expected launchers on ${entry.name}" >&2
          failed=1
        fi

        if grep -Fq -- 'orca.desktop' "${scriptFile}"; then
          echo "kdePlasmaApplets activation script still pins Orca on ${entry.name}" >&2
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
  failed=0

  ${lib.concatMapStringsSep "\n" assertEntry configurations.entries}

  if [ "$failed" != 0 ]; then
    exit 1
  fi
  touch $out
''
