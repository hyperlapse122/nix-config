{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.networking;
in {
  options.my.system.networking = {
    networkmanager = {
      enable = lib.mkEnableOption "NetworkManager (대다수 데스크톱/노트북 호스트의 기본 네트워크 스택)";
    };

    firewall = {
      # 의도적으로 mkEnableOption 이 아닌 default = true 로 둔다.
      # 이유: 방화벽은 모든 호스트의 기본 안전 장치 — 새 호스트가 명시적으로 켜는 걸 잊어
      # 인바운드 포트가 활짝 열린 채로 부팅되는 사고를 막기 위함.
      # 격리된 환경 (예: 하이퍼바이저 NAT 뒤의 게스트) 만 false 로 명시적으로 꺼야 한다.
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          NixOS 방화벽 (networking.firewall.* / nftables 백엔드) 활성화.
          명시적으로 허용한 포트 외 모든 인바운드 트래픽 차단.
          서비스가 자동으로 포트를 여는 경우 (예: services.openssh.openFirewall = true 가 기본값) 는 그대로 동작한다.
          기본값 true — 모든 호스트에 일괄 적용 (공용 네트워크 노출을 가정).
          하이퍼바이저 NAT 뒤에 격리된 게스트 등 외부 노출이 없는 호스트만 false 로 끄는 것을 권장.
        '';
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.networkmanager.enable {
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
    })

    {
      # firewall.enable 은 lib.mkIf 로 감싸지 않고 직접 대입한다.
      # 이유: NixOS 의 networking.firewall.enable 기본값이 true 라서, mkIf 로 false 분기를 처리하면
      # config attribute 자체가 정의되지 않고 NixOS 기본값(true) 가 그대로 적용된다.
      # 즉 호스트가 my.system.networking.firewall.enable = false 로 끄겠다는 의도가 묵살된다.
      # 직접 대입하면 cfg.firewall.enable 의 값(true/false) 이 그대로 전달된다.
      networking.firewall.enable = cfg.firewall.enable;
    }
  ];
}
