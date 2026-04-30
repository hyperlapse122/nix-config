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
    enable = lib.mkEnableOption "Native module build toolchain (gcc + gnumake + pkg-config + autotools)";
  };

  config = lib.mkIf cfg.enable {
    # For building native node/python modules — node-gyp, cpu-features, buildcheck, etc. resolve cc, g++, make on PATH.
    # Equivalent to Debian's build-essential + autotools.
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
