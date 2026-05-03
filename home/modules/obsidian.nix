{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.obsidian;
  vaultPath = "${config.home.homeDirectory}/Documents/Obsidian";
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

    xdg.configFile."obsidian/obsidian.json".text = builtins.toJSON {
      vaults.default = {
        path = vaultPath;
        ts = 0;
        open = true;
      };
    };
  };
}
