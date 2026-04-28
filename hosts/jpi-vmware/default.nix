{ config, pkgs, lib, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../common
  ];

  # 호스트명 — flake.nix 의 nixosConfigurations 키와 디렉터리명과 일치해야 함.
  networking.hostName = "jpi-vmware";

  # 부트로더 (BIOS/Legacy) — VMware guest 의 디스크 구성에 맞춤.
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
    useOSProber = false;
  };

  # VMware guest 지원 (이 호스트 전용)
  virtualisation.vmware.guest.enable = true;

  # nix-vscode-extensions overlay — 호스트 pkgs 에 적용해야 allowUnfree 가 전파됨.
  # home-manager 안에서 적용하면 별도 pkgs 인스턴스가 만들어져 Copilot/Pylance 등이 침묵 실패.
  # 자세한 사유는 home/modules/editors/AGENTS.md 와 root AGENTS.md 의 ANTI-PATTERNS 참고.
  nixpkgs.overlays = [ inputs.nix-vscode-extensions.overlays.default ];

  # 공유 모듈 활성화 (hosts/common/*)
  my.system.users.h82.enable = true;
  my.system.locale.korean.enable = true;
  my.system.networking.networkmanager.enable = true;
  my.system.audio.pipewire.enable = true;
  my.system.ssh.server.enable = true;
  my.system.desktop.plasma.enable = true;
  my.system.programs.nix-ld.enable = true;
  my.system.programs._1password.enable = true;

  # 노트북 입력 (keyd + libinput palm rejection) — VMware guest 라서 비활성.
  # 호스트 키보드/터치패드는 hypervisor 가 추상화해서 전달하므로 keyd 매핑이 무의미하고,
  # libinput palm rejection 도 물리 터치패드가 없어 적용 대상이 없음.
  # 명시적으로 false 를 박아두는 이유: 기본값(false) 의존이 아니라 "이 호스트는 의도적으로 끔" 을 문서화.
  my.system.laptop-input.enable = false;

  # 한국어 입력 (fcitx5) 은 home-manager 모듈에서 관리: home/modules/i18n/fcitx5.nix

  # state version — 절대 임의로 바꾸지 말 것 (이 호스트가 처음 설치된 NixOS 릴리즈)
  system.stateVersion = "25.11";
}
