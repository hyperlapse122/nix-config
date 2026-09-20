{
  description = "ThinkPad X1 Carbon Gen 11 NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
    in {
      nixosConfigurations = let
        mkHost = bootstrap: nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            inputs.disko.nixosModules.disko
            inputs.home-manager.nixosModules.home-manager
            inputs.sops-nix.nixosModules.sops
            inputs.lanzaboote.nixosModules.lanzaboote
            ./hosts/ThinkPad-X1-Carbon-Gen-11
            {
              my.bootstrap = bootstrap;
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.h82 = import ./home/h82;
            }
          ];
        };
      in {
        ThinkPad-X1-Carbon-Gen-11 = mkHost false;
        ThinkPad-X1-Carbon-Gen-11-bootstrap = mkHost true;
      };
      packages.${system}.disko = inputs.disko.packages.${system}.disko;
      checks.${system}.boot-layout = import ./tests/boot-layout.nix { inherit pkgs inputs; };
      formatter.${system} = pkgs.nixfmt;
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [ age sops gnupg git nixfmt shellcheck python3 ];
      };
    };
}
