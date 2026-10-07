{ lib, pkgs, ... }:
{
  # The minikube package links its own bin/kubectl to minikube, which
  # downloads a kubectl on first use; the real kubectl takes priority. Each
  # package installs its zsh completion into share/zsh/site-functions.
  home.packages = [
    (lib.hiPrio pkgs.kubectl)
    pkgs.kubernetes-helm
    pkgs.minikube
  ];
}
