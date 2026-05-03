{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.obsidian;
in
{
  options.my.obsidian = {
    enable = lib.mkEnableOption "Obsidian";
  };

  config = lib.mkIf cfg.enable {
    programs.obsidian = {
      enable = true;
      package = pkgs.obsidian;
      cli.enable = true;
    };
  };
}
