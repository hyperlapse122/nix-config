{ ... }:
{
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;

  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "h82" ];
  };
}
