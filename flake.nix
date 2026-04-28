{
  description = "H82's NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    # nixos-unstable: VS Code / Zed / 1Password 등 빠른 업데이트가 필요한 패키지에 사용
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # home-manager: master(unstable) 사용 - programs.opencode 등 최신 모듈 필요
    # useGlobalPkgs = true 이므로 모듈 내부 pkgs 는 호스트의 stable nixpkgs 그대로 사용됨
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
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
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, plasma-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      # nixos-unstable pkgs 인스턴스. allowUnfree 는 별도 인스턴스라 여기서 직접 켜줌
      # (호스트의 nixpkgs.config.allowUnfree 는 stable 채널 한정이라 여기까지 전파되지 않는다)
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      nixosConfigurations = {
        jpi-vmware = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs pkgs-unstable; };
          modules = [
            ./hosts/jpi-vmware
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.users.h82 = import ./home/h82.nix;
              home-manager.extraSpecialArgs = { inherit inputs pkgs-unstable; };
              home-manager.sharedModules = [ plasma-manager.homeModules.plasma-manager ];
            }
          ];
        };
      };
    };
}
