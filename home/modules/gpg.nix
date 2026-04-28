{ config, lib, pkgs, ... }:
let
  cfg = config.my.gpg;
in {
  options.my.gpg = {
    enable = lib.mkEnableOption "GnuPG + gpg-agent (pinentry-qt)";
  };

  config = lib.mkIf cfg.enable {
    programs.gpg = {
      enable = true;
    };

    # gpg-agent: 사용자 systemd unit 으로 실행되며 pinentry 로 패스프레이즈를 받는다.
    # NOTE: pinentry-qt 는 Qt6 기반이라 KDE Plasma / Wayland 환경에 맞다.
    #       다른 데스크톱 환경을 쓰는 호스트가 생기면 그 때 옵션을 늘릴 것.
    services.gpg-agent = {
      enable = true;
      pinentry.package = pkgs.pinentry-qt;
    };
  };
}
