{ pkgs }:
pkgs.writeShellApplication {
  name = "minikube-darwin-start";
  text = builtins.readFile ../scripts/minikube-darwin-start;
}
