{ config, lib, pkgs, pkgs-unstable, ... }:
let
  cfg = config.my.chrome;
in {
  options.my.chrome = {
    enable = lib.mkEnableOption "Google Chrome (latest stable from nixos-unstable)";
  };

  config = lib.mkIf cfg.enable {
    # nixos-unstable 의 google-chrome 사용 (stable 채널보다 빠른 업데이트 주기)
    home.packages = [ pkgs-unstable.google-chrome ];
  };
}
