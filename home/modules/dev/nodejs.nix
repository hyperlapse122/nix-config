{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.dev.nodejs;
in
{
  options.my.dev.nodejs = {
    enable = lib.mkEnableOption "Node.js LTS + yarn (nixpkgs default = current LTS)";
  };

  config = lib.mkIf cfg.enable {
    # Node.js LTS — pkgs.nodejs in nixpkgs unstable points at the current active LTS line.
    # yarn (classic 1.x) — alternative package manager to npm.
    home.packages = [
      pkgs.nodejs
      pkgs.yarn-berry
    ];
  };
}
