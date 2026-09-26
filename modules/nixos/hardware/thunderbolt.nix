{ ... }:
{
  # The ThinkPad's Thunderbolt domain runs at security level `user`, so the
  # kernel keeps a new device such as the Apple Studio Display unauthorized --
  # its camera, speakers, and microphones stay unusable -- until bolt authorizes
  # it. With IOMMU DMA protection active, bolt enrolls and authorizes every new
  # Thunderbolt device without a prompt; that posture is accepted here.
  #
  # Plasma 6 does not enable bolt itself, and plasma6.nix ships the Thunderbolt
  # settings module (plasma-thunderbolt) only when bolt is enabled.
  services.hardware.bolt.enable = true;
}
