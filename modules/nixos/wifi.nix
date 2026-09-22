{
  config,
  lib,
  ...
}:
let
  cfg = config.my.wifi;
  available = cfg.sopsFile != null;
  upperLabels = map lib.toUpper cfg.networks;
in
{
  options.my.wifi = {
    sopsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = if builtins.pathExists ../../secrets/wifi.yaml then ../../secrets/wifi.yaml else null;
      description = "Encrypted Wi-Fi credential YAML. Missing input builds and activates with no Wi-Fi profiles.";
    };
    networks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "home"
        "office"
      ];
      description = ''
        Arbitrary local labels (never the literal SSID) for the networks
        declared in `secrets/wifi.yaml`. Each label needs matching
        `wifi.<label>.ssid` / `wifi.<label>.psk` entries in that file.
      '';
    };
  };
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = lib.length (lib.unique upperLabels) == lib.length upperLabels;
          message = "my.wifi.networks labels must be unique case-insensitively (each becomes an uppercased environment variable prefix)";
        }
      ];
    }
    (lib.mkIf available (
      let
        secretFor = label: field: {
          name = "wifi/${label}/${field}";
          value = {
            sopsFile = cfg.sopsFile;
            key = "wifi/${label}/${field}";
            owner = "root";
            mode = "0400";
          };
        };
      in
      {
        # Independent of modules/nixos/secrets.nix's own cliAuth.sopsFile state:
        # this module must decrypt secrets/wifi.yaml even when tokens.yaml is
        # absent, so it configures its own age key source rather than relying
        # on cliAuth's `mkIf available` block to have already set one.
        sops.age.keyFile = "/var/lib/sops-nix/key.txt";
        sops.age.generateKey = false;

        sops.secrets = lib.listToAttrs (
          lib.concatMap (label: [
            (secretFor label "ssid")
            (secretFor label "psk")
          ]) cfg.networks
        );

        sops.templates."wifi.env".content = lib.concatMapStrings (label: ''
          ${lib.toUpper label}_SSID=${config.sops.placeholder."wifi/${label}/ssid"}
          ${lib.toUpper label}_PSK=${config.sops.placeholder."wifi/${label}/psk"}
        '') cfg.networks;

        systemd.services."NetworkManager-ensure-profiles" = {
          after = [ "sops-install-secrets.service" ];
          wants = [ "sops-install-secrets.service" ];
        };

        networking.networkmanager.ensureProfiles = {
          environmentFiles = [ config.sops.templates."wifi.env".path ];
          profiles = lib.listToAttrs (
            map (label: {
              name = label;
              value = {
                connection = {
                  id = label;
                  type = "wifi";
                };
                wifi.ssid = "$" + lib.toUpper label + "_SSID";
                wifi-security = {
                  key-mgmt = "wpa-psk";
                  psk = "$" + lib.toUpper label + "_PSK";
                };
              };
            }) cfg.networks
          );
        };
      }
    ))
  ];
}
