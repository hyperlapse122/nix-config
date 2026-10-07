{ pkgs }:
pkgs.writeShellApplication {
  name = "docker-cred-helpers";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.jq
  ];
  text = builtins.readFile ../scripts/docker-cred-helpers;
}
