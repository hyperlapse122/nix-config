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

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      nixosConfigurations =
        let
          mkHost =
            bootstrap:
            nixpkgs.lib.nixosSystem {
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
        in
        {
          ThinkPad-X1-Carbon-Gen-11 = mkHost false;
          ThinkPad-X1-Carbon-Gen-11-bootstrap = mkHost true;
        };
      packages.${system}.disko = inputs.disko.packages.${system}.disko;
      checks.${system} = {
        pinentry-card =
          pkgs.runCommand "pinentry-card-tests"
            {
              nativeBuildInputs = [
                pkgs.python3
                pkgs.bash
              ];
            }
            ''
              cp ${./scripts/pinentry-card} ./pinentry-card
              bash ${./tests/pinentry-card.sh} ./pinentry-card
              touch $out
            '';
        restore-age-identity =
          pkgs.runCommand "restore-age-identity-tests" { nativeBuildInputs = [ pkgs.python3 ]; }
            ''
              export PYTHONDONTWRITEBYTECODE=1
              mkdir -p scripts tests
              cp ${./scripts/restore-age-identity} scripts/restore-age-identity
              cp ${./tests/restore-age-identity.py} tests/restore-age-identity.py
              python tests/restore-age-identity.py
              touch $out
            '';
        boot-layout = import ./tests/boot-layout.nix { inherit pkgs inputs; };
        auth-provisioning = import ./tests/auth-provisioning.nix { inherit pkgs inputs; };
        publish-cli-auth =
          pkgs.runCommand "publish-cli-auth-tests" { nativeBuildInputs = [ pkgs.python3 ]; }
            ''
              export PYTHONDONTWRITEBYTECODE=1
              mkdir -p scripts tests
              cp ${./scripts/publish-cli-auth} scripts/publish-cli-auth
              cp ${./tests/test_publish_cli_auth.py} tests/test_publish_cli_auth.py
              python tests/test_publish_cli_auth.py
              touch $out
            '';
        zsh-prezto =
          let
            host = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11;
            zpreztorc = host.config.home-manager.users.h82.home.file."./.zpreztorc".source;
            zshenv = host.config.home-manager.users.h82.home.file."./.zshenv".source;
            zshrc = host.config.home-manager.users.h82.home.file."./.zshrc".source;
          in
          pkgs.runCommand "zsh-prezto-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
            grep -q "zstyle ':prezto:load' pmodule" ${zpreztorc}
            grep -q "runcoms/zshenv" ${zshenv}
            grep -q "runcoms/zshrc" ${zshrc}
            touch $out
          '';
      };
      formatter.${system} = pkgs.nixfmt-tree;
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          age
          sops
          gnupg
          git
          nixfmt
          libsecret
          shellcheck
          python3
        ];
      };
    };
}
