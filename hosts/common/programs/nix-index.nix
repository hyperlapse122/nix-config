{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.my.system.programs.nix-index;
in
{
  imports = [
    inputs.nix-index-database.nixosModules.default
  ];

  options.my.system.programs.nix-index = {
    enable = lib.mkEnableOption "nix-index (nix-locate command + zsh/bash command-not-found integration)";
  };

  config = lib.mkMerge [
    {
      programs.nix-index-database.enable = cfg.enable;
    }

    (lib.mkIf cfg.enable {
      # Install nix-index with the pre-generated nixos-unstable database.
      # `nix-locate <file>` searches which package in the store owns a file, and on missing-command
      # input it suggests which nixpkgs package contains it.
      programs.nix-index.enable = true;

      # Mutually exclusive with nixpkgs's legacy command-not-found (the programs.sqlite-based suggester).
      # nixos/modules/programs/nix-index.nix asserts this, so we explicitly disable it.
      # nix-index is faster and indexes packages outside the channel as well, so it's the preferred replacement.
      programs.command-not-found.enable = false;
    })
  ];
}
