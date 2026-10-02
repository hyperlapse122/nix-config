{ config, lib, ... }:
{
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  # The production boot splash needs the native KMS driver before switch-root.
  boot.initrd.kernelModules = lib.mkIf (!config.my.bootstrap) [ "i915" ];
  boot.kernelModules = [ "kvm-intel" ];
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  hardware.graphics.enable = true;
  hardware.bluetooth.enable = true;
  services.fstrim.enable = true;
  zramSwap.enable = false;
}
