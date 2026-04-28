{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.programs.nix-ld;
in {
  options.my.system.programs.nix-ld = {
    enable = lib.mkEnableOption "nix-ld (외부 동적 링킹 바이너리 호환, 예: mise 가 받는 toolchain)";
  };

  config = lib.mkIf cfg.enable {
    programs.nix-ld.enable = true;
  };
}
