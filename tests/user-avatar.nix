/*
  Check interface:

    import ./tests/user-avatar.nix { inherit pkgs self; }

  Asserts that every host deploys the user avatar where each consumer reads it.

  Verifies, on all four host configurations:
  - Home Manager's built home files carry ~/.face and ~/.face.icon with the asset's bytes
    (read by AccountsService for System Settings and by the Plasma session).
  - The system profile carries share/sddm/faces/h82.face.icon with the asset's bytes
    (read by the SDDM greeter, which cannot enter the mode-700 home directory).

  The comparisons are byte-for-byte, so they do not depend on the asset's store path.
*/
{ pkgs, self }:
let
  asset = ../home/h82/assets/face.png;

  assertHost =
    hostName: host:
    let
      homeFiles = host.config.home-manager.users.h82.home-files;
      systemPath = host.config.system.path;
    in
    ''
      for name in .face .face.icon; do
        if [ ! -e "${homeFiles}/$name" ]; then
          echo "Home Manager does not deploy ~/$name on ${hostName}" >&2
          exit 1
        fi
        if ! cmp -s "${homeFiles}/$name" "${asset}"; then
          echo "~/$name on ${hostName} differs from home/h82/assets/face.png" >&2
          exit 1
        fi
      done

      sddmFace="${systemPath}/share/sddm/faces/h82.face.icon"
      if [ ! -e "$sddmFace" ]; then
        echo "system profile lacks share/sddm/faces/h82.face.icon on ${hostName}" >&2
        exit 1
      fi
      if ! cmp -s "$sddmFace" "${asset}"; then
        echo "SDDM face for h82 on ${hostName} differs from home/h82/assets/face.png" >&2
        exit 1
      fi
    '';
in
pkgs.runCommand "user-avatar-tests" { nativeBuildInputs = [ pkgs.diffutils ]; } ''
  set -x

  ${assertHost "ThinkPad-X1-Carbon-Gen-11" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11}
  ${assertHost "ThinkPad-X1-Carbon-Gen-11-bootstrap" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap}
  ${assertHost "MS-7D91" self.nixosConfigurations.MS-7D91}
  ${assertHost "MS-7D91-bootstrap" self.nixosConfigurations.MS-7D91-bootstrap}

  touch $out
''
