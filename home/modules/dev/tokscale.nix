{ config, lib, pkgs, ... }:
let
  cfg = config.my.dev.tokscale;

  # tokscale CLI: bunx 래퍼 (npm 레지스트리에서 매번 최신 tokscale 가져옴).
  # opencode 모듈과 동일한 패턴 — bun 본체는 별도로 home.packages 에 넣어 의존성 보장.
  tokscaleWrapper = pkgs.writeShellApplication {
    name = "tokscale";
    text = ''
      exec ${pkgs.bun}/bin/bunx tokscale@latest "$@"
    '';
  };
in {
  options.my.dev.tokscale = {
    enable = lib.mkEnableOption "tokscale CLI (bunx 래퍼)";
  };

  config = lib.mkIf cfg.enable {
    # bunx 래퍼 + bun 본체
    home.packages = [
      tokscaleWrapper
      pkgs.bun
    ];
  };
}
