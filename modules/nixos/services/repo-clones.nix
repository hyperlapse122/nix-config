{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.repoClones;
  available = cfg.sopsFile != null;
  repoClones = import ../../../packages/repo-clones.nix { inherit pkgs; };
  listSecret = "repo-clones/list";
in
{
  options.my.repoClones = {
    enable = lib.mkEnableOption "cloning the declared repositories into ~/src on every switch";
    sopsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default =
        if builtins.pathExists ../../../secrets/repos.yaml then ../../../secrets/repos.yaml else null;
      description = "Encrypted repository list YAML. Missing input builds with the repo-clones command installed but no clone unit.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        # The manual retry path exists even before the list is provisioned.
        environment.systemPackages = [ repoClones ];
      }
      (lib.mkIf available {
        # Independent of modules/nixos/system/secrets.nix's own cliAuth.sopsFile
        # state, like the Tailscale module: decrypt with the same age key even
        # when tokens.yaml is absent.
        sops.age.keyFile = config.my.cliAuth.ageKeyFile;
        sops.age.generateKey = false;

        sops.secrets.${listSecret} = {
          sopsFile = cfg.sopsFile;
          key = "repos";
          owner = "h82";
          mode = "0400";
        };

        # Without RemainAfterExit the oneshot is inactive between runs, so
        # every switch starts it again through multi-user.target, even when
        # only the encrypted list changed and the Home Manager generation did
        # not. The helper exits 0 on per-entry failures, so a clone that fails
        # never fails the switch.
        systemd.services.repo-clones = {
          description = "Clone declared repositories missing from ~/src";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [
            "network-online.target"
            "sops-install-secrets.service"
            "home-manager-h82.service"
          ];
          serviceConfig = {
            Type = "oneshot";
            User = "h82";
            ExecStart = "${lib.getExe repoClones} ${config.sops.secrets.${listSecret}.path}";
          };
        };
      })
    ]
  );
}
