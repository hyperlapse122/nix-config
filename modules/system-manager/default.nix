{ config, ... }:
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
}
