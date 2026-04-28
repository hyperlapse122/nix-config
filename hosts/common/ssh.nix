{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.ssh;
in {
  options.my.system.ssh = {
    server.enable = lib.mkEnableOption "OpenSSH 서버 (sshd, password 인증 비활성, root 로그인 비허용)";
  };

  config = lib.mkIf cfg.server.enable {
    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
      settings.PermitRootLogin = "no";
    };
  };
}
