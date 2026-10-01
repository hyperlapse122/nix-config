# The hosts under a hosts/ directory, split by kind. A directory that holds
# host.nix is a non-NixOS host; every other one is a NixOS host. Host
# discovery in flake.nix and every check that enumerates hosts share this, so
# they all agree on which hosts have a NixOS system, and with it a disk layout.
#
#   hosts = import ./lib/hosts.nix { inherit lib; } ./hosts;
#   -> { all, nixos, linux, withVariants }
#
# withVariants build hostName gives the production and bootstrap output of one
# host as name/value pairs for listToAttrs, calling build hostName bootstrap.
{ lib }:
dir:
let
  all = import ../tests/lib/directories.nix { inherit lib; } dir;
  isLinux = hostName: builtins.pathExists (dir + "/${hostName}/host.nix");
in
{
  inherit all;
  nixos = lib.filter (hostName: !isLinux hostName) all;
  linux = lib.filter isLinux all;

  withVariants =
    build: hostName:
    map
      (bootstrap: {
        name = if bootstrap then "${hostName}-bootstrap" else hostName;
        value = build hostName bootstrap;
      })
      [
        false
        true
      ];
}
