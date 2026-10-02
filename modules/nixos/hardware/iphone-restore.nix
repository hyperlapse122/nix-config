{ pkgs, ... }:
{
  # Restores an iPhone or iPad in DFU or recovery mode from an IPSW file with
  # `idevicerestore`, run as the logged-in user. `docs/recovery.md` has the
  # procedure.
  #
  # In DFU and recovery mode the device is driven over raw USB through
  # libirecovery, so the user needs the device node itself. libirecovery's own
  # udev rule hands it to a placeholder group nixpkgs leaves unset, so it is not
  # installed. The rule below tags it `uaccess` instead, from a file that sorts
  # before systemd's 73-seat-late.rules: a tag set from 99-local.rules, where
  # `services.udev.extraRules` lands, builds cleanly and grants nothing.
  # `tests/udev-device-access.nix` reads the built rules directory to keep it
  # that way. 05ac:1227 is DFU, 05ac:1222 is legacy WTF, and 05ac:1280-1283
  # are recovery mode.
  #
  # Once the restore ramdisk boots, the device re-enumerates in restore mode
  # and idevicerestore reaches it through usbmuxd, which runs as its own user
  # and owns Apple devices through the module's group rule.
  services.udev.packages = [
    (pkgs.writeTextDir "etc/udev/rules.d/60-apple-recovery.rules" ''
      # Apple iOS devices in DFU, legacy WTF, and recovery mode.
      SUBSYSTEM=="usb", ATTR{idVendor}=="05ac", ATTR{idProduct}=="122[27]|128[0-3]", TAG+="uaccess"
    '')
  ];

  services.usbmuxd.enable = true;

  environment.systemPackages = [
    pkgs.idevicerestore
    # `irecovery -q` shows whether a device is in DFU or recovery mode.
    pkgs.libirecovery
    pkgs.libimobiledevice
  ];
}
