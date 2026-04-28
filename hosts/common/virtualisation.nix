{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.virtualisation.docker;
in {
  options.my.system.virtualisation.docker = {
    enable = lib.mkEnableOption "Docker 데몬 + docker-compose CLI (sudo 없이 쓰려면 사용자가 docker 그룹에 속해야 함 — h82 는 hosts/common/users.nix 에서 이미 등록됨)";
  };

  config = lib.mkIf cfg.enable {
    # Docker 데몬 활성화. NixOS 의 docker 패키지에는 compose v2 플러그인이 포함되어
    # `docker compose ...` (공백) 형태가 즉시 동작함.
    virtualisation.docker.enable = true;

    # 레거시 standalone 바이너리 `docker-compose` (하이픈) 도 같이 제공.
    # compose v2 (`docker compose`) 와 v1 (`docker-compose`) 둘 다 호출 가능하게 하기 위함 —
    # 외부 스크립트/문서가 어느 쪽을 쓰든 깨지지 않도록.
    environment.systemPackages = [ pkgs.docker-compose ];
  };
}
