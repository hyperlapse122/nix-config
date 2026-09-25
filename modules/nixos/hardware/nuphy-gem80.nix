{ pkgs, ... }:
{
  # These rules hand a device to the logged-in seat user through the `uaccess`
  # tag. systemd's 73-seat-late.rules runs the uaccess builtin only for devices
  # already tagged when it is evaluated, so the tag has to be set by a file that
  # sorts before it. `services.udev.extraRules` cannot do that: NixOS writes it
  # to 99-local.rules, applied after every other file, so a `uaccess` tag placed
  # there builds cleanly and grants nothing. `tests/udev-device-access.nix`
  # reads the built rules directory to keep it that way.
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "nuphy-gem80-udev-rules";
      destination = "/etc/udev/rules.d/60-nuphy-gem80.rules";
      text = ''
        # NuPhy Gem80 hidraw access for the VIA/WebHID configurator.
        KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="19f5", ATTRS{idProduct}=="3275", TAG+="uaccess"

        # STM32 ROM DFU bootloader access for firmware flashing. This is how the
        # Gem80 presents in bootloader mode, but 0483:df11 is ST's generic
        # bootloader identity, so the rule matches every STM32 device in DFU
        # mode, not only the Gem80.
        SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="df11", TAG+="uaccess"
      '';
    })
  ];
}
