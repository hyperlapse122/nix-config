{ config, lib, pkgs, ... }:
let
  cfg = config.my.dev.agents;
in {
  options.my.dev.agents = {
    enable = lib.mkEnableOption "agent skills + 공유 커맨드 디렉터리 (~/.agents → ~/nix-config/agents live symlink)";
  };

  config = lib.mkIf cfg.enable {
    # Out-of-store (live) symlink: ~/.agents → ~/nix-config/agents.
    # OpenCode 의 oh-my-openagent 플러그인이 런타임에 skills/ 와 .skill-lock.json 을
    # 직접 쓰기 때문에 Nix store 경로(read-only)로 들어가면 EROFS 로 깨진다.
    # mkOutOfStoreSymlink 로 repo 경로를 그대로 노출 → 스킬 설치/잠금 갱신이 가능하고
    # 파일 변경이 rebuild 없이 즉시 반영된다.
    home.file.".agents".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/agents";
  };
}
