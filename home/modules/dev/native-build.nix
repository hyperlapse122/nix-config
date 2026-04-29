{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.dev.native-build;
in
{
  options.my.dev.native-build = {
    enable = lib.mkEnableOption "네이티브 모듈 빌드 툴체인 (gcc + gnumake + pkg-config + autotools)";
  };

  config = lib.mkIf cfg.enable {
    # 네이티브 노드/파이썬 모듈 빌드용 — node-gyp, cpu-features, buildcheck 등이 cc, g++, make 를 PATH 에서 찾는다.
    # Debian 의 build-essential 동등 구성 + autotools.
    home.packages = with pkgs; [
      gcc
      gnumake
      pkg-config
      autoconf
      automake
      libtool
    ];
  };
}
