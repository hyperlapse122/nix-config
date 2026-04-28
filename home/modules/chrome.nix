{ config, lib, pkgs, ... }:
let
  cfg = config.my.chrome;
in {
  options.my.chrome = {
    enable = lib.mkEnableOption "Google Chrome";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.google-chrome ];
  };
}
