{ config, lib, pkgs, ... }:
let
  cfg = config.my.ssh;
  # 1Password SSH agent UNIX socket (Linux 전용 경로).
  # 루트 AGENTS.md 의 "NixOS only (no nix-darwin / WSL planned)" 정책에 따라
  # 위키의 Darwin 분기 (`Library/Group Containers/.../agent.sock`) 는 의도적으로 생략.
  onePassPath = "${config.home.homeDirectory}/.1password/agent.sock";
in {
  options.my.ssh = {
    enable = lib.mkEnableOption "SSH Client configuration";
  };

  config = lib.mkIf cfg.enable {
    # IdentityAgent 를 ~/.ssh/config 에 직접 박는다.
    # 위키 노트: .ssh/config 의 IdentityAgent 가 SSH_AUTH_SOCK 환경변수보다 우선순위가 높음.
    #
    # 동작 전제 조건:
    #   1. 시스템 모듈 my.system.programs._1password 가 활성화된 호스트일 것.
    #   2. 1Password 앱에서 Settings → Developer → "Use the SSH agent" 옵션을 켤 것.
    programs.ssh = {
      enable = true;
      extraConfig = ''
        Host *
            IdentityAgent ${onePassPath}
      '';
    };
  };
}
