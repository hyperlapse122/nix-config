/*
  Check interface:

    import ./tests/wireplumber-bluetooth.nix { inherit pkgs self; }

  Asserts that every host configuration makes the WirePlumber user service
  load bluetooth.autoswitch-to-headset-profile = false, declared in
  modules/nixos/hardware/bluetooth-audio.nix. The check reads the conf.d
  fragments under the service's XDG_DATA_DIRS, the search path WirePlumber
  actually loads, rather than the extraConfig option value.

  Verifies:
  - ThinkPad-X1-Carbon-Gen-11, ThinkPad-X1-Carbon-Gen-11-bootstrap, MS-7D91,
    and MS-7D91-bootstrap all keep the wireplumber user service enabled.
  - At least one fragment sets the key to false in a wireplumber.settings
    section, whatever the fragment file is named.
  - No fragment sets the key to true, in either the compact JSON extraConfig
    renders or the SPA-JSON a hand-written configPackages fragment uses.
*/
{ pkgs, self }:
let
  assertHost =
    hostName: host:
    let
      service = host.config.systemd.user.services.wireplumber or { };
      dataDirs = service.environment.XDG_DATA_DIRS or "";
    in
    ''
      if [ "${pkgs.lib.boolToString (service.enable or false)}" != "true" ]; then
        echo "${hostName}: the wireplumber user service is not enabled" >&2
        exit 1
      fi

      data_dirs='${dataDirs}'
      if [ -z "$data_dirs" ]; then
        echo "${hostName}: the wireplumber user service has no XDG_DATA_DIRS" >&2
        exit 1
      fi

      found_false=0
      IFS=: read -r -a dirs <<< "$data_dirs"
      for dir in "''${dirs[@]}"; do
        for fragment in "$dir"/wireplumber/wireplumber.conf.d/*.conf; do
          [ -e "$fragment" ] || continue
          if grep -Eq 'bluetooth\.autoswitch-to-headset-profile"?[[:space:]]*[:=][[:space:]]*true' "$fragment"; then
            echo "${hostName}: $fragment sets bluetooth.autoswitch-to-headset-profile to true" >&2
            exit 1
          fi
          if grep -Eq '^wireplumber\.settings = .*"bluetooth\.autoswitch-to-headset-profile":false' "$fragment"; then
            found_false=1
          fi
        done
      done

      if [ "$found_false" != 1 ]; then
        echo "${hostName}: no wireplumber.conf.d fragment sets bluetooth.autoswitch-to-headset-profile to false" >&2
        exit 1
      fi
    '';
in
pkgs.runCommand "wireplumber-bluetooth-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
  set -x

  ${assertHost "ThinkPad-X1-Carbon-Gen-11" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11}
  ${assertHost "ThinkPad-X1-Carbon-Gen-11-bootstrap" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap}
  ${assertHost "MS-7D91" self.nixosConfigurations.MS-7D91}
  ${assertHost "MS-7D91-bootstrap" self.nixosConfigurations.MS-7D91-bootstrap}

  touch $out
''
