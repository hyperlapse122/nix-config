{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.system.programs.nix-index;
in
{
  options.my.system.programs.nix-index = {
    enable = lib.mkEnableOption "nix-index (nix-locate command + zsh/bash command-not-found integration)";
  };

  config = lib.mkIf cfg.enable {
    # Install the nix-index package + shell integration (zsh/bash sources command-not-found.sh).
    # `nix-locate <file>` searches which package in the store owns a file, and on a missing-command
    # input it suggests which nixpkgs package contains it.
    programs.nix-index.enable = true;

    # Mutually exclusive with nixpkgs's legacy command-not-found (the programs.sqlite-based suggester).
    # nixos/modules/programs/nix-index.nix asserts this, so we explicitly disable it.
    # nix-index is faster and indexes packages outside the channel as well, so it's the preferred replacement.
    programs.command-not-found.enable = false;

    # CAVEAT: The index DB is NOT auto-generated or auto-refreshed.
    # After enabling, run `nix-index` once in the user shell to populate ~/.cache/nix-index;
    # only then will nix-locate and command-not-found suggestions function.
  };
}
