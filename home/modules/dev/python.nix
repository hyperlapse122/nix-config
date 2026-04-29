{ config, lib, pkgs, ... }:
let
  cfg = config.my.dev.python;
in {
  options.my.dev.python = {
    enable = lib.mkEnableOption "Python 3 (nixpkgs 기본 인터프리터)";
  };

  config = lib.mkIf cfg.enable {
    # Python 3 — pkgs.python3 는 nixpkgs unstable 의 현재 기본 인터프리터를 가리킨다.
    home.packages = [ pkgs.python3 ];
  };
}
