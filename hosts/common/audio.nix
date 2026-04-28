{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.audio.pipewire;
in {
  options.my.system.audio.pipewire = {
    enable = lib.mkEnableOption "PipeWire 사운드 (ALSA + PulseAudio 호환 레이어 포함)";
  };

  config = lib.mkIf cfg.enable {
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
  };
}
