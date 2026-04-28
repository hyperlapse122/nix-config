{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.networking.networkmanager;
in {
  options.my.system.networking.networkmanager = {
    enable = lib.mkEnableOption "NetworkManager (대다수 데스크톱/노트북 호스트의 기본 네트워크 스택)";
  };

  config = lib.mkIf cfg.enable {
    networking.networkmanager.enable = true;
  };
}
