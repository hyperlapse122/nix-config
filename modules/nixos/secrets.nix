{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.cliAuth;
  available = cfg.sopsFile != null;
  publisher = pkgs.writeScriptBin "publish-cli-auth" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile ../../scripts/publish-cli-auth}
  '';
  publishCommand = lib.escapeShellArgs [
    "${pkgs.util-linux}/bin/runuser"
    "-u"
    "h82"
    "--"
    "${publisher}/bin/publish-cli-auth"
    "--source"
    "/run/secrets/cli-auth"
    "--home"
    "/home/h82"
    "--github-user"
    cfg.githubUser
    "--gitlab-user"
    cfg.gitlabUser
    "--jpi-user"
    cfg.jpiUser
  ];
in
{
  options.my.cliAuth = {
    enable = lib.mkEnableOption "CLI authentication publication during activation";
    sopsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = if builtins.pathExists ../../secrets/tokens.yaml then ../../secrets/tokens.yaml else null;
      description = "Encrypted token YAML. Missing input fails at activation, not evaluation.";
    };
    ageKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/sops-nix/key.txt";
      description = "Runtime age identity restored once with the YubiKey.";
    };
    githubUser = lib.mkOption {
      type = lib.types.str;
      default = "hyperlapse122";
    };
    gitlabUser = lib.mkOption {
      type = lib.types.str;
      default = "hyperlapse";
    };
    jpiUser = lib.mkOption {
      type = lib.types.str;
      default = "hyperlapse";
    };
  };
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        systemd.services.sops-install-secrets = {
          wantedBy = [ "sysinit.target" ];
          requiredBy = [ "sysinit-reactivation.target" ];
          after = [
            "local-fs.target"
            "systemd-sysusers.service"
            "userborn.service"
          ];
          before = [
            "sysinit.target"
            "sysinit-reactivation.target"
          ];
          unitConfig = {
            DefaultDependencies = "no";
            RequiresMountsFor = [
              "/home/h82"
              cfg.ageKeyFile
            ];
          };
          serviceConfig = {
            Type = "oneshot";
            # A successful oneshot must be inactive so unchanged switches re-run it.
            RemainAfterExit = lib.mkForce false;
          };
        };
      }
      (lib.mkIf available {
        sops = {
          defaultSopsFile = cfg.sopsFile;
          age = {
            keyFile = cfg.ageKeyFile;
            generateKey = false;
            sshKeyPaths = [ ];
          };
          gnupg.sshKeyPaths = [ ];
          useSystemdActivation = true;
          secrets =
            lib.genAttrs
              (map (name: "cli-auth/${name}") [
                "github_token"
                "gitlab_token"
                "jpi_token"
              ])
              (name: {
                key = lib.removePrefix "cli-auth/" name;
                owner = "h82";
                mode = "0400";
              });
        };
        systemd.services.sops-install-secrets.serviceConfig.ExecStartPost = publishCommand;
      })
      (lib.mkIf (!available) {
        systemd.services.sops-install-secrets.serviceConfig.ExecStart =
          pkgs.writeShellScript "missing-cli-secrets" ''
            echo 'CLI authentication not provisioned: prepare secrets/tokens.yaml and restore the local age identity. See docs/provisioning.md.' >&2
            exit 1
          '';
      })
    ]
  );
}
