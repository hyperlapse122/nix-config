{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.system.ssh;
in
{
  options.my.system.ssh = {
    server.enable = lib.mkEnableOption "OpenSSH server (sshd, password auth disabled, root login disallowed)";
  };

  config = lib.mkIf cfg.server.enable {
    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
      settings.PermitRootLogin = "no";
    };
  };
}
