{ config, lib, pkgs, ... }:
let
  cfg = config.my.dev.nodejs;
in {
  options.my.dev.nodejs = {
    enable = lib.mkEnableOption "Node.js LTS (nixpkgs 기본값 = 현재 LTS)";
  };

  config = lib.mkIf cfg.enable {
    # Node.js LTS — pkgs.nodejs 는 nixpkgs unstable 에서 현재 active LTS 라인을 가리킨다.
    home.packages = [ pkgs.nodejs ];
  };
}
