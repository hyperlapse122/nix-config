{ config, lib, pkgs, ... }:
let
  cfg = config.my.ssh;
  # 1Password SSH agent UNIX socket (Linux-only path).
  # Per the root AGENTS.md "NixOS only (no nix-darwin / WSL planned)" policy, the Wiki's
  # Darwin branch (`Library/Group Containers/.../agent.sock`) is intentionally omitted.
  onePassPath = "${config.home.homeDirectory}/.1password/agent.sock";
in {
  options.my.ssh = {
    enable = lib.mkEnableOption "SSH Client configuration";
  };

  config = lib.mkIf cfg.enable {
    # Starting with home-manager 25.11, programs.ssh's implicit defaults were deprecated.
    # We disable them with `enableDefaultConfig = false` and re-declare the same values explicitly under matchBlocks."*".
    # Source: nix-community/home-manager release-25.11 modules/programs/ssh.nix
    #
    # Behavior preconditions:
    #   1. The host has my.system.programs._1password enabled.
    #   2. 1Password app: Settings → Developer → "Use the SSH agent" enabled.
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks."*" = {
        # The actual purpose of this module — wire up the 1Password agent.
        identityAgent = onePassPath;

        # Below are the values home-manager used to inject automatically when enableDefaultConfig=true.
        # In 25.11+, they must be set explicitly to preserve identical behavior.
        forwardAgent = false;
        addKeysToAgent = "no";
        compression = false;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "no";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";
      };
    };
  };
}
