/*
  Check interface:

    import ./tests/proton-vpn.nix { inherit pkgs self; }

  Asserts that the Proton VPN app and the split-DNS setup it needs reach both
  production configurations as built output, and that neither bootstrap
  configuration carries them. Every assertion reads the materialised /etc tree
  or the system path rather than the options they derive from: enabling
  services.resolved sets networking.networkmanager.dns unconditionally, so an
  assertion on that option would fold to a constant.

  Verifies, on ThinkPad-X1-Carbon-Gen-11 and MS-7D91:
  - the system path carries bin/protonvpn-app and the app's desktop entry.
  - NetworkManager.conf renders dns=systemd-resolved, and /etc/resolv.conf is
    the link to resolved's stub file.
  - systemd-resolved.service is wanted by sysinit.target, not merely rendered.
  - resolved.conf renders LLMNR=false, since resolved otherwise sends LLMNR
    queries that these hosts never sent under resolvconf.
  - /etc/NetworkManager/VPN carries the OpenVPN plugin's service file.

  Verifies, on both bootstrap configurations:
  - none of the items above are present. These negatives pass trivially when
    the module is missing everywhere, which is why they only run beside the
    production positives above.

  Verifies, on all four configurations:
  - the firewall start script's reverse-path rule is the loose variant.
    Strict mode drops replies that arrive on an interface other than the one
    the default route names, which is what a full-tunnel VPN beside
    tailscale0 produces.

  It cannot see what the app or resolved do at runtime; docs/verification.md
  carries the hardware checks for that. Every failure is collected in one build.
*/
{ pkgs, self }:
let
  inherit (pkgs.lib) concatStringsSep mapAttrsToList escapeShellArg;

  esc = value: escapeShellArg (toString value);

  stubResolvConf = "/run/systemd/resolve/stub-resolv.conf";
  looseRpfilterRule = "-m rpfilter --validmark --loose -j RETURN";

  fail = message: ''
    echo ${esc message} >&2
    failed=1
  '';

  # `present` true asserts the test holds, false asserts it does not.
  expect =
    present: test: message:
    if present then
      ''
        if ! ${test}; then
          ${fail message}
        fi
      ''
    else
      ''
        if ${test}; then
          ${fail message}
        fi
      '';

  hostAssertions =
    hostName:
    { host, production }:
    let
      path = host.config.system.path;
      etc = "${host.config.system.build.etc}/etc";
      state = if production then "lacks" else "unexpectedly carries";
    in
    concatStringsSep "\n" [
      (expect production "[ -x ${esc "${path}/bin/protonvpn-app"} ]"
        "${hostName}: the system path ${state} bin/protonvpn-app"
      )
      (expect production "[ -f ${esc "${path}/share/applications/proton.vpn.app.gtk.desktop"} ]"
        "${hostName}: the system path ${state} the Proton VPN desktop entry"
      )
      (expect production
        "grep -Fxq dns=systemd-resolved ${esc "${etc}/NetworkManager/NetworkManager.conf"}"
        "${hostName}: NetworkManager.conf ${state} dns=systemd-resolved"
      )
      (expect production "[ \"$(readlink ${esc "${etc}/resolv.conf"})\" = ${esc stubResolvConf} ]"
        "${hostName}: /etc/resolv.conf ${state} the link to ${stubResolvConf}"
      )
      (expect production
        "[ -e ${esc "${etc}/systemd/system/sysinit.target.wants/systemd-resolved.service"} ]"
        "${hostName}: sysinit.target ${state} a want on systemd-resolved.service"
      )
      (expect production "grep -Fxqs LLMNR=false ${esc "${etc}/systemd/resolved.conf"}"
        "${hostName}: resolved.conf ${state} LLMNR=false"
      )
      (expect production "[ -e ${esc "${etc}/NetworkManager/VPN/nm-openvpn-service.name"} ]"
        "${hostName}: /etc/NetworkManager/VPN ${state} the OpenVPN plugin"
      )
      ''
        firewall_start=$(sed -n 's/^ExecStart=@\([^ ]*\) .*/\1/p' ${esc "${etc}/systemd/system/firewall.service"})
        if [ -z "$firewall_start" ] || ! grep -Fq -- ${esc looseRpfilterRule} "$firewall_start"; then
          ${fail "${hostName}: the firewall start script carries no loose reverse-path rule"}
        fi
      ''
    ];
in
pkgs.runCommand "proton-vpn-tests" { } ''
  set -x
  failed=0

  ${concatStringsSep "\n" (
    mapAttrsToList hostAssertions {
      ThinkPad-X1-Carbon-Gen-11 = {
        host = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11;
        production = true;
      };
      MS-7D91 = {
        host = self.nixosConfigurations.MS-7D91;
        production = true;
      };
      ThinkPad-X1-Carbon-Gen-11-bootstrap = {
        host = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap;
        production = false;
      };
      MS-7D91-bootstrap = {
        host = self.nixosConfigurations.MS-7D91-bootstrap;
        production = false;
      };
    }
  )}

  if [ "$failed" != 0 ]; then
    exit 1
  fi
  touch $out
''
