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

    # A rootless container cannot mknod, so `--device /dev/kvm` bind-mounts
    # the host's node and root inside the container, mapped to this user,
    # cannot chmod it. Container users such as Nix's nixbld builders are not
    # in the host's kvm group either, so the host node's mode alone decides
    # whether NixOS VM tests in a container get KVM. Pin it to 0666 instead of
    # inheriting systemd's dev-kvm-mode build default; this file is
    # 99-local.rules, so its MODE is the last one applied. Rootful Podman would
    # also work, but the rootful socket stays off above.
    services.udev.extraRules = ''
      KERNEL=="kvm", GROUP="kvm", MODE="0666"
    '';

    # Rootless Podman needs /etc/subuid and /etc/subgid entries. nixpkgs only
    # sets this with mkDefault for normal users that declare no explicit ranges.
    users.users.${config.my.user.name}.autoSubUidGidRange = true;

    # virtualisation.podman.autoPrune runs as root against rootful storage,
    # which holds nothing here, so prune each user's rootless storage from
    # their own user manager instead. The wrapped package keeps /run/wrappers
    # on PATH for newuidmap, which the unit's own PATH would otherwise drop.
    # System accounts, such as the display manager's, have no subordinate ID
    # ranges, so the prune runs only in the configured account's manager.
    # minikube does not recreate a Podman node container that a prune
    # removed, so a stopped cluster would only come back through
    # `minikube delete`; the label filter keeps its container and network.
    systemd.user.services.podman-prune = {
      description = "Prune unused rootless Podman containers, networks, and dangling images";
      unitConfig.ConditionUser = config.my.user.name;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${config.virtualisation.podman.package}/bin/podman system prune --force --filter label!=created_by.minikube.sigs.k8s.io";
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
