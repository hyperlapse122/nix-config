{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.hardware.logitech;
in {
  options.my.system.hardware.logitech = {
    enable = lib.mkEnableOption "udev rule for Logitech Unifying/Bolt receivers (disables wakeup during USB autosuspend)";
  };

  config = lib.mkIf cfg.enable {
    # Pin the `power/wakeup` attribute of Logitech Unifying Receiver (idProduct=c52b)
    # and Bolt Receiver (idProduct=c548) to disabled, blocking the host from auto-waking
    # on mouse/keyboard input while in USB autosuspend.
    # The goal is to prevent unintended wake-from-sleep events such as a laptop waking up
    # because of mouse-wheel/button collisions inside a bag.
    #
    # Source: dotfiles/etc/udev/rules.d/logitech-receiver.rules (ported as-is).
    # idVendor 046d = Logitech.
    # idProduct: c52b = Unifying Receiver, c548 = Bolt Receiver.
    # `|` is the OR separator in systemd's udev matcher (systemd 240+).
    #
    # services.udev.extraRules is merged into /etc/udev/rules.d/99-local.rules.
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="usb", DRIVERS=="usb", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c52b|c548", ATTR{power/wakeup}="disabled"
    '';
  };
}
