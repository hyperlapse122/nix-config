{ pkgs }:

pkgs.writeShellApplication {
  name = "network-recovery";
  # curl is called by bare name, like the macOS tools below, so a test can
  # stub the HTTP body. The daemon PATH includes /usr/bin, which has curl.
  # A Nix curl here would sit ahead of that stub.
  # route, arp, ifconfig, networksetup, dscacheutil, killall, launchctl,
  # scutil, nc, and sudo are macOS tools and are not runtimeInputs.
  runtimeInputs = [
    pkgs.coreutils
    pkgs.gawk
  ];
  text = builtins.readFile ../scripts/network-recovery;
}
