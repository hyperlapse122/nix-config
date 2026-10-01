{
  config,
  lib,
  pkgs,
  ...
}:
let
  production = config.my.kind == "nixos" && !config.my.bootstrap;
  publicKey = config.my.desktopSSH.publicKey;
  helper = import ../../../packages/desktop-ssh-session-active.nix { inherit pkgs; };
  tool = import ../../../packages/desktop-ssh.nix { inherit pkgs; };
in
lib.mkMerge [
  # Bootstrap keeps the existing agent until host credentials are provisioned.
  (lib.mkIf (config.my.kind == "nixos") {
    home.file.".ssh/config".text =
      if production then
        ''
          Host *
            IdentityFile ${publicKey}
            IdentityAgent /run/user/%i/desktop-ssh/agent.sock
        ''
      else
        ''
          Host *
            IdentityAgent ~/.1password/agent.sock
        '';

    home.file.".config/1Password/ssh/agent.toml".source = ../../../config/1password/agent.toml;
  })

  (lib.mkIf production {
    home.packages = [ (lib.hiPrio tool) ];
    home.file.".config/desktop-ssh/config.json".text = builtins.toJSON {
      public_key = "${publicKey}";
      key_file = "${config.my.user.home}/.ssh/id_ed25519_nix_config";
      fallback_socket = "${config.my.user.home}/.1password/agent.sock";
    };
    systemd.user.services.desktop-ssh-agent = {
      Unit = {
        Description = "Desktop session SSH primary agent";
        After = [ "graphical-session.target" ];
        BindsTo = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecCondition = lib.escapeShellArgs [
          "${helper}/bin/desktop-ssh-session-active"
          config.my.user.name
        ];
        ExecStart = lib.escapeShellArgs [
          "${tool}/bin/desktop-ssh"
          "agent"
          "--config"
          "${config.my.user.home}/.config/desktop-ssh/config.json"
        ];
        ExecStopPost = "${pkgs.systemd}/bin/systemctl --no-ask-password stop desktop-ssh-provision.service";
        RuntimeDirectory = "desktop-ssh";
        RuntimeDirectoryMode = "0700";
        LimitCORE = 0;
        KillMode = "control-group";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  })

  # A non-NixOS host has no desktop and so no 1Password agent: it uses its own
  # key, which production activation publishes (non-nixos-secrets.nix).
  (lib.mkIf (config.my.kind == "linux") {
    home.file.".ssh/config".text = ''
      Host *
        IdentityFile ${config.my.secrets.sshKey}
    '';
  })
]
