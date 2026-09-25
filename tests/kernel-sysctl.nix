/*
  Check interface:

    import ./tests/kernel-sysctl.nix { inherit pkgs self; }

  Asserts that every host configuration renders the kernel sysctl values
  declared in modules/nixos/system/base.nix into /etc/sysctl.d/60-nixos.conf,
  the file systemd-sysctl applies at boot.

  Verifies:
  - ThinkPad-X1-Carbon-Gen-11, ThinkPad-X1-Carbon-Gen-11-bootstrap, MS-7D91,
    and MS-7D91-bootstrap all keep the sysctl.d/60-nixos.conf etc entry enabled.
  - Each rendered file carries the inotify limits and IPv4/IPv6 forwarding
    lines exactly, matched as whole lines so a longer value cannot satisfy
    the assertion.
*/
{ pkgs, self }:
let
  expectedLines = [
    "fs.inotify.max_user_watches=524288"
    "fs.inotify.max_user_instances=524288"
    "net.ipv4.ip_forward=1"
    "net.ipv6.conf.all.forwarding=1"
  ];

  assertHost =
    hostName: host:
    let
      sysctlEntry = host.config.environment.etc."sysctl.d/60-nixos.conf";
    in
    ''
      if [ "${builtins.toJSON sysctlEntry.enable}" != "true" ]; then
        echo "sysctl.d/60-nixos.conf is not enabled on ${hostName}" >&2
        exit 1
      fi
    ''
    + pkgs.lib.concatMapStrings (line: ''
      if ! grep -Fxq -- '${line}' "${sysctlEntry.source}"; then
        echo "${hostName}: sysctl.d/60-nixos.conf is missing the line '${line}'" >&2
        exit 1
      fi
    '') expectedLines;
in
pkgs.runCommand "kernel-sysctl-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
  set -x

  ${assertHost "ThinkPad-X1-Carbon-Gen-11" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11}
  ${assertHost "ThinkPad-X1-Carbon-Gen-11-bootstrap" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap}
  ${assertHost "MS-7D91" self.nixosConfigurations.MS-7D91}
  ${assertHost "MS-7D91-bootstrap" self.nixosConfigurations.MS-7D91-bootstrap}

  touch $out
''
