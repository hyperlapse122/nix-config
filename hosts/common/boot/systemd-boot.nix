{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.boot.systemd-boot;
in {
  options.my.system.boot.systemd-boot = {
    enable = lib.mkEnableOption "systemd-boot 부트로더 (UEFI) — EFI 변수 쓰기 + Plymouth 스플래시 포함, ESP 마운트는 NixOS 기본값 (/boot). BIOS/Legacy 호스트는 my.system.boot.grub 사용";
  };

  config = lib.mkIf cfg.enable {
    boot.loader.systemd-boot.enable = true;

    # bootctl 이 EFI 변수 (BootOrder, BootXXXX) 를 직접 쓸 수 있게 허용.
    # NixOS 가 boot entry 를 등록/갱신하려면 필요.
    # 일부 펌웨어 (Mac 등) 에서 문제가 생기면 이 모듈을 enable 하지 말고 inline 으로
    # boot.loader.efi.canTouchEfiVariables = false; 와 함께 직접 systemd-boot 활성화.
    boot.loader.efi.canTouchEfiVariables = true;

    # 부팅 스플래시 (Plymouth) — UEFI/systemd-boot 호스트의 표준 정책으로 묶음.
    # `splash` 는 NixOS plymouth 모듈이 자동으로 boot.kernelParams 에 추가함.
    # 추가 quiet boot 파라미터 (`quiet`, `loglevel=3`, `rd.systemd.show_status=false` 등) 는
    # 의도적으로 미적용 — 시스템 전역 영향이 크고 디버깅 시 커널 메시지가 필요한 경우 많음.
    # 테마 변경은 호스트의 default.nix 에서 boot.plymouth.theme 으로 직접 설정.
    boot.plymouth = {
      enable = true;

      # HiDPI 디스플레이용 2x 렌더 스케일 — ~/dotfiles/etc/plymouth/plymouthd.conf 의
      # `[Daemon] DeviceScale=2` 이식. NixOS 의 boot.plymouth.extraConfig 는 자동 생성된
      # [Daemon] 섹션 내부 (Theme= 다음 줄) 에 raw 텍스트로 append 됨 (nixpkgs 의 plymouth.nix 참고).
      extraConfig = ''
        DeviceScale=2
      '';
    };
  };
}
