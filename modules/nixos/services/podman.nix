{
  config,
  lib,
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

    # Rootless Podman needs /etc/subuid and /etc/subgid entries. nixpkgs only
    # sets this with mkDefault for normal users that declare no explicit ranges.
    users.users.h82.autoSubUidGidRange = true;

    # virtualisation.podman.autoPrune runs as root against rootful storage,
    # which holds nothing here, so prune each user's rootless storage from
    # their own user manager instead. The wrapped package keeps /run/wrappers
    # on PATH for newuidmap, which the unit's own PATH would otherwise drop.
    # Only the configured account has subordinate ID ranges; other user
    # managers, such as the display manager's, skip the unit.
    systemd.user.services.podman-prune = {
      description = "Prune unused rootless Podman containers, networks, and dangling images";
      unitConfig.ConditionUser = config.my.user.name;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${config.virtualisation.podman.package}/bin/podman system prune --force";
      };
    };

    systemd.user.timers.podman-prune = {
      description = "Weekly rootless Podman prune";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}
