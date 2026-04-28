{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.boot.grub;
in {
  options.my.system.boot.grub = {
    enable = lib.mkEnableOption "GRUB 부트로더 (BIOS/Legacy) — useOSProber 비활성. EFI/UEFI 호스트는 my.system.boot.systemd-boot 사용";

    # `my.*` 옵션은 원칙적으로 `.enable` 하나만 노출하지만, 모듈 활성화 시 반드시 짝지어 지정해야 하는
    # 필수 인자는 옵션으로 함께 노출하는 것이 추적성에 더 좋다고 판단 — `.enable` 단독 원칙의 예외.
    # 선례: home/modules/editors/vscode.nix 가 동일한 사유로 `package` 를 노출.
    device = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "/dev/sda";
      description = ''
        GRUB 을 설치할 디스크 device (BIOS/Legacy 부트섹터 위치).
        enable = true 일 때 반드시 비어있지 않게 지정해야 함 — 아래 assertion 으로 강제.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # NixOS 의 boot.loader.grub.device 도 자체 검증을 하지만, 메시지가 일반적이라
    # `my.system.boot.grub.device` 라는 옵션 이름을 직접 짚어주는 친절한 메시지 제공.
    assertions = [{
      assertion = cfg.device != "";
      message = "my.system.boot.grub.enable = true 인 호스트는 my.system.boot.grub.device 를 지정해야 합니다 (예: \"/dev/sda\").";
    }];

    boot.loader.grub = {
      enable = true;
      device = cfg.device;
      # 멀티부트가 아닌 단일-OS 호스트가 일반적이므로 OS prober 는 비활성.
      # 부팅 속도 + 안정성 (다른 OS 의 부트섹터 변경에 영향받지 않음).
      # 멀티부트가 필요한 호스트는 이 모듈을 enable 하지 말고 inline 으로 직접 GRUB 설정할 것.
      useOSProber = false;
    };
  };
}
