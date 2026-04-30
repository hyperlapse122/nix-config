{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.keyboard.kr106;
in {
  options.my.system.keyboard.kr106 = {
    enable = lib.mkEnableOption "Korean 106-key keyboard layout for X11/Wayland (xkb kr/kr106)";
  };

  config = lib.mkIf cfg.enable {
    # X11 / Wayland keyboard layout — applies to both display servers because xkbcommon
    # (which KWin/Wayland reads) consumes the same `services.xserver.xkb.*` settings.
    # Variant `kr106` is the standard Korean physical keyboard with the extra Hangul and Hanja
    # keys; KDE Plasma 6 picks this up as the default layout when no per-user override exists
    # in kxkbrc.
    # NOTE: `console.keyMap` is intentionally left at the NixOS default (us). The TTY is rarely
    #       used on this setup and the default avoids the extra `kr` keymap derivation in the
    #       system closure.
    services.xserver.xkb = {
      layout = "kr";
      variant = "kr106";
    };
  };
}
