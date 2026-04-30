{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.virtualisation.docker;
in {
  options.my.system.virtualisation.docker = {
    enable = lib.mkEnableOption "Docker daemon + docker-compose CLI (the user must be in the docker group to use it without sudo — h82 is already registered in hosts/common/users.nix)";
  };

  config = lib.mkIf cfg.enable {
    # Enable the Docker daemon. NixOS's docker package includes the compose v2 plugin,
    # so `docker compose ...` (with a space) works out of the box.
    virtualisation.docker.enable = true;

    # Also provide the legacy standalone `docker-compose` (hyphenated) binary.
    # Lets both compose v2 (`docker compose`) and v1 (`docker-compose`) be invoked,
    # so external scripts / docs that use either form keep working.
    environment.systemPackages = [ pkgs.docker-compose ];
  };
}
