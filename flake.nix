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
        keyd-remap = import ./tests/keyd-remap.nix { inherit pkgs self; };
        claude = import ./tests/claude.nix { inherit pkgs self; };
        claude-settings =
          let
            packaged = (import ./packages/claude-tools.nix { inherit pkgs; }).claudeSettings;
          in
          pkgs.runCommand "claude-settings-tests" { nativeBuildInputs = [ pkgs.python3 ]; } ''
            export PYTHONDONTWRITEBYTECODE=1
            mkdir -p scripts tests
            cp ${./scripts/claude-settings} scripts/claude-settings
            cp ${./tests/test_claude_settings.py} tests/test_claude_settings.py
            python tests/test_claude_settings.py

            # Activation runs the packaged binary, not this source copy, and its
            # unit's PATH carries no python3. Exercise the built file so a lost
            # +x bit or an unpatched `#!/usr/bin/env python3` fails here rather
            # than on the laptop.
            interpreter=$(head -1 ${packaged}/bin/claude-settings)
            case "$interpreter" in
              '#!'/nix/store/*) ;;
              *)
                echo "packaged merger must carry a store interpreter, got: $interpreter" >&2
                exit 1
                ;;
            esac

            mkdir -p home/.claude
            printf '{"model":"sonnet","numStartups":41,"retired":"gone"}\n' > home/.claude/settings.json
            printf '{"set":{"model":"opus[1m]"},"remove":["retired"]}\n' > declared.json
            env -i ${packaged}/bin/claude-settings \
              --settings "$PWD/home/.claude/settings.json" --declared "$PWD/declared.json"
            ${pkgs.python3}/bin/python3 - <<'PY'
            import json
            merged = json.load(open('home/.claude/settings.json'))
            assert merged['model'] == 'opus[1m]', merged
            assert merged['numStartups'] == 41, merged
            assert 'retired' not in merged, merged
            PY

            touch $out
          '';
        gemini = import ./tests/gemini.nix { inherit pkgs self; };
        nix-ld = import ./tests/nix-ld.nix { inherit pkgs self; };
        pam-fingerprint = import ./tests/pam-fingerprint.nix { inherit pkgs self; };
        enroll-fingerprint =
          let
            packaged = import ./packages/enroll-fingerprint.nix { inherit pkgs; };
          in
          pkgs.runCommand "enroll-fingerprint-tests"
            {
              nativeBuildInputs = [
                pkgs.bash
                pkgs.gnugrep
              ];
            }
            ''
              mkdir -p scripts tests
              cp ${./scripts/enroll-fingerprint} scripts/enroll-fingerprint
              cp ${./tests/enroll-fingerprint.sh} tests/enroll-fingerprint.sh
              chmod +x scripts/enroll-fingerprint
              patchShebangs scripts/enroll-fingerprint
              bash tests/enroll-fingerprint.sh scripts/enroll-fingerprint

              # The source test renders the @...@ constants itself, so it never
              # sees the built file. Activation runs the built one, where a lost
              # substitution would leave the script reaching a literal
              # '@PAMTESTER@' and the password gate would fail open-ended.
              if grep -qE '@[A-Z_]+@' ${packaged}/bin/enroll-fingerprint; then
                echo "packaged helper still carries an unsubstituted placeholder" >&2
                grep -nE '@[A-Z_]+@' ${packaged}/bin/enroll-fingerprint >&2
                exit 1
              fi
              interpreter=$(head -1 ${packaged}/bin/enroll-fingerprint)
              case "$interpreter" in
                '#!'/nix/store/*) ;;
                *)
                  echo "packaged helper must carry a store interpreter, got: $interpreter" >&2
                  exit 1
                  ;;
              esac

              touch $out
            '';
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
        docker-credential-sops =
          pkgs.runCommand "docker-credential-sops-tests" { nativeBuildInputs = [ pkgs.python3 ]; }
            ''
              export PYTHONDONTWRITEBYTECODE=1
              mkdir -p scripts tests
              cp ${./scripts/docker-credential-sops} scripts/docker-credential-sops
              cp ${./tests/test_docker_credential_sops.py} tests/test_docker_credential_sops.py
              python tests/test_docker_credential_sops.py
              touch $out
            '';
        podman-containers = import ./tests/podman-containers.nix { inherit pkgs self; };
        podman-registry-auth = import ./tests/podman-registry-auth.nix { inherit pkgs inputs; };
        zsh-prezto =
          let
            host = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11;
            zpreztorc = host.config.home-manager.users.h82.home.file.".config/zsh/.zpreztorc".source;
            zshenv = host.config.home-manager.users.h82.home.file.".config/zsh/.zshenv".source;
            zshrc = host.config.home-manager.users.h82.home.file.".config/zsh/.zshrc".source;
            dotzshenv = host.config.home-manager.users.h82.home.file.".zshenv".text;
          in
          pkgs.runCommand "zsh-prezto-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
            grep -q "zstyle ':prezto:load' pmodule" ${zpreztorc}
            grep -q "runcoms/zshenv" ${zshenv}
            grep -q "runcoms/zshrc" ${zshrc}
            echo "${dotzshenv}" | grep -q "source /home/h82/.config/zsh/.zshenv"
            touch $out
          '';
        ghostty-font =
          let
            host = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11;
            ghosttyConfig = host.config.home-manager.users.h82.xdg.configFile."ghostty/config".source;
            monospaceFonts = host.config.fonts.fontconfig.defaultFonts.monospace;
          in
          pkgs.runCommand "ghostty-font-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
            grep -Fx "font-family = JetBrainsMono Nerd Font" ${ghosttyConfig}
            grep -Fx "font-family = D2CodingLigature Nerd Font" ${ghosttyConfig}
            grep -Fx "font-family = D2KodingLigature Nerd Font" ${ghosttyConfig}
            echo '${builtins.toJSON monospaceFonts}' | grep -q "D2CodingLigature Nerd Font"
            echo '${builtins.toJSON monospaceFonts}' | grep -q "D2KodingLigature Nerd Font"
            touch $out
          '';
        python3-runtime =
          let
            host = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11;
            userPackages = host.config.home-manager.users.h82.home.packages;
            hasPython3 = pkgs.lib.lists.any (p: (p.pname or "") == "python3") userPackages;
            hasUv = pkgs.lib.lists.any (p: (p.pname or "") == "uv") userPackages;
          in
          pkgs.runCommand "python3-runtime-tests"
            {
              nativeBuildInputs = [
                pkgs.python3
                pkgs.uv
              ];
            }
            ''
              ${pkgs.lib.optionalString (!hasPython3) "echo 'missing python3 in user packages' >&2; exit 1;"}
              ${pkgs.lib.optionalString (!hasUv) "echo 'missing uv in user packages' >&2; exit 1;"}
              python3 --version
              uv --version
              touch $out
            '';
        gpg-agent-no-cache =
          let
            user = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.home-manager.users.h82;
            gpgAgentConf =
              pkgs.writeText "gpg-agent.conf"
                user.home.file."${user.programs.gpg.homedir}/gpg-agent.conf".text;
          in
          pkgs.runCommand "gpg-agent-no-cache-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
            set -x
            if ! grep -Fxq 'default-cache-ttl 0' ${gpgAgentConf}; then
              echo 'gpg-agent.conf no longer sets default-cache-ttl 0' >&2
              exit 1
            fi
            if ! grep -Fxq 'max-cache-ttl 0' ${gpgAgentConf}; then
              echo 'gpg-agent.conf no longer sets max-cache-ttl 0' >&2
              exit 1
            fi
            # Any further cache lifetime, ssh variants included, reintroduces the
            # agent-side cache the card PIN handling is built on doing without.
            if grep -E 'cache-ttl' ${gpgAgentConf} | grep -qvE '^[a-z-]*cache-ttl(-ssh)? 0$'; then
              echo 'gpg-agent.conf sets a non-zero cache lifetime' >&2
              exit 1
            fi
            touch $out
          '';
        yubikey-manager-shell =
          let
            shellPackages = self.devShells.${system}.default.nativeBuildInputs;
            ykman = pkgs.lib.lists.findFirst (p: (p.pname or "") == "yubikey-manager") null shellPackages;
            # The store-path interpolation stays inside an optionalString guard so that
            # dropping the package fails inside the builder with the message below, rather
            # than aborting evaluation with a null coercion error.
            absent = pkgs.lib.optionalString (ykman == null) ''
              echo 'missing yubikey-manager in the development shell' >&2
              exit 1
            '';
            present = pkgs.lib.optionalString (ykman != null) ''
              if [ ! -x ${ykman}/bin/ykman ]; then
                echo 'yubikey-manager package ships no bin/ykman executable' >&2
                exit 1
              fi
            '';
          in
          pkgs.runCommand "yubikey-manager-shell-tests" { } ''
            set -x
            ${absent}
            ${present}
            touch $out
          '';
        yubikey-fido = import ./tests/yubikey-fido.nix { inherit pkgs self; };
        kleopatra-gui =
          let
            host = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11;
            userPackages = host.config.home-manager.users.h82.home.packages;
            kleopatra = pkgs.lib.lists.findFirst (p: (p.pname or "") == "kleopatra") null userPackages;
            # Every store-path interpolation stays inside an optionalString guard so that
            # removing the package fails inside the builder with the message below, rather
            # than aborting evaluation with a null coercion error.
            absent = pkgs.lib.optionalString (kleopatra == null) ''
              echo 'missing kleopatra in user packages' >&2
              exit 1
            '';
            present = pkgs.lib.optionalString (kleopatra != null) ''
              if [ ! -x ${kleopatra}/bin/kleopatra ]; then
                echo 'kleopatra package ships no bin/kleopatra executable' >&2
                exit 1
              fi
              if [ ! -f ${kleopatra}/share/applications/org.kde.kleopatra.desktop ]; then
                echo 'kleopatra package ships no org.kde.kleopatra.desktop entry' >&2
                exit 1
              fi
            '';
          in
          pkgs.runCommand "kleopatra-gui-tests" { } ''
            set -x
            ${absent}
            ${present}
            touch $out
          '';
        bootstrap-recipients = import ./tests/bootstrap-recipients.nix { inherit pkgs; };
        github-workflow-conventions =
          pkgs.runCommand "github-workflow-conventions-tests"
            {
              nativeBuildInputs = [
                pkgs.gawk
                pkgs.gnugrep
              ];
            }
            ''
              bash ${./tests/github-workflow-conventions.sh} \
                ${./.github/workflows/claude-code-review.yml} \
                ${./.github/workflows/claude.yml}
              touch $out
            '';
        desktop-autostart = import ./tests/desktop-autostart.nix { inherit pkgs self; };
        nixos-rebuild-helper = import ./tests/nixos-rebuild-helper.nix { inherit pkgs self; };
        nr = pkgs.runCommand "nr-tests" { nativeBuildInputs = [ pkgs.git ]; } ''
          export HOME=$TMPDIR
          mkdir -p scripts tests
          cp ${./scripts/nr} scripts/nr
          cp ${./tests/nr.sh} tests/nr.sh
          chmod +x scripts/nr
          patchShebangs scripts/nr
          bash tests/nr.sh scripts/nr
          touch $out
        '';
        age-identity-helpers =
          pkgs.runCommand "age-identity-helpers-tests" { nativeBuildInputs = [ pkgs.coreutils ]; }
            ''
              export HOME=$TMPDIR
              mkdir -p scripts tests
              cp ${./scripts/recover-age-identity} scripts/recover-age-identity
              cp ${./scripts/prepare-age-identity} scripts/prepare-age-identity
              cp ${./tests/age-identity-helpers.sh} tests/age-identity-helpers.sh
              chmod +x scripts/recover-age-identity scripts/prepare-age-identity
              patchShebangs scripts/recover-age-identity scripts/prepare-age-identity
              bash tests/age-identity-helpers.sh \
                scripts/recover-age-identity scripts/prepare-age-identity
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
          yubikey-manager
        ];
      };
    };
}
