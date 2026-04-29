{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.networking.tailscale;
in {
  options.my.system.networking.tailscale = {
    enable = lib.mkEnableOption "Tailscale (WireGuard 메쉬 VPN) — 첫 부팅 후 `sudo tailscale up` 으로 인증 필요. 시크릿 관리 모듈이 없으므로 authKey 자동화는 사용하지 않음.";
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;

      # UDP 41641 (cfg.port 기본값) 오픈 — peer 간 직접 연결 (NAT hole punching 후 P2P) 을 위한 WireGuard 포트.
      # 닫혀있어도 DERP 릴레이로 폴백되어 동작은 하지만, 직접 연결이 가능한 환경에서 지연/대역폭 측면에서 유리.
      # 호스트가 my.system.networking.firewall.enable = false 인 경우 (예: jpi-vmware) 이 옵션은 무시되며 부작용 없음.
      openFirewall = true;

      # client 모드 — 다른 노드의 exit node / subnet route 를 사용 가능하지만, 이 호스트는 그런 역할을 하지 않음.
      # NixOS 모듈이 자동으로 networking.firewall.checkReversePath = "loose" 를 설정해
      # exit node 사용 시 reverse-path filter 가 트래픽을 떨어뜨리는 문제를 회피한다 (nixos/modules/services/networking/tailscale.nix 참고).
      # 이 호스트를 exit node 로 노출하거나 subnet routing 을 하려면 "server" 또는 "both" 로 변경 필요.
      useRoutingFeatures = "client";
    };

    # tailscale CLI 는 services.tailscale.enable 가 자동으로 environment.systemPackages 에 추가하므로 별도 등록 불필요.
    # NetworkManager 의 unmanaged 인터페이스 목록 (`tailscale*`) 은 hosts/common/networking.nix 에서 이미 처리됨.
  };
}
