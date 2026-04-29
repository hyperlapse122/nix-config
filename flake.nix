{
  description = "H82's NixOS configurations";

  inputs = {
    # 단일 채널 정책: 모든 패키지를 nixos-unstable 에서 가져온다.
    # Arch Linux 처럼 rolling release 감각을 유지하려는 의도 — stable 채널을 따로 두지 않는다.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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

    # Playwright 전용 flake — pietdevries94/playwright-web-flake.
    # nixpkgs 의 playwright 버전이 lag 되거나 npm `@playwright/test` 와 어긋날 때
    # 이 flake 의 태그(예: 1.x.y)를 핀해 동기화한다.
    # `inputs.nixpkgs.follows = "nixpkgs"` 로 단일 채널 정책 유지 — driver.nix 가 우리 nixpkgs 로 callPackage 됨.
    playwright = {
      url = "github:pietdevries94/playwright-web-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
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
      };
    };
}
