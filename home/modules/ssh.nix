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
    # home-manager 25.11 부터 programs.ssh 의 암묵적 default 들이 deprecated 됨.
    # `enableDefaultConfig = false` 로 끄고, 같은 값들을 matchBlocks."*" 에 직접 명시한다.
    # 출처: nix-community/home-manager release-25.11 modules/programs/ssh.nix
    #
    # 동작 전제 조건:
    #   1. 시스템 모듈 my.system.programs._1password 가 활성화된 호스트일 것.
    #   2. 1Password 앱 Settings → Developer → "Use the SSH agent" 활성화.
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks."*" = {
        # 이 모듈의 본 목적 — 1Password agent 연동.
        identityAgent = onePassPath;

        # 이하는 home-manager 가 enableDefaultConfig=true 일 때 자동 주입하던 값들.
        # 25.11+ 에선 사용자가 직접 박아야 동작이 동일하게 유지됨.
        forwardAgent = false;
        addKeysToAgent = "no";
        compression = false;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "no";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";
      };
    };
  };
}
