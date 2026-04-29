{ config, pkgs, lib, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../common
  ];

  # 호스트명 — flake.nix 의 nixosConfigurations 키와 디렉터리명과 일치해야 함.
  networking.hostName = "jpi-vmware";

  # 부트로더 (BIOS/Legacy) — VMware guest 의 디스크 구성. 정책 모듈: hosts/common/boot/grub.nix.
  # device 는 호스트 하드웨어 (VMware 가상 디스크) 라서 여기에 두지만, useOSProber 등 정책은 모듈 안에 박혀 있음.
  my.system.boot.grub = {
    enable = true;
    device = "/dev/sda";
  };

  # VMware guest 지원 (이 호스트 전용)
  virtualisation.vmware.guest.enable = true;
  hardware.graphics.enable = true;

  # nix-vscode-extensions overlay — 호스트 pkgs 에 적용해야 allowUnfree 가 전파됨.
  # home-manager 안에서 적용하면 별도 pkgs 인스턴스가 만들어져 Copilot/Pylance 등이 침묵 실패.
  # 자세한 사유는 home/modules/editors/AGENTS.md 와 root AGENTS.md 의 ANTI-PATTERNS 참고.
  nixpkgs.overlays = [ inputs.nix-vscode-extensions.overlays.default ];

  # 공유 모듈 활성화 (hosts/common/*)
  my.system.users.h82.enable = true;
  my.system.locale.korean.enable = true;
  my.system.networking.networkmanager.enable = true;
  my.system.networking.tailscale.enable = true;
  my.system.audio.pipewire.enable = true;
  my.system.ssh.server.enable = true;
  my.system.desktop.plasma.enable = true;
  my.system.programs.nix-ld.enable = true;
  my.system.programs.nix-index.enable = true;
  my.system.programs._1password = {
    enable = true;
    # 로그인 시 시스템 트레이로 자동 상주 — 브라우저 확장과 SSH agent 가
    # 1Password 데몬에 곧바로 붙을 수 있게 함.
    autostart = true;
  };
  my.system.virtualisation.docker.enable = true;
  my.system.hardware.logitech.enable = true;

  # aarch64 (arm64) 크로스 컴파일 활성화 — binfmt_misc + qemu-user 로 aarch64-linux 바이너리를 호스트에서 실행.
  # `nix build nixpkgs#pkgsCross.aarch64-multiplatform.<pkg>` 결과물 및
  # native aarch64 빌드 (cache.nixos.org 캐시 활용) 모두 가능. 정책: hosts/common/cross-compile.nix.
  my.system.cross-compile.aarch64.enable = true;

  # 호스트 단위 home-manager 오버라이드.
  # `home-manager.users.h82` 는 flake.nix 에서 이미 `import ./home/h82.nix` 로 정의되어 있다.
  # 같은 키에 attrset 을 또 대입하면 NixOS 모듈 시스템이 두 정의를 자동으로 병합한다
  # (home-manager 의 users 옵션 타입 = `attrsOf (submoduleWith ...)` — 각 사용자 항목이
  # 서브모듈이라 여러 정의가 imports 처럼 합쳐짐). 즉 home/h82.nix 의 설정을 그대로 둔 채
  # 이 호스트만의 override 를 얹는 패턴이다.
  home-manager.users.h82 = {
    # 화면 자동 잠금 / 자동 끄기 — VMware guest 데스크탑이라 둘 다 끔.
    # idle 잠금 (kscreenlockerrc Autolock) 과 DPMS (powerdevilrc turnOffDisplay) 가
    # 가상 세션에서는 의미 없이 거슬리기만 하므로 명시적으로 비활성.
    # NOTE: 절전/재개 시 잠금 (LockOnResume) 과 dim display 는 건드리지 않는다 —
    #       각 옵션 기본값(켜짐) 유지. 옵션 의미는 home/modules/desktop/plasma.nix 참고.
    my.desktop.plasma.autoLock.enable = false;
    my.desktop.plasma.screenOff.enable = false;
  };

  # 노트북 입력 (keyd + libinput palm rejection) — VMware guest 라서 비활성.
  # 호스트 키보드/터치패드는 hypervisor 가 추상화해서 전달하므로 keyd 매핑이 무의미하고,
  # libinput palm rejection 도 물리 터치패드가 없어 적용 대상이 없음.
  # 명시적으로 false 를 박아두는 이유: 기본값(false) 의존이 아니라 "이 호스트는 의도적으로 끔" 을 문서화.
  my.system.laptop-input.enable = false;

  # 방화벽 — VMware guest 라서 비활성 (공용 모듈 기본값 true 를 이 호스트에서만 false 로 override).
  # VMware Workstation 의 기본 NAT 네트워크 뒤에 있어 외부에서 직접 인바운드가 닿지 않고,
  # 호스트 OS 의 방화벽이 이미 1차 격리를 수행한다. guest 안에서 추가 iptables/nftables 레이어를
  # 돌리면 docker 의 자체 NAT 룰 (my.system.virtualisation.docker) 과 충돌할 여지만 늘어나고
  # 보호 측면의 이득은 거의 없음.
  my.system.networking.firewall.enable = false;

  # 한국어 입력 (fcitx5) 은 home-manager 모듈에서 관리: home/modules/i18n/fcitx5.nix

  # state version — 절대 임의로 바꾸지 말 것 (이 호스트가 처음 설치된 NixOS 릴리즈)
  system.stateVersion = "25.11";
}
