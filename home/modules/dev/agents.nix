{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.dev.agents;
in
{
  options.my.dev.agents = {
    enable = lib.mkEnableOption "agent skills + shared commands directory (~/.agents → ~/nix-config/agents live symlink)";
  };

  config = lib.mkIf cfg.enable {
    # Out-of-store (live) symlink: ~/.agents → ~/nix-config/agents.
    # OpenCode's oh-my-openagent plugin writes to skills/ and .skill-lock.json at runtime,
    # so a Nix-store path (read-only) would break with EROFS.
    # mkOutOfStoreSymlink exposes the repo path as-is → skill installs / lockfile updates work,
    # and file changes are reflected immediately without a rebuild.
    home.file.".agents".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/agents";
  };
}
