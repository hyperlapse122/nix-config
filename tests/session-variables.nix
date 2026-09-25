/*
  Check interface:

    import ./tests/session-variables.nix { inherit pkgs self; }

  Asserts that every host configuration renders the Testcontainers,
  Turborepo, and telemetry opt-out session variables into both files that
  carry the h82 session environment: the Home Manager hm-session-vars.sh
  that login shells source, and ~/.config/environment.d/10-home-manager.conf
  that the systemd user manager reads.

  Verifies:
  - ThinkPad-X1-Carbon-Gen-11, ThinkPad-X1-Carbon-Gen-11-bootstrap, MS-7D91,
    and MS-7D91-bootstrap all materialize environment.d/10-home-manager.conf
    in the Home Manager generation's home-files, so a disabled or retargeted
    entry fails here rather than passing on its option text.
  - Each file carries every expected variable as a whole line, so a longer
    value cannot satisfy the assertion.
*/
{ pkgs, self }:
let
  expectedVariables = {
    TESTCONTAINERS_RYUK_CONTAINER_PRIVILEGED = "true";
    TESTCONTAINERS_RYUK_PRIVILEGED = "true";
    TURBO_ENV_MODE = "loose";
    DOTNET_CLI_TELEMETRY_OPTOUT = "1";
    DOTNET_TELEMETRY_OPTOUT = "1";
    TURBO_TELEMETRY_DISABLED = "1";
    POWERSHELL_TELEMETRY_OPTOUT = "1";
  };

  assertHost =
    hostName: host:
    let
      hm = host.config.home-manager.users.h82;
      environmentFile = "${hm.home-files}/.config/environment.d/10-home-manager.conf";
      shellFile = "${hm.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
    in
    ''
      if [ ! -f "${environmentFile}" ]; then
        echo "${hostName}: home-files has no .config/environment.d/10-home-manager.conf" >&2
        exit 1
      fi
    ''
    + pkgs.lib.concatStrings (
      pkgs.lib.mapAttrsToList (name: value: ''
        if ! grep -Fxq -- '${name}=${value}' "${environmentFile}"; then
          echo "${hostName}: environment.d/10-home-manager.conf is missing '${name}=${value}'" >&2
          exit 1
        fi
        if ! grep -Fxq -- 'export ${name}="${value}"' "${shellFile}"; then
          echo "${hostName}: hm-session-vars.sh is missing 'export ${name}=\"${value}\"'" >&2
          exit 1
        fi
      '') expectedVariables
    );
in
pkgs.runCommand "session-variables-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
  set -x

  ${assertHost "ThinkPad-X1-Carbon-Gen-11" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11}
  ${assertHost "ThinkPad-X1-Carbon-Gen-11-bootstrap" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap}
  ${assertHost "MS-7D91" self.nixosConfigurations.MS-7D91}
  ${assertHost "MS-7D91-bootstrap" self.nixosConfigurations.MS-7D91-bootstrap}

  touch $out
''
