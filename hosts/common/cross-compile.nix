{
  config,
  lib,
  ...
}:
let
  cfg = config.my.system.cross-compile;
in
{
  options.my.system.cross-compile = {
    aarch64 = {
      enable = lib.mkEnableOption "aarch64 (arm64) 크로스 컴파일 + 외부 아키텍쳐 바이너리 실행 지원 (binfmt_misc + QEMU user-mode)";
    };
  };

  config = lib.mkIf cfg.aarch64.enable {
    # binfmt_misc 커널 기능 + QEMU user-mode emulation 으로 aarch64-linux 바이너리를
    # x86_64 호스트에서 그대로 실행할 수 있게 한다.
    #
    # 이 한 줄로 두 가지 워크플로가 동시에 열린다:
    #   1) 크로스 컴파일 결과 직접 실행
    #      `nix build nixpkgs#pkgsCross.aarch64-multiplatform.hello`
    #      → ./result/bin/hello 가 binfmt 등록된 qemu-aarch64 를 통해 그대로 동작.
    #   2) native aarch64 빌드를 QEMU 위에서 수행
    #      `import <nixpkgs> { localSystem = "aarch64-linux"; }` 또는 flake 의
    #      pkgsCrossNative 패턴 — 이 경로는 cache.nixos.org 의 aarch64-linux 결과물을
    #      그대로 받을 수 있어 (Hydra 가 native aarch64 를 캐시함) 빌드 시간이 크게 짧아진다.
    #      반면 (1) 의 cross-compile 산출물은 캐시되지 않으므로 반드시 로컬 빌드.
    #
    # `boot.binfmt.emulatedSystems` 는 NixOS 모듈이 자동으로 `nix.settings.extra-platforms`
    # 에도 동일 시스템을 추가하므로, nix 가 해당 system 의 derivation 을 build 가능 대상으로
    # 인식한다 — 별도 설정 불필요.
    #
    # 참고: https://wiki.nixos.org/wiki/Cross_Compiling
    boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  };
}
