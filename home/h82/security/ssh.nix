{ config, lib, ... }:
lib.mkMerge [
  # NixOS hosts take SSH keys from the 1Password desktop app's agent.
  (lib.mkIf (config.my.kind == "nixos") {
    home.file.".ssh/config".text = ''
      Host *
        IdentityAgent ~/.1password/agent.sock
    '';

    home.file.".config/1Password/ssh/agent.toml".source = ../../../config/1password/agent.toml;
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
