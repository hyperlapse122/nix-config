{ pkgs }:
pkgs.writeShellApplication {
  name = "mobile-devices";
  runtimeInputs = [
    pkgs.gnugrep
    pkgs.jq
  ];
  text = builtins.readFile ../scripts/mobile-devices;
}
