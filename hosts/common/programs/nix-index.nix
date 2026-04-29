{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.system.programs.nix-index;
in
{
  options.my.system.programs.nix-index = {
    enable = lib.mkEnableOption "nix-index (nix-locate 명령 + zsh/bash command-not-found 통합)";
  };

  config = lib.mkIf cfg.enable {
    # nix-index 패키지 설치 + 셸 통합 (zsh/bash 가 command-not-found.sh 를 source).
    # `nix-locate <file>` 로 store 안의 파일이 어느 패키지에 속하는지 검색하고,
    # 없는 명령어 입력 시 어떤 nixpkgs 패키지에 들어 있는지 제안한다.
    programs.nix-index.enable = true;

    # nixpkgs 의 레거시 command-not-found (programs.sqlite 기반 제안기) 와 상호 배타.
    # nixos/modules/programs/nix-index.nix 가 assertion 으로 강제하므로 명시적으로 끈다.
    # nix-index 쪽이 더 빠르고 채널 외 패키지도 인덱싱하므로 대체.
    programs.command-not-found.enable = false;

    # CAVEAT: 인덱스 DB 는 자동 생성/갱신되지 않는다.
    # 활성화 후 사용자 셸에서 한 번 `nix-index` 를 실행해
    # ~/.cache/nix-index 를 채워야 nix-locate 와 command-not-found 제안이 동작한다.
  };
}
