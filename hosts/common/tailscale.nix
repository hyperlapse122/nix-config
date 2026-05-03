{
  config,
  lib,
  ...
}:
let
  cfg = config.my.system.networking.tailscale;
in
{
  options.my.system.networking.tailscale = {
    enable = lib.mkEnableOption "Tailscale (WireGuard mesh VPN) — requires `sudo tailscale up` after first boot to authenticate. No authKey automation since this repo has no secret-management module.";
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;

      # Open UDP 41641 (cfg.port default) — the WireGuard port used for direct peer connections (P2P after NAT hole punching).
      # If closed, traffic falls back to a DERP relay and still works, but direct connections give better latency / bandwidth where possible.
      # When the host has my.system.networking.firewall.enable = false (e.g. jpi-vmware), this option is no-op and harmless.
      openFirewall = true;

      # client mode — can use other nodes' exit-node / subnet routes, but this host does not act as either.
      # The NixOS module automatically sets networking.firewall.checkReversePath = "loose" to avoid the reverse-path
      # filter dropping traffic when using an exit node (see nixos/modules/services/networking/tailscale.nix).
      # To expose this host AS an exit node or do subnet routing, change this to "server" or "both".
      useRoutingFeatures = "client";

      extraSetFlags = [
        "--accept-routes"
        "--operator=h82"
      ];
    };

    # The tailscale CLI is added to environment.systemPackages automatically by services.tailscale.enable, so no explicit package registration is needed.
    # The NetworkManager unmanaged-interfaces list (`tailscale*`) is already handled in hosts/common/networking.nix.
  };
}
