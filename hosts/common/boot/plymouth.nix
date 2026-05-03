{ config, lib, ... }:
{
  config = lib.mkIf config.boot.plymouth.enable {
    boot = {
      kernelParams = lib.mkAfter [
        "quiet"
        "loglevel=3"
        "systemd.show_status=auto"
        "rd.udev.log_level=3"
        "splash"
        "vt.global_cursor_default=0"
      ];

      kernel.sysctl."kernel.printk" = "3 3 3 3";
    };
  };
}
