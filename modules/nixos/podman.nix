{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.podman;
in
{
  options.my.podman = {
    enable = lib.mkEnableOption "rootless Podman container runtime with Docker CLI compatibility";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
    };

    # Disable the rootful systemd socket so only the rootless user socket is active.
    # virtualisation.podman.enable adds "sockets.target" to systemd.sockets.podman.wantedBy,
    # which starts the rootful daemon socket. We explicitly empty it.
    systemd.sockets.podman.wantedBy = lib.mkForce [ ];
  };
}
