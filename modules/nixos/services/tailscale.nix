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

  # Reads the Authorization header from stdin via `curl -K -` rather than a
  # CLI argument, so the bearer token never appears in this unit's
  # /proc/<pid>/cmdline (readable by any local user).
  authedCurl = ''printf 'header = "Authorization: Bearer %s"\n' "$TAILSCALE_API_TOKEN" | curl -sS --fail -K -'';

  # A plain derivation (rather than the systemd module's inline `script`
  # sugar) so tests/tailscale-provisioning.nix can invoke this exact script
  # directly -- with a stubbed `tailscale` on PATH -- without needing a real
  # authenticated tailnet connection inside an isolated VM test.
  dedupScript = pkgs.writeShellScript "tailscale-dedup-device" ''
    set -uo pipefail

    self_hostname="${config.networking.hostName}"

    if ! status_json="$(tailscale status --json)"; then
      echo "tailscale-dedup-device: could not read tailscale status; skipping" >&2
      exit 0
    fi
    device_id_self="$(printf '%s' "$status_json" | jq -r '.Self.ID')"
    if [ -z "$device_id_self" ] || [ "$device_id_self" = "null" ]; then
      # Not authenticated yet (e.g. tailscaled-autoconnect hasn't reached
      # Running by the time systemd's ordering let this unit start). Without
      # a real self ID every other device would look like a stranger, so
      # deleting anything here risks removing a still-live registration.
      echo "tailscale-dedup-device: no self device ID yet; skipping" >&2
      exit 0
    fi

    if ! devices_json="$(${authedCurl} "$TAILSCALE_API_BASE/api/v2/tailnet/-/devices")"; then
      echo "tailscale-dedup-device: Tailscale API request failed; skipping cleanup this run" >&2
      exit 0
    fi

    stale_ids="$(printf '%s' "$devices_json" | jq -r --arg host "$self_hostname" --arg self "$device_id_self" \
      '.devices[] | select((.hostname | ascii_downcase) == ($host | ascii_downcase)) | select(.id != $self) | .id')"

    if [ -z "$stale_ids" ]; then
      echo "tailscale-dedup-device: no stale devices for $self_hostname"
      exit 0
    fi

    printf '%s\n' "$stale_ids" | while IFS= read -r stale_id; do
      [ -n "$stale_id" ] || continue
      if ${authedCurl} -X DELETE "$TAILSCALE_API_BASE/api/v2/device/$stale_id"; then
        echo "tailscale-dedup-device: removed stale device $stale_id"
      else
        echo "tailscale-dedup-device: failed to remove stale device $stale_id" >&2
      fi
    done
  '';
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
    dedupScriptPath = lib.mkOption {
      type = lib.types.path;
      internal = true;
      readOnly = true;
      default = dedupScript;
      description = "Store path of the dedup unit's script, exposed only so tests/tailscale-provisioning.nix can invoke it directly.";
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
              ++ lib.optionals cfg.advertiseRoutes [
                "tailscale/routes/lan_10"
                "tailscale/routes/lan_1"
                "tailscale/routes/wp_jpi_co_kr"
              ]
            )
            (name: {
              sopsFile = cfg.sopsFile;
              owner = "root";
              mode = "0400";
            });

        sops.templates."tailscale.env".content = ''
          TAILSCALE_API_TOKEN=${config.sops.placeholder."tailscale/api_token"}
          TAILSCALE_API_BASE=${cfg.apiBase}
        ''
        + lib.optionalString cfg.advertiseRoutes ''
          TAILSCALE_ROUTES=${
            lib.concatStringsSep "," [
              config.sops.placeholder."tailscale/routes/lan_10"
              config.sops.placeholder."tailscale/routes/lan_1"
              config.sops.placeholder."tailscale/routes/wp_jpi_co_kr"
            ]
          }
        '';

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
            EnvironmentFile = config.sops.templates."tailscale.env".path;
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
            EnvironmentFile = config.sops.templates."tailscale.env".path;
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
