{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.networking.networkmanager;
in {
  options.my.system.networking.networkmanager = {
    enable = lib.mkEnableOption "NetworkManager (대다수 데스크톱/노트북 호스트의 기본 네트워크 스택)";
  };

  config = lib.mkIf cfg.enable {
    networking.networkmanager = {
      enable = true;

      # NM이 직접 관리하지 않을 인터페이스 목록.
      # dotfiles/etc/NetworkManager/conf.d/*.conf 의 [keyfile] unmanaged-devices
      # 항목들을 한 줄로 합친 것 — NixOS는 이 리스트를 ";" 로 join 해서
      # /etc/NetworkManager/NetworkManager.conf 의 [keyfile] 섹션에 기록한다.
      # 각 인터페이스의 실제 관리 주체:
      #   - lo:         loopback (NM 개입 불필요)
      #   - vmnet*:     VMware Workstation/Player 의 가상 네트워크 (vmware-networks)
      #   - tailscale*: Tailscale 데몬
      #   - docker*:    Docker 가 직접 관리하는 브릿지
      #   - veth*:      컨테이너의 가상 이더넷 페어 (Docker/Podman 등)
      unmanaged = [
        "interface-name:lo"
        "interface-name:vmnet*"
        "interface-name:tailscale*"
        "interface-name:docker*"
        "interface-name:veth*"
      ];
    };
  };
}
