{ config, lib, ... }:
let
  nvidiaKms =
    lib.elem "nvidia" config.services.xserver.videoDrivers && config.hardware.nvidia.modesetting.enable;
in
{
  # Production boots straight from the firmware logo to SDDM. Bootstrap outputs
  # keep the menu and the text log, because installation and recovery need both.
  config = lib.mkIf (!config.my.bootstrap) {
    # systemd-boot opens the menu when a key is held at power-on.
    boot.loader.timeout = 0;

    boot.plymouth = {
      enable = true;
      theme = "bgrt";
    };

    # boot.initrd.verbose is left alone: only the scripted initrd reads it.
    # show_status=error still prints failures, which show_status=false would
    # hide, and unlike auto it stays quiet when a slow boot crosses systemd's
    # delay threshold.
    boot.consoleLogLevel = 3;
    boot.kernelParams = [
      "quiet"
      "udev.log_level=3"
      "rd.udev.log_level=3"
      "systemd.show_status=error"
      "rd.systemd.show_status=error"
    ];

    # Plymouth ignores simpledrm until its 8 s device timeout, so without a
    # native KMS driver in the initrd a TPM2-unlocked boot leaves the initrd
    # before any splash appears. nvidia_uvm stays out: nixpkgs loads it through
    # a post-load softdep once the nvidia udev rules have run.
    boot.initrd.kernelModules = lib.mkIf nvidiaKms [
      "nvidia"
      "nvidia_modeset"
      "nvidia_drm"
    ];
  };
}
