{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.system.users.h82;
in
{
  options.my.system.users.h82 = {
    enable = lib.mkEnableOption "h82 user account (shell: zsh)";
  };

  config = lib.mkIf cfg.enable {
    users.users.h82 = {
      isNormalUser = true;
      description = "H82";
      extraGroups = [
        "wheel"
        "networkmanager"
        "docker"
      ];
      shell = pkgs.zsh;
    };

    # h82's login shell is zsh, so we must also enable it at the system level.
    # (Avoiding AGENTS.md's "Tightly coupling two modules" anti-pattern: bundling zsh with h82 in
    #  the same module is fine because both belong to the single concern "set up the h82 account".)
    programs.zsh.enable = true;
  };
}
