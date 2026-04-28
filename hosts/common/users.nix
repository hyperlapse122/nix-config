{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.users.h82;
in {
  options.my.system.users.h82 = {
    enable = lib.mkEnableOption "h82 사용자 계정 (shell: zsh)";
  };

  config = lib.mkIf cfg.enable {
    users.users.h82 = {
      isNormalUser = true;
      description = "H82";
      extraGroups = [ "wheel" "networkmanager" "docker" ];
      shell = pkgs.zsh;
    };

    # h82 의 로그인 셸이 zsh 이므로 시스템 레벨 활성화도 같이 켜야 함.
    # (AGENTS.md 의 "Tightly coupling two modules" 안티패턴 회피: zsh 가
    #  h82 와 한 모듈 안에 묶이는 건 'h82 계정 셋업' 이라는 단일 관심사이므로 OK.)
    programs.zsh.enable = true;
  };
}
