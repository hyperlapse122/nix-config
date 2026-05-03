{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.obsidian;
  vaultRelativePath = "Documents/Obsidian";
  vaultPath = "${config.home.homeDirectory}/Documents/Obsidian";
  obsidianGitVersion = "2.38.2";
  obsidianGitPluginId = "obsidian-git";
  obsidianGitPluginPath = "${vaultRelativePath}/.obsidian/plugins/${obsidianGitPluginId}";
  obsidianGitSources = {
    mainJs = pkgs.fetchurl {
      url = "https://github.com/Vinzent03/obsidian-git/releases/download/${obsidianGitVersion}/main.js";
      hash = "sha256-0S1TqaqUWuck0fiY26I/D7y2op1GWVzdLzaJt8c0BhQ=";
    };
    manifest = pkgs.fetchurl {
      url = "https://github.com/Vinzent03/obsidian-git/releases/download/${obsidianGitVersion}/manifest.json";
      hash = "sha256-qe6sg8xxvJ6wa1h4L01U0UB4TvR4mdS9xz6Q0ajVJG0=";
    };
    styles = pkgs.fetchurl {
      url = "https://github.com/Vinzent03/obsidian-git/releases/download/${obsidianGitVersion}/styles.css";
      hash = "sha256-CTj/FgBO4fM2JyiZHijc4LuTe+USRtoIKWOAA1N76q4=";
    };
  };
in
{
  options.my.obsidian = {
    enable = lib.mkEnableOption "Obsidian";
  };

  config = lib.mkIf cfg.enable {
    programs.obsidian = {
      enable = true;
      package = pkgs.obsidian;
      cli.enable = true;
    };

    home.activation.createObsidianVault = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p ${lib.escapeShellArg vaultPath}
    '';

    xdg.configFile."obsidian/obsidian.json" = {
      force = true;
      text = builtins.toJSON {
        vaults.default = {
          path = vaultPath;
          ts = 0;
          open = true;
        };
      };
    };

    home.file = {
      "${vaultRelativePath}/.obsidian/community-plugins.json" = {
        force = true;
        text = builtins.toJSON [
          obsidianGitPluginId
        ];
      };
      "${obsidianGitPluginPath}/main.js" = {
        force = true;
        source = obsidianGitSources.mainJs;
      };
      "${obsidianGitPluginPath}/manifest.json" = {
        force = true;
        source = obsidianGitSources.manifest;
      };
      "${obsidianGitPluginPath}/styles.css" = {
        force = true;
        source = obsidianGitSources.styles;
      };
    };
  };
}
