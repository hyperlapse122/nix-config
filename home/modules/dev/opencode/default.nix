{ config, lib, pkgs, pkgs-unstable, ... }:
let
  cfg = config.my.dev.opencode;
  # opencode.json 을 그대로 읽어 settings 로 사용한다.
  # $schema 는 home-manager 의 programs.opencode 모듈이 자동으로 주입하므로 제거.
  opencodeSettings = lib.removeAttrs
    (builtins.fromJSON (builtins.readFile ./opencode.json))
    [ "$schema" ];
in {
  options.my.dev.opencode = {
    enable = lib.mkEnableOption "opencode CLI (bunx 래퍼) + 설정 파일 일체";
  };

  config = lib.mkIf cfg.enable {
    # programs.opencode 모듈 (home-manager master) 로 설정/컨텍스트/커맨드 관리.
    # 본체 바이너리는 아래 bunx 래퍼가 제공하므로 package = null 로 자체 install 비활성화.
    programs.opencode = {
      enable = true;
      package = null;
      settings = opencodeSettings;
      context = ./AGENTS.md;
      commands = ./commands;
    };

    # nixos-unstable 의 bun + opencode 래퍼 (npm 레지스트리에서 매번 최신 opencode-ai 가져옴)
    home.packages = [
      pkgs-unstable.bun
      (pkgs.writeShellApplication {
        name = "opencode";
        text = ''
          exec ${pkgs-unstable.bun}/bin/bunx opencode-ai@latest "$@"
        '';
      })
    ];

    # oh-my-openagent 플러그인 설정 (programs.opencode 가 다루지 않는 외부 플러그인 파일)
    xdg.configFile."opencode/oh-my-openagent.jsonc".source = ./oh-my-openagent.jsonc;
  };
}
