{
  config,
  lib,
  pkgs,
  ...
}:
let
  # The reader drivers pcscd loads, as the NixOS services.pcscd module
  # provides them. Without ccid, pcscd sees no YubiKey reader at all, and the
  # user's scdaemon (disable-ccid, pcsc-shared) depends entirely on pcscd.
  pcscPlugins = pkgs.buildEnv {
    name = "pcscd-plugins";
    paths = [ "${pkgs.ccid}/pcsc/drivers" ];
  };

  # An empty reader.conf keeps pcscd from scanning its whole config directory;
  # see https://github.com/NixOS/nixpkgs/issues/121088.
  readerConf = pkgs.writeText "reader.conf" "";
in
{
  # The distribution owns its user database; system-manager must never write
  # /etc/passwd, /etc/group, or /etc/shadow on a host it does not own.
  services.userborn.enable = false;

  # Read by the non-NixOS `nr` to learn which host and variant it applies,
  # instead of guessing the host from `uname -n`, which the distribution owns.
  environment.etc."nix-config-host".text = ''
    host=${config.my.hostName}
    variant=${if config.my.bootstrap then "bootstrap" else "production"}
  '';

  # nix.conf is the flake's to own, as it is on NixOS: this replaces the
  # installer's copy and keeps it as nix.conf.system-manager-backup. The
  # upstream module drops the installer's build-users-group, so it is set here
  # to keep builds running as the unprivileged nixbld users.
  nix.enable = true;
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    build-users-group = "nixbld";
  };

  # pcscd runs as root with no socket-activation dependency on a distribution
  # package: the unit and socket are written here, and the preflight in `nr`
  # refuses to run while a distribution pcscd unit exists alongside them.
  systemd.sockets.pcscd = {
    description = "PC/SC Smart Card Daemon Activation Socket";
    wantedBy = [ "multi-user.target" ];
    socketConfig = {
      ListenStream = "/run/pcscd/pcscd.comm";
      SocketMode = "0666";
      RemoveOnStop = true;
    };
  };
  systemd.services.pcscd = {
    description = "PC/SC Smart Card Daemon";
    requires = [ "pcscd.socket" ];
    after = [ "pcscd.socket" ];
    environment.PCSCLITE_HP_DROPDIR = pcscPlugins;
    serviceConfig.ExecStart = "${lib.getExe pkgs.pcsclite} -f -x -c ${readerConf}";
  };
}
