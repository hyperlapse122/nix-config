{
  config,
  lib,
  ...
}:
let
  cfg = config.my.keyd;
in
{
  options.my.keyd = {
    ids = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "0001:0001" ];
      description = "Keyboards the remap applies to. The default is the internal AT keyboard, narrowing the upstream wildcard so an external keyboard keeps stock behaviour.";
    };
    copilotKey = lib.mkEnableOption "the Copilot key correction, for hosts that ship a Copilot key in place of the right Meta key";
  };

  config = {
    services.keyd = {
      enable = true;
      keyboards.default = {
        inherit (cfg) ids;
        settings = {
          control.capslock = "capslock";
          main = {
            capslock = "hangeul";
          }
          // lib.optionalAttrs cfg.copilotKey {
            "leftshift+leftmeta+f23" = "layer(meta)";
          };
        };
      };
    };

    systemd.services.keyd = {
      # Ordering only guarantees keyd was spawned before the greeter, not that
      # it already grabbed the keyboard; it narrows the race rather than closing it.
      before = [ "display-manager.service" ];
      # Backs off the upstream Restart=always so a panic sequence buys a usable
      # window instead of 100ms. Note this also puts the unit out of reach of
      # systemd default start-rate limiting (5 starts / 10s), so a persistently
      # failing keyd now retries indefinitely instead of settling in failed.
      serviceConfig.RestartSec = "5s";
    };

    # keyd check, monitor and reload are needed for hardware verification, and the
    # upstream module sets only ExecStart.
    environment.systemPackages = [ config.services.keyd.package ];

    # keyd hides the real keyboard behind a virtual one. Without this quirk libinput
    # stops treating that keyboard as built in, which breaks its pairing with the
    # internal touchpad for disable-while-typing.
    environment.etc."libinput/local-overrides.quirks".text = ''
      [Serial Keyboards]
      MatchUdevType=keyboard
      MatchName=keyd virtual keyboard
      AttrKeyboardIntegration=internal
    '';
  };
}
