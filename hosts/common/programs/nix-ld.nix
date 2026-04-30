{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.programs.nix-ld;
in {
  options.my.system.programs.nix-ld = {
    enable = lib.mkEnableOption "nix-ld (compatibility for foreign dynamically-linked binaries, e.g. toolchains fetched by mise)";
  };

  config = lib.mkIf cfg.enable {
    programs.nix-ld.enable = true;
  };
}
