{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.system.networking;
in
{
  options.my.system.networking = {
    networkmanager = {
      enable = lib.mkEnableOption "NetworkManager (default network stack on most desktop / laptop hosts)";
    };

    firewall = {
      # Intentionally `default = true` rather than mkEnableOption.
      # Reason: the firewall is the baseline safety net on every host — this prevents the
      # accident of a new host booting with inbound ports wide open because the maintainer
      # forgot to flip it on explicitly.
      # Only isolated environments (e.g. guests behind a hypervisor NAT) should override this to false.
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enables the NixOS firewall (networking.firewall.* / nftables backend).
          Blocks all inbound traffic except the ports we explicitly allow.
          Services that auto-open their own ports (e.g. services.openssh.openFirewall = true is the default) keep working.
          Default true — applied uniformly across hosts (assumes exposure to public networks).
          Recommended only for hosts with no external exposure (e.g. guests behind a hypervisor NAT) to set this to false.
        '';
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.networkmanager.enable {
      networking.networkmanager = {
        enable = true;

        # Interfaces that NetworkManager should NOT manage directly.
        # This is the consolidated form of the [keyfile] unmanaged-devices entries from
        # dotfiles/etc/NetworkManager/conf.d/*.conf — NixOS joins the list with ";" and writes
        # it to /etc/NetworkManager/NetworkManager.conf under [keyfile].
        # Actual owner of each interface:
        #   - lo:         loopback (NM should not touch)
        #   - vmnet*:     VMware Workstation/Player virtual networks (vmware-networks)
        #   - tailscale*: Tailscale daemon
        #   - docker*:    Bridges Docker manages itself
        #   - veth*:      Container virtual-ethernet pairs (Docker / Podman / etc.)
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
      # Assign firewall.enable directly instead of wrapping in lib.mkIf.
      # Reason: NixOS's networking.firewall.enable defaults to true. If we used mkIf to handle the false branch,
      # the config attribute itself would be undefined and NixOS's default (true) would still apply —
      # i.e. a host setting my.system.networking.firewall.enable = false would be silently ignored.
      # Direct assignment forwards cfg.firewall.enable's value (true/false) verbatim.
      networking.firewall.enable = cfg.firewall.enable;
    }
  ];
}
