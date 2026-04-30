{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.locale.korean;
in {
  options.my.system.locale.korean = {
    enable = lib.mkEnableOption "Korean locale (Asia/Seoul, ko_KR.UTF-8)";
  };

  config = lib.mkIf cfg.enable {
    # Time zone / region
    time.timeZone = "Asia/Seoul";
    i18n.defaultLocale = "ko_KR.UTF-8";
    i18n.extraLocaleSettings = {
      LC_TIME = "ko_KR.UTF-8";
      LC_MONETARY = "ko_KR.UTF-8";
    };
  };
}
