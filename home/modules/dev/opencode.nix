{ config, lib, pkgs, pkgs-unstable, ... }:
let
  cfg = config.my.dev.opencode;
in {
  options.my.dev.opencode = {
    enable = lib.mkEnableOption "opencode CLI (bunx 래퍼, bun 은 nixos-unstable)";
  };

  config = lib.mkIf cfg.enable {
    # nixos-unstable 의 bun 사용 (stable 보다 빠른 업데이트 주기)
    # opencode 자체는 npm 레지스트리에서 매번 최신을 가져온다 (opencode-ai@latest)
    home.packages = [
      pkgs-unstable.bun
      (pkgs.writeShellApplication {
        name = "opencode";
        text = ''
          exec ${pkgs-unstable.bun}/bin/bunx opencode-ai@latest "$@"
        '';
      })
    ];
  };
}
