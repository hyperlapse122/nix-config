{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.dev.opencode;

  # opencode itself: a bunx wrapper (pulls the latest opencode-ai from npm every invocation).
  # NOTE: Setting programs.opencode.package = null makes the master home-manager module fail evaluation
  #       on warnings — lib.versionAtLeast null "1.2.15" throws (a known bug in modules/programs/opencode.nix).
  #       Passing the wrapper as the package directly makes lib.getVersion return "" → versionAtLeast "" "..." = false
  #       → the deprecated TUI keys warning evaluation also passes safely + home.packages is registered automatically by the HM module.
  opencodeWrapper = pkgs.writeShellApplication {
    name = "opencode";
    text = ''
      exec ${pkgs.bun}/bin/bunx opencode-ai@latest "$@"
    '';
  };

  # Read opencode.json verbatim and use it as the settings.
  # `$schema` is auto-injected by home-manager's programs.opencode module, so strip it.
  opencodeSettings = lib.removeAttrs (builtins.fromJSON (builtins.readFile ./opencode.json)) [
    "$schema"
  ];
in
{
  options.my.dev.opencode = {
    enable = lib.mkEnableOption "opencode CLI (bunx wrapper) + the full set of config files";
  };

  config = lib.mkIf cfg.enable {
    # Manage settings / context / commands through the programs.opencode module (home-manager master).
    # Pass the bunx wrapper directly as `package` — the HM module registers it in home.packages automatically.
    programs.opencode = {
      enable = true;
      package = opencodeWrapper;
      settings = opencodeSettings;
      context = ./context.md;
      commands = ./commands;
    };

    # bun itself, on which the bunx wrapper depends
    home.packages = [
      pkgs.bun
    ];

    # oh-my-openagent plugin config (an external plugin file that programs.opencode does not handle)
    xdg.configFile."opencode/oh-my-openagent.jsonc".source = ./oh-my-openagent.jsonc;
  };
}
