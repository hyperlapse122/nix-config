{
  description = "H82's NixOS configurations";

  nixConfig = {
    extra-substituters = [ "https://codex-cli.cachix.org" ];
    extra-trusted-public-keys = [
      "codex-cli.cachix.org-1:1Br3H1hHoRYG22n//cGKJOk3cQXgYobUel6O8DgSing="
    ];
  };

  inputs = {
    # Single-channel policy: every package is pulled from nixos-unstable.
    # The intent is to feel like Arch Linux's rolling release — no separate stable channel.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    codex-cli-nix = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware";

    # Dedicated Playwright flake — pietdevries94/playwright-web-flake.
    # When nixpkgs's playwright version lags or drifts from npm `@playwright/test`,
    # pin a tag of this flake (e.g. 1.x.y) to keep them in sync.
    # `inputs.nixpkgs.follows = "nixpkgs"` keeps the single-channel policy — driver.nix is callPackage'd against our nixpkgs.
    playwright = {
      url = "github:pietdevries94/playwright-web-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      plasma-manager,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations = {
        jpi-vmware = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/jpi-vmware
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.users.h82 = import ./home/h82.nix;
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.sharedModules = [ plasma-manager.homeModules.plasma-manager ];
            }
          ];
        };
        h82-t14-gen2 = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/h82-t14-gen2
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.users.h82 = import ./home/h82.nix;
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.sharedModules = [ plasma-manager.homeModules.plasma-manager ];
            }
          ];
        };
      };
    };
}
