/*
  Check interface:

    import ./tests/plasma-taskbar.nix { inherit pkgs self; }

  Asserts that the KDE Plasma applets activation script declares the pinned taskbar
  launchers in the specified order (Google Chrome, Dolphin, Ghostty, Orca)
  across all hosts.

  Verifies:
  - ThinkPad-X1-Carbon-Gen-11 defines kdePlasmaApplets activation script with launchers.
  - MS-7D91 defines kdePlasmaApplets activation script with launchers.
  - Pinned applications are ordered as: preferred://browser, preferred://filemanager,
    applications:com.mitchellh.ghostty.desktop, applications:orca.desktop.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  assertHostScript =
    hostName: host:
    let
      activationData = host.config.home-manager.users.h82.home.activation.kdePlasmaApplets.data or null;
      scriptFile = pkgs.writeText "${hostName}-kde-plasma-applets.sh" (
        if activationData != null then activationData else ""
      );
      expectedLaunchers = "preferred://browser,preferred://filemanager,applications:com.mitchellh.ghostty.desktop,applications:orca.desktop";
    in
    ''
      if [ ! -s "${scriptFile}" ]; then
        echo "kdePlasmaApplets activation script is missing or empty on ${hostName}" >&2
        exit 1
      fi

      if ! grep -Fq -- '--key launchers "${expectedLaunchers}"' "${scriptFile}"; then
        echo "kdePlasmaApplets activation script is missing expected launchers on ${hostName}" >&2
        exit 1
      fi

      if ! grep -Fq -- '--key groupingStrategy 0' "${scriptFile}"; then
        echo "kdePlasmaApplets activation script lost groupingStrategy configuration on ${hostName}" >&2
        exit 1
      fi
    '';
in
pkgs.runCommand "plasma-taskbar-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
  set -x

  ${assertHostScript "ThinkPad-X1-Carbon-Gen-11" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11}
  ${assertHostScript "MS-7D91" self.nixosConfigurations.MS-7D91}

  touch $out
''
