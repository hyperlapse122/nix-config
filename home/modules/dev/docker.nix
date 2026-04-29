{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.dev.docker;

  # docker-credential-glab — Docker credential helper for GitLab Container Registry.
  # `glab auth docker-helper` 의 얇은 래퍼. PATH 에 `docker-credential-glab` 이름으로
  # 노출되어야 docker 가 ~/.docker/config.json 의 credHelpers="glab" 매핑으로 호출할 수 있음
  # (docker 의 helper 검색 규칙: `docker-credential-<value>` 바이너리를 PATH 에서 찾음).
  # 첫 사용 시: `glab auth login --hostname <gitlab-host>` 로 토큰 등록.
  dockerCredentialGlab = pkgs.writeShellApplication {
    name = "docker-credential-glab";
    runtimeInputs = [ pkgs.glab ];
    text = ''
      exec glab auth docker-helper "$@"
    '';
  };
in
{
  options.my.dev.docker = {
    enable = lib.mkEnableOption "Docker CLI 자격증명 헬퍼 (registry.jpi.app → glab)";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      # `glab auth login` 직접 실행용 + 래퍼 런타임 의존성. git.nix 에도 포함되지만
      # 같은 store path 라 Nix 가 중복 제거함 — 모듈 독립성 유지를 위해 여기서도 명시.
      pkgs.glab
      dockerCredentialGlab
    ];

    # ~/.docker/config.json — Docker CLI 설정 (선언적 관리).
    # credHelpers 는 레지스트리별로 `docker-credential-<value>` 바이너리를 호출하도록 매핑.
    # registry.jpi.app — JPI 사내 GitLab Container Registry.
    # default 포트(443)와 명시적 `:443` 둘 다 등록 — docker 는 url 정규화 없이 문자열 매칭이라
    # `docker login registry.jpi.app:443` 처럼 명시 포트로 들어오면 별도 키가 필요함.
    #
    # 주의: 이 파일은 Nix store 심볼릭 링크라 읽기 전용. 다른 레지스트리에 `docker login` 으로
    # 자격증명을 저장하려 하면 EROFS 로 실패함 — 그런 레지스트리도 helper 로 관리하거나
    # 이 모듈에 추가로 선언해야 함.
    home.file.".docker/config.json".text = builtins.toJSON {
      credHelpers = {
        "registry.jpi.app" = "glab";
        "registry.jpi.app:443" = "glab";
      };
    };
  };
}
