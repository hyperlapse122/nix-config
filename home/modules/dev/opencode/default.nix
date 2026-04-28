{ config, lib, pkgs, ... }:
let
  cfg = config.my.dev.opencode;

  # opencode 본체: bunx 래퍼 (npm 레지스트리에서 매번 최신 opencode-ai 가져옴).
  # NOTE: programs.opencode.package = null 로 두면 home-manager master 모듈이 warnings 평가에서
  #       lib.versionAtLeast null "1.2.15" 로 터진다 (modules/programs/opencode.nix 의 알려진 버그).
  #       래퍼를 package 로 직접 넘기면 lib.getVersion 이 "" 를 반환 → versionAtLeast "" "..." = false
  #       → deprecated TUI keys 경고 평가도 안전하게 통과 + home.packages 도 HM 모듈이 자동 등록.
  opencodeWrapper = pkgs.writeShellApplication {
    name = "opencode";
    text = ''
      exec ${pkgs.bun}/bin/bunx opencode-ai@latest "$@"
    '';
  };

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
    # package 자리에 bunx 래퍼를 직접 넘긴다 — HM 모듈이 home.packages 에 자동 등록.
    programs.opencode = {
      enable = true;
      package = opencodeWrapper;
      settings = opencodeSettings;
      context = ./AGENTS.md;
      commands = ./commands;
    };

    # bunx 래퍼가 의존하는 bun 본체
    home.packages = [
      pkgs.bun
    ];

    # oh-my-openagent 플러그인 설정 (programs.opencode 가 다루지 않는 외부 플러그인 파일)
    xdg.configFile."opencode/oh-my-openagent.jsonc".source = ./oh-my-openagent.jsonc;
  };
}
