{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.system.laptop-input;
in
{
  options.my.system.laptop-input = {
    enable = lib.mkEnableOption "Laptop input configuration (keyd key remapping + libinput palm rejection tuning)";
  };

  config = lib.mkIf cfg.enable {
    # keyd — system-level key-remapping daemon.
    # Reference: https://wiki.nixos.org/wiki/Keyd
    #
    # We use `settings` rather than `extraConfig` because, when a flat attrset can express the same config inside Nix,
    # it is more typing-/merge-safe at evaluation time than an extraConfig string.
    services.keyd = {
      enable = true;
      keyboards.default = {
        # Wildcard — match every keyboard.
        # The "Disabling Copilot key" Wiki section recommends pinning explicit IDs to avoid palm-rejection
        # issues, but the environment.etc."libinput/local-overrides.quirks" rule below addresses the same
        # problem, so the wildcard is fine.
        ids = [ "*" ];
        settings = {
          # Default layer
          main = {
            # CapsLock → Hangeul (Korean/English toggle). Same as dotfiles/etc/keyd/default.conf.
            capslock = "hangeul";
            # Disable the Copilot key — the useless Copilot key on newer laptops is mapped to a meta layer.
            # Catches the standard sequence (leftshift+leftmeta+f23) confirmed via `sudo keyd monitor`.
            # Reference: https://wiki.nixos.org/wiki/Keyd#Disabling_Copilot_key
            "leftshift+leftmeta+f23" = "layer(meta)";
          };
          # Ctrl layer — while Ctrl is held, CapsLock acts as the real CapsLock.
          # Bypasses main's capslock=hangeul mapping so that a real CapsLock is still reachable when needed.
          control = {
            capslock = "capslock";
          };
        };
      };
    };

    # libinput palm-rejection tuning.
    # The virtual keyboard keyd creates must be classified as an internal keyboard for libinput palm
    # rejection to engage during typing. Without this, the touchpad stays active during keystrokes,
    # producing typos and stray clicks.
    # Reference: https://github.com/rvaiya/keyd/issues/723
    environment.etc."libinput/local-overrides.quirks".text = ''
      [Serial Keyboards]
      MatchUdevType=keyboard
      MatchName=keyd virtual keyboard
      AttrKeyboardIntegration=internal
    '';
  };
}
