{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.dev.python;
in
{
  options.my.dev.python = {
    enable = lib.mkEnableOption "Python 3 (nixpkgs default interpreter)";
  };

  config = lib.mkIf cfg.enable {
    # Python 3 — pkgs.python3 in nixpkgs unstable points at the current default interpreter.
    home.packages = [ pkgs.python3 ];
  };
}
