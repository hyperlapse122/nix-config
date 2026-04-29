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

  # docker-credential-gh — Docker credential helper for GitHub Container Registry.
  # `gh` 는 `glab auth docker-helper` 같은 내장 헬퍼가 없으므로 docker credential 프로토콜을
  # 직접 구현 (참고: https://gist.github.com/mislav/e154d707db230dc882d7194ec85d79f6).
  # 프로토콜:
  #   - `get`   : stdin 으로 호스트를 받아 {"Username":..,"Secret":..} JSON 출력
  #   - `store` : stdin 소비 후 no-op (인증은 `gh auth login` 으로 관리, docker login 으로 저장 안 함)
  #   - `erase` : stdin 소비 후 no-op
  # 첫 사용 시: `gh auth login` 으로 토큰 등록 (이미 git.nix 의 git credential helper 가
  # 같은 토큰을 공유하므로 GitHub 작업 중이면 보통 이미 인증되어 있음).
  dockerCredentialGh = pkgs.writeShellApplication {
    name = "docker-credential-gh";
    runtimeInputs = [ pkgs.gh ];
    text = ''
      cmd="''${1:-}"

      case "$cmd" in
        store | erase)
          # Docker 프로토콜 - stdin 소비하고 no-op.
          cat >/dev/null
          exit 0
          ;;
        get) ;;
        *) exit 1 ;;
      esac

      host="$(cat)"
      host="''${host#https://}"
      host="''${host%/}"

      # 헬퍼가 응답할 호스트 화이트리스트. credHelpers 매핑과 일치해야 함
      # (docker 가 다른 호스트로 이 바이너리를 호출하면 그건 설정 오류라 거절).
      case "$host" in
        ghcr.io | docker.pkg.github.com) ;;
        *) exit 1 ;;
      esac

      token="$(gh auth token --hostname github.com)"
      # 사용자명: gh API 우선, 실패 시 ghcr.io 가 PAT 와 함께 받아주는 dummy 값으로 대체.
      username="$(GH_HOST=github.com gh api user -q '.login' 2>/dev/null || echo oauth2accesstoken)"

      printf '{"Username":"%s","Secret":"%s"}\n' "$username" "$token"
    '';
  };
in
{
  options.my.dev.docker = {
    enable = lib.mkEnableOption "Docker CLI 자격증명 헬퍼 (registry.jpi.app → glab, ghcr.io → gh)";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      # `glab/gh auth login` 직접 실행용 + 래퍼 런타임 의존성. git.nix 에도 포함되지만
      # 같은 store path 라 Nix 가 중복 제거함 — 모듈 독립성 유지를 위해 여기서도 명시.
      pkgs.glab
      pkgs.gh
      dockerCredentialGlab
      dockerCredentialGh
    ];

    # ~/.docker/config.json — Docker CLI 설정 (선언적 관리).
    # credHelpers 는 레지스트리별로 `docker-credential-<value>` 바이너리를 호출하도록 매핑.
    #   - registry.jpi.app    → glab : JPI 사내 GitLab Container Registry
    #     default 포트(443)와 명시적 `:443` 둘 다 등록 — docker 는 url 정규화 없이 문자열 매칭
    #     이라 `docker login registry.jpi.app:443` 처럼 명시 포트로 들어오면 별도 키가 필요.
    #   - ghcr.io             → gh   : GitHub Container Registry
    #   - docker.pkg.github.com → gh : GitHub Packages (legacy, ghcr.io 로 마이그레이션 됨)
    #
    # 주의: 이 파일은 Nix store 심볼릭 링크라 읽기 전용. 다른 레지스트리에 `docker login` 으로
    # 자격증명을 저장하려 하면 EROFS 로 실패함 — 그런 레지스트리도 helper 로 관리하거나
    # 이 모듈에 추가로 선언해야 함.
    home.file.".docker/config.json".text = builtins.toJSON {
      credHelpers = {
        "registry.jpi.app" = "glab";
        "registry.jpi.app:443" = "glab";
        "ghcr.io" = "gh";
        "docker.pkg.github.com" = "gh";
      };
    };
  };
}
