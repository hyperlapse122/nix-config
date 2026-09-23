{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.tailscale;
  available = cfg.sopsFile != null;
  tailscalePkg = config.services.tailscale.package;
  routeLabels = [
    "lan_10"
    "lan_1"
    "wp_jpi_co_kr"
  ];

  dedupScript = pkgs.writeShellScript "tailscale-dedup-device" (
    builtins.readFile ../../../scripts/tailscale-dedup-device
  );
in
{
  options.my.tailscale = {
    enable = lib.mkEnableOption "Tailscale mesh networking with SSH and unattended re-registration";
    advertiseRoutes = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Advertise this host's subnet routes to the tailnet. Only one host in the tailnet should set this.";
    };
    sopsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default =
        if builtins.pathExists ../../../secrets/tailscale.yaml then
          ../../../secrets/tailscale.yaml
        else
          null;
      description = "Encrypted Tailscale credentials YAML. Missing input builds with tailscaled running but unauthenticated.";
    };
    apiBase = lib.mkOption {
      type = lib.types.str;
      default = "https://api.tailscale.com";
      description = "Tailscale API base URL. Overridden in VM tests to point at a mock server instead of the real API.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        services.tailscale = {
          enable = true;
          openFirewall = true;
          extraUpFlags = [
            "--ssh"
            "--accept-routes"
          ];
          useRoutingFeatures = if cfg.advertiseRoutes then "server" else "none";
        };
      }
      (lib.mkIf available {
        # Independent of modules/nixos/system/secrets.nix's own cliAuth.sopsFile state:
        # this module must decrypt secrets/tailscale.yaml even when tokens.yaml is
        # absent, so it configures its own age key source rather than relying
        # on cliAuth's `mkIf available` block to have already set one.
        sops.age.keyFile = config.my.cliAuth.ageKeyFile;
        sops.age.generateKey = false;

        sops.secrets =
          lib.genAttrs
            (
              [
                "tailscale/auth_key"
                "tailscale/api_token"
              ]
              ++ lib.optionals cfg.advertiseRoutes (map (r: "tailscale/routes/${r}") routeLabels)
            )
            (name: {
              sopsFile = cfg.sopsFile;
              owner = "root";
              mode = "0400";
            });

        # Split so tailscale-advertise-routes (which never calls the API)
        # isn't hand the bearer token it has no use for.
        sops.templates = lib.mkMerge [
          {
            "tailscale-api.env".content = ''
              TAILSCALE_API_TOKEN=${config.sops.placeholder."tailscale/api_token"}
              TAILSCALE_API_BASE=${cfg.apiBase}
            '';
          }
          (lib.mkIf cfg.advertiseRoutes {
            "tailscale-routes.env".content = ''
              TAILSCALE_ROUTES=${
                lib.concatMapStringsSep "," (r: config.sops.placeholder."tailscale/routes/${r}") routeLabels
              }
            '';
          })
        ];

        services.tailscale.authKeyFile = config.sops.secrets."tailscale/auth_key".path;

        # Runs after tailscaled-autoconnect settles (that unit is Type=notify
        # and only starts once BackendState reaches Running), so this unit
        # never races tailscaled's control socket and never needs its own
        # BackendState poll. It compares this host's *current* device ID
        # against every other device sharing its hostname and deletes only
        # the mismatches -- safe on an ordinary rebuild (nothing else shares
        # the hostname), safe across key-expiry reauth (the same device ID
        # reauthenticates, so nothing matches), and correct on a genuine
        # reinstall (a stale device with a different ID is the only match).
        systemd.services.tailscale-dedup-device = {
          description = "Remove stale tailnet devices sharing this host's name";
          after = [ "tailscaled-autoconnect.service" ];
          wants = [ "tailscaled-autoconnect.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            EnvironmentFile = config.sops.templates."tailscale-api.env".path;
            Environment = "SELF_HOSTNAME=${config.networking.hostName}";
            ExecStart = dedupScript;
          };
          path = [
            tailscalePkg
            pkgs.jq
            pkgs.curl
          ];
        };

        systemd.services.tailscale-advertise-routes = lib.mkIf cfg.advertiseRoutes {
          description = "Advertise this host's configured Tailscale subnet routes";
          after = [ "tailscaled-autoconnect.service" ];
          wants = [ "tailscaled-autoconnect.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            EnvironmentFile = config.sops.templates."tailscale-routes.env".path;
          };
          path = [ tailscalePkg ];
          # tailscale set --advertise-routes is idempotent, so this needs no
          # state gate: safe to run on every activation.
          script = ''
            tailscale set --advertise-routes="$TAILSCALE_ROUTES"
          '';
        };
      })
    ]
  );
}
