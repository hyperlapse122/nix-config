{
  description = "Declarative NixOS configuration for personal hosts";

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
    # Applies the system layer of a non-NixOS host: /etc files and systemd
    # units on a distribution this flake does not own.
    system-manager = {
      url = "github:numtide/system-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Applies the system layer of a macOS host, with Home Manager inside it.
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Installs Homebrew itself on a macOS host, so the first apply needs no
    # manual Homebrew install; nix-darwin's homebrew module installs the casks.
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    # Boots a foreign distribution's cloud image for the non-NixOS VM check.
    nix-vm-test = {
      url = "github:numtide/nix-vm-test";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Pinned to a release tag rather than a branch, and the registry in
    # home/h82/agents/agent-plugins.nix records the revision that tag is expected to
    # name. A tag is mutable and a relock re-resolves the ref, so the tag alone
    # is not a pin -- the agent-plugins check compares this input's locked
    # revision against that recorded value and fails when upstream moves it.
    compound-engineering-plugin = {
      url = "github:EveryInc/compound-engineering-plugin/compound-engineering-v3.31.0";
      flake = false;
    };
    korean-skills = {
      url = "github:DaleSeo/korean-skills/v1.0.0";
      flake = false;
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
      agentTools = import ./packages/agent-tools.nix { inherit pkgs; };
      inherit (nixpkgs) lib;

      # Each directory under hosts/ is a host, named by the directory. One that
      # holds host.nix is a Linux or macOS host, by the kind host.nix names;
      # every other one is a NixOS host.
      hosts = import ./lib/hosts.nix { inherit lib; } ./hosts;

      # Both variants of every host one assembly builds, keyed by output name.
      variantsOf =
        mkHost: hostNames:
        lib.listToAttrs (
          lib.concatMap (hosts.withVariants (
            hostName: bootstrap:
            mkHost {
              inherit hostName bootstrap;
              dir = ./hosts + "/${hostName}";
            }
          )) hostNames
        );
      linuxHosts = variantsOf (import ./lib/linux-host.nix { inherit inputs; }) hosts.linux;
      darwinHosts = variantsOf (import ./lib/darwin-host.nix { inherit inputs; }) hosts.darwin;
      darwinFixtures = import ./tests/lib/darwin-fixtures.nix { inherit inputs; };

      # The non-NixOS fixture hosts build on their own architecture, so each
      # system's checks carry the fixtures of that system.
      linuxFixtures = import ./tests/lib/linux-fixtures.nix { inherit inputs; };
      fixtureChecksFor = import ./tests/lib/fixture-checks.nix { inherit lib linuxFixtures; };
      vmChecks = import ./tests/vm-checks.nix { inherit pkgs inputs linuxFixtures; };
      checkShards = import ./tests/check-shards.nix {
        inherit pkgs;
        checks = self.checks.${system};
        # The checks whose closure carries a host generation, found by
        # sweeping each check's .drv closure for a NixOS system-path or a Home
        # Manager or system-manager generation. The fixture checks are listed
        # through fixtureChecksFor because their names embed a fixture host.
        hostClosureChecks = [
          "agent-browser-deps"
          "baloo-extractor"
          "desktop-ssh"
          "elf-load-segments"
          "emoji-font"
          "iphone-restore"
          "kde-theme"
          "minikube-autostart"
          "nix-cleanup"
          "non-nixos-outputs"
          "printing"
          "proton-vpn"
          "user-avatar"
          "wifiman"
          "winbox"
          "yubikey-fido"
        ]
        ++ lib.attrNames (fixtureChecksFor system);
        lightCount = 3;
      };
    in
    {
      homeConfigurations = lib.mapAttrs (_: host: host.home) linuxHosts;
      systemConfigs = lib.mapAttrs (_: host: host.systemManager) linuxHosts;
      checks.aarch64-linux = fixtureChecksFor "aarch64-linux";
      # Reads what the macOS fixture hosts materialize, so building it builds
      # both fixture systems; only a macOS builder can.
      checks.aarch64-darwin.darwin-outputs = import ./tests/darwin-outputs.nix {
        pkgs = import nixpkgs { system = "aarch64-darwin"; };
        inherit darwinFixtures;
      };
      darwinConfigurations = darwinHosts;

      nixosConfigurations =
        let
          mkHost = import ./lib/nixos-host.nix { inherit inputs; };
        in
        lib.listToAttrs (
          lib.concatMap (hosts.withVariants (
            hostName: bootstrap: mkHost { inherit hostName bootstrap; }
          )) hosts.nixos
        );
      packages.${system} = {
        disko = inputs.disko.packages.${system}.disko;
        # Exposed so the release-tracking workflow invokes the packaged helper
        # rather than running scripts/ with whatever interpreter the runner has.
        agent-plugin-release = agentTools.agentPluginRelease;
        claude-desktop-release = agentTools.claudeDesktopRelease;
        claude-desktop = import ./packages/claude-desktop.nix { inherit pkgs; };
        wifiman-desktop-release = agentTools.wifimanDesktopRelease;
        wifiman-desktop = import ./packages/wifiman-desktop.nix { inherit pkgs; };
        claude-code-release = agentTools.claudeCodeRelease;
        claude-code = import ./packages/claude-code.nix { inherit pkgs; };
        mise-release = agentTools.miseRelease;
        mise = import ./packages/mise.nix { inherit pkgs; };
        opencode-release = agentTools.opencodeRelease;
        opencode = import ./packages/opencode.nix { inherit pkgs; };
        pi-release = agentTools.piRelease;
        pi = import ./packages/pi.nix { inherit pkgs; };
        npm-release = agentTools.npmRelease;
        pi-acp = import ./packages/pi-acp.nix { inherit pkgs; };
        acpx = import ./packages/acpx.nix { inherit pkgs; };
        antigravity-cli-release = agentTools.antigravityCliRelease;
        antigravity-cli = import ./packages/antigravity-cli.nix { inherit pkgs; };
        t3code-release = agentTools.t3codeRelease;
        synthetic-models-watch = agentTools.syntheticModelsWatch;
        t3code = import ./packages/t3code.nix { inherit pkgs; };
        t3code-cli = import ./packages/t3code-cli.nix { inherit pkgs; };
        antigravity-acp = import ./packages/antigravity-acp.nix {
          inherit pkgs;
          pins = (builtins.fromJSON (builtins.readFile ./packages/t3code-release.json)).antigravity;
        };
        antigravity-acp-release = agentTools.antigravityAcpRelease;
        antigravity-acp-path = import ./packages/antigravity-acp-path.nix { inherit pkgs; };
        android-sdk-release = agentTools.androidSdkRelease;
      };
      # VM tests live outside `checks` so `nix flake check` stays fast and needs
      # no KVM. legacyPackages, unlike an unknown top-level output, draws no
      # flake check warning, and `nix build .#vmChecks.<name>` resolves here.
      legacyPackages.${system} = {
        vmChecks = vmChecks // {
          all = pkgs.linkFarm "vm-checks" vmChecks;
        };
        # CI builds the checks one shard per job; `nix flake check` still
        # builds them all at once.
        checkShards = checkShards.shards;
      };
      checks.${system} =
        let
          configurations = import ./tests/lib/configurations.nix {
            inherit pkgs self;
            fixtures = linuxFixtures;
          };

          # Runs `assertConfiguration` over every configuration the flake builds.
          # Each per-configuration fragment records a failure in `fail` instead of
          # exiting, so one red build names every affected configuration.
          forEveryConfiguration = assertConfiguration: ''
            ${configurations.guard}
            fail=0
            ${pkgs.lib.concatMapStrings assertConfiguration configurations.entries}
            [ "$fail" = 0 ] || exit 1
          '';

          # Runs `assertUser` over every Home Manager user environment the flake
          # builds for this architecture, NixOS and non-NixOS hosts alike.
          forEveryUser = assertUser: ''
            ${configurations.userGuard}
            fail=0
            ${pkgs.lib.concatMapStrings assertUser configurations.userEntries}
            [ "$fail" = 0 ] || exit 1
          '';

          # A configuration whose user went missing reports each package as
          # absent inside the builder rather than aborting evaluation.
          userPackagesOf = entry: entry.user.home.packages or [ ];

          # The user package with this pname, or null when none is installed.
          userPackageOf =
            pname: entry: pkgs.lib.lists.findFirst (p: (p.pname or "") == pname) null (userPackagesOf entry);

          # Fetches every platform a release pin names, not only this system's,
          # so a wrong URL or hash for a platform no Linux job builds fails on
          # the x86_64 updater before the pin reaches main.
          pinnedSources =
            name: pinFile:
            pkgs.linkFarm name (
              pkgs.lib.mapAttrs (_: platform: pkgs.fetchurl { inherit (platform) url hash; })
                (builtins.fromJSON (builtins.readFile pinFile)).platforms
            );

          # Home Manager file targets of one user environment.
          homeFileTargets =
            entry: map (file: file.target or "") (builtins.attrValues (entry.user.home.file or { }));

          # Runs a stdlib Python test against a copy of the one script it drives.
          optionalLines = text: pkgs.lib.optionalString (text != "") "\n${pkgs.lib.removeSuffix "\n" text}";
          pythonScriptCheckWith =
            {
              setup ? "",
              extra ? "",
            }:
            name: script: test:
            pkgs.runCommand "${name}-tests" { nativeBuildInputs = [ pkgs.python3 ]; } ''
              export PYTHONDONTWRITEBYTECODE=1
              mkdir -p scripts tests
              cp ${script} scripts/${baseNameOf script}
              cp ${test} tests/${baseNameOf test}${optionalLines setup}
              python tests/${baseNameOf test}${optionalLines extra}
              touch $out
            '';
          pythonScriptCheck = pythonScriptCheckWith { };

          # Every store-path interpolation stays inside an optionalString guard so
          # that removing the package fails inside the builder with the message
          # below, rather than aborting evaluation with a null coercion error.
          assertUserPackage =
            {
              pname,
              executables,
              desktopEntries,
            }:
            entry:
            let
              package = userPackageOf pname entry;
            in
            ''
              ${pkgs.lib.optionalString (package == null) ''
                echo 'missing ${pname} in user packages on ${entry.name}' >&2
                fail=1
              ''}
              ${pkgs.lib.optionalString (package != null) ''
                ${pkgs.lib.concatMapStrings (executable: ''
                  if [ ! -x ${package}/bin/${executable} ]; then
                    echo '${pname} package ships no bin/${executable} executable on ${entry.name}' >&2
                    fail=1
                  fi
                '') executables}
                ${pkgs.lib.concatMapStrings (desktopEntry: ''
                  if [ ! -f ${package}/share/applications/${desktopEntry} ]; then
                    echo '${pname} package ships no ${desktopEntry} entry on ${entry.name}' >&2
                    fail=1
                  fi
                '') desktopEntries}
              ''}
            '';
        in
        {
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
          podman-machine-resources = pkgs.runCommand "podman-machine-resources-tests" { } ''
            bash ${./tests/podman-machine-resources.sh} ${
              pkgs.lib.getExe (import ./packages/podman-machine-resources.nix { inherit pkgs; })
            }
            touch $out
          '';
          minikube-darwin-start = pkgs.runCommand "minikube-darwin-start-tests" { } ''
            bash ${./tests/minikube-darwin-start.sh} ${
              pkgs.lib.getExe (import ./packages/minikube-darwin-start.nix { inherit pkgs; })
            }
            touch $out
          '';
          mobile-devices = pkgs.runCommand "mobile-devices-tests" { } ''
            bash ${./tests/mobile-devices.sh} ${
              pkgs.lib.getExe (import ./packages/mobile-devices.nix { inherit pkgs; })
            }
            touch $out
          '';
          darwin-config = import ./tests/darwin-config.nix {
            inherit
              pkgs
              self
              linuxFixtures
              darwinFixtures
              ;
          };
          pinentry-card-darwin =
            pkgs.runCommand "pinentry-card-darwin-tests"
              {
                nativeBuildInputs = [
                  pkgs.python3
                  pkgs.bash
                ];
              }
              ''
                bash ${./tests/pinentry-card-darwin.sh} ${
                  (import ./packages/gpg-tools.nix { inherit pkgs; }).mkDarwinPinentryCard {
                    pinentryMac = "/pinentry-mac-stand-in/bin/pinentry-mac";
                  }
                }
                touch $out
              '';
          restore-age-identity =
            pythonScriptCheck "restore-age-identity" ./scripts/restore-age-identity
              ./tests/restore-age-identity.py;
          boot-layout-invariants = import ./tests/boot-layout-invariants.nix { inherit pkgs; };
          claude = import ./tests/claude.nix { inherit pkgs self; };
          synthetic-models = import ./tests/synthetic-models.nix { inherit pkgs; };
          # The probe needs a signed-in instance home, so no check runs it;
          # this covers its rule verdicts and the cleanup of what it plants.
          antigravity-acp-probe =
            pythonScriptCheck "antigravity-acp-probe" ./scripts/antigravity-acp-probe
              ./tests/test_antigravity_acp_probe.py;
          serve-html = pythonScriptCheck "serve-html" ./scripts/serve-html ./tests/test_serve_html.py;
          agent-settings =
            let
              tools = import ./packages/agent-tools.nix { inherit pkgs; };
              packaged = tools.agentSettings;
            in
            pkgs.runCommand "agent-settings-tests" { nativeBuildInputs = [ pkgs.python3 ]; } ''
              export PYTHONDONTWRITEBYTECODE=1
              mkdir -p scripts tests
              cp ${./scripts/agent-settings} scripts/agent-settings
              cp ${./tests/test_agent_settings.py} tests/test_agent_settings.py
              python tests/test_agent_settings.py

              # Activation runs the packaged binary, not this source copy, and its
              # unit's PATH carries no python3. Exercise the built file so a lost
              # +x bit or an unpatched `#!/usr/bin/env python3` fails here rather
              # than at activation.
              interpreter=$(head -1 ${packaged}/bin/agent-settings)
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
              env -i ${packaged}/bin/agent-settings \
                --settings "$PWD/home/.claude/settings.json" --declared "$PWD/declared.json"
              ${pkgs.python3}/bin/python3 - <<'PY'
              import json
              merged = json.load(open('home/.claude/settings.json'))
              assert merged['model'] == 'opus[1m]', merged
              assert merged['numStartups'] == 41, merged
              assert 'retired' not in merged, merged
              PY

              # Nested assignment through the packaged binary: the declared leaves
              # start divergent and every nested object carries a sibling, so a
              # whole-object replace drops a key here instead of matching.
              mkdir -p home/.config/tokscale
              printf '{"autoRefreshMs":60000,"tuiLightMode":true,"scanner":{"opencodeDbPaths":["x"],"bucketTimezone":"UTC"},"autosubmit":{"enabled":true,"lastRunAtMs":1700000000000},"scanner.bucketTimezone":"literal"}\n' \
                > home/.config/tokscale/settings.json
              printf '{"set":{"autoRefreshMs":30000},"setPaths":[{"path":["scanner","bucketTimezone"],"value":"Asia/Seoul"},{"path":["autosubmit","enabled"],"value":false}]}\n' \
                > nested.json
              env -i ${packaged}/bin/agent-settings --label Tokscale \
                --settings "$PWD/home/.config/tokscale/settings.json" --declared "$PWD/nested.json"
              ${pkgs.python3}/bin/python3 - <<'PY'
              import json
              merged = json.load(open('home/.config/tokscale/settings.json'))
              assert merged['autoRefreshMs'] == 30000, merged
              assert merged['tuiLightMode'] is True, merged
              assert merged['scanner'] == {'opencodeDbPaths': ['x'], 'bucketTimezone': 'Asia/Seoul'}, merged
              assert merged['autosubmit'] == {'enabled': False, 'lastRunAtMs': 1700000000000}, merged
              assert merged['scanner.bucketTimezone'] == 'literal', merged
              PY

              # A non-object intermediate must fail the process and leave the file alone.
              printf '{"scanner":"flat"}\n' > home/.config/tokscale/settings.json
              if env -i ${packaged}/bin/agent-settings --label Tokscale \
                  --settings "$PWD/home/.config/tokscale/settings.json" --declared "$PWD/nested.json"; then
                echo "packaged merger accepted a non-object intermediate" >&2
                exit 1
              fi
              if [ "$(cat home/.config/tokscale/settings.json)" != '{"scanner":"flat"}' ]; then
                echo "refused nested merge still rewrote the settings file" >&2
                exit 1
              fi

              # An owned key through the packaged binary: the repository's entry
              # starts stale with an extra event, and another writer's entry
              # beside it must come through byte for byte.
              mkdir -p home/.gemini/config
              printf '{"foreign-status":{"enabled":true,"Stop":[{"type":"command","command":"foreign-hook","timeout":10}]},"repo-owned":{"enabled":false,"Stop":[]}}\n' \
                > home/.gemini/config/hooks.json
              printf '{"own":{"repo-owned":{"enabled":true,"SessionStart":[{"type":"command","command":"x","timeout":10}]}}}\n' \
                > owned.json
              env -i ${packaged}/bin/agent-settings --label 'Antigravity hooks' \
                --settings "$PWD/home/.gemini/config/hooks.json" --declared "$PWD/owned.json"
              ${pkgs.python3}/bin/python3 - <<'PY'
              import json
              merged = json.load(open('home/.gemini/config/hooks.json'))
              assert merged['foreign-status'] == {'enabled': True, 'Stop': [{'type': 'command', 'command': 'foreign-hook', 'timeout': 10}]}, merged
              assert merged['repo-owned'] == {'enabled': True, 'SessionStart': [{'type': 'command', 'command': 'x', 'timeout': 10}]}, merged
              PY

              touch $out
            '';
          gemini = import ./tests/gemini.nix { inherit pkgs self; };
          ghq = import ./tests/ghq.nix { inherit pkgs self; };
          git-lfs = import ./tests/git-lfs.nix { inherit pkgs self; };
          git-trim = import ./tests/git-trim.nix { inherit pkgs self; };
          antigravity-acp-path = import ./tests/antigravity-acp-path.nix {
            inherit pkgs;
            pluginSource = inputs.compound-engineering-plugin;
          };
          shell-utilities = import ./tests/shell-utilities.nix { inherit pkgs self; };
          mise-settings = import ./tests/mise-settings.nix {
            inherit pkgs self;
            fixtures = linuxFixtures;
          };
          nix-cleanup = import ./tests/nix-cleanup.nix { inherit pkgs self; };
          elf-load-segments = import ./tests/elf-load-segments.nix {
            inherit pkgs self;
            fixtures = linuxFixtures;
          };
          boot-splash = import ./tests/boot-splash.nix { inherit pkgs self; };
          agent-plugins = import ./tests/agent-plugins.nix { inherit pkgs self; };
          korean-skills = import ./tests/korean-skills.nix {
            inherit pkgs self;
            fixtures = linuxFixtures;
          };
          antigravity-plugin-install = import ./tests/antigravity-plugin-install.nix { inherit pkgs self; };
          antigravity-cli-sources = pinnedSources "antigravity-cli-sources" ./packages/antigravity-cli-release.json;
          opencode-sources = pinnedSources "opencode-sources" ./packages/opencode-release.json;
          pi-sources = pinnedSources "pi-sources" ./packages/pi-release.json;
          agent-instructions = import ./tests/agent-instructions.nix {
            inherit pkgs self;
            fixtures = linuxFixtures;
          };
          git-cli-repo-flags = import ./tests/git-cli-repo-flags.nix {
            inherit pkgs self;
            fixtures = linuxFixtures;
          };
          agent-plugin-sync =
            pkgs.runCommand "agent-plugin-sync-tests" { nativeBuildInputs = [ pkgs.python3 ]; }
              ''
                export PYTHONDONTWRITEBYTECODE=1
                mkdir -p scripts tests
                cp ${./scripts/agent-plugin-sync} scripts/agent-plugin-sync
                cp ${./scripts/agent-settings} scripts/agent-settings
                cp ${./tests/test_agent_plugin_sync.py} tests/test_agent_plugin_sync.py
                python tests/test_agent_plugin_sync.py
                touch $out
              '';
          agent-plugin-release =
            pythonScriptCheck "agent-plugin-release" ./scripts/agent-plugin-release
              ./tests/test_agent_plugin_release.py;
          claude-desktop-release =
            pythonScriptCheck "claude-desktop-release" ./scripts/claude-desktop-release
              ./tests/test_claude_desktop_release.py;
          wifiman-desktop-release =
            pythonScriptCheck "wifiman-desktop-release" ./scripts/wifiman-desktop-release
              ./tests/test_wifiman_desktop_release.py;
          claude-code-release =
            pythonScriptCheck "claude-code-release" ./scripts/claude-code-release
              ./tests/test_claude_code_release.py;
          mise-release = pythonScriptCheck "mise-release" ./scripts/mise-release ./tests/test_mise_release.py;
          opencode-release =
            pythonScriptCheck "opencode-release" ./scripts/opencode-release
              ./tests/test_opencode_release.py;
          pi-release = pythonScriptCheck "pi-release" ./scripts/pi-release ./tests/test_pi_release.py;
          npm-release = pythonScriptCheck "npm-release" ./scripts/npm-release ./tests/test_npm_release.py;
          antigravity-cli-release =
            pythonScriptCheck "antigravity-cli-release" ./scripts/antigravity-cli-release
              ./tests/test_antigravity_cli_release.py;
          antigravity-acp-release =
            pythonScriptCheck "antigravity-acp-release" ./scripts/antigravity-acp-release
              ./tests/test_antigravity_acp_release.py;
          t3code-release =
            pythonScriptCheck "t3code-release" ./scripts/t3code-release
              ./tests/test_t3code_release.py;
          synthetic-models-watch =
            let
              realSource = pkgs.writeText "synthetic-models.json" (
                builtins.toJSON (import ./home/h82/agents/synthetic-models.nix)
              );
            in
            pythonScriptCheckWith {
              # The real source must match the snapshot, and the tests read it,
              # never a copy that can drift.
              setup = ''
                mkdir -p tests/fixtures
                cp -r ${./tests/fixtures/synthetic-models} tests/fixtures/synthetic-models
                python scripts/synthetic-models-watch --source-json ${realSource} \
                  --catalog tests/fixtures/synthetic-models/catalog-2026-10-21.json --result result.json
                python - <<'PY'
                import json, sys
                result = json.load(open("result.json"))
                if result["status"] != "clean" or result["findings"] != []:
                    sys.exit("synthetic-models-watch: home/h82/agents/synthetic-models.nix drifts from the "
                             f"2026-10-21 catalog snapshot: {json.dumps(result['findings'])}")
                PY
                export SYNTHETIC_MODELS_SOURCE_JSON=${realSource}
              '';
            } "synthetic-models-watch" ./scripts/synthetic-models-watch ./tests/test_synthetic_models_watch.py;
          synthetic-models-reconcile =
            pkgs.runCommand "synthetic-models-reconcile-tests"
              {
                nativeBuildInputs = [
                  pkgs.python3
                  pkgs.jq
                  pkgs.gawk
                ];
              }
              ''
                export PYTHONDONTWRITEBYTECODE=1
                bash ${./tests/synthetic-models-reconcile.sh} \
                  ${./.github/workflows/synthetic-models.yml} ${./scripts/synthetic-models-watch} \
                  ${./tests/fixtures/synthetic-models/catalog-2026-10-21.json} \
                  ${pkgs.writeText "synthetic-models.json" (
                    builtins.toJSON (import ./home/h82/agents/synthetic-models.nix)
                  )}
                touch $out
              '';
          t3code-antigravity-install =
            pkgs.runCommand "t3code-antigravity-install-tests" { nativeBuildInputs = [ pkgs.python3 ]; }
              ''
                export PYTHONDONTWRITEBYTECODE=1
                mkdir -p scripts tests
                cp ${./scripts/t3code-antigravity-install} scripts/t3code-antigravity-install
                cp ${./tests/test_t3code_antigravity_install.py} tests/test_t3code_antigravity_install.py
                patchShebangs scripts
                python tests/test_t3code_antigravity_install.py
                touch $out
              '';
          t3code-antigravity-link =
            pkgs.runCommand "t3code-antigravity-link-tests" { nativeBuildInputs = [ pkgs.python3 ]; }
              ''
                export PYTHONDONTWRITEBYTECODE=1
                mkdir -p scripts tests
                cp ${./scripts/t3code-antigravity-link} scripts/t3code-antigravity-link
                cp ${./tests/test_t3code_antigravity_link.py} tests/test_t3code_antigravity_link.py
                patchShebangs scripts
                python tests/test_t3code_antigravity_link.py
                touch $out
              '';
          t3code-antigravity-pin =
            pkgs.runCommand "t3code-antigravity-pin" { nativeBuildInputs = [ pkgs.python3 ]; }
              ''
                                python3 -I ${./tests/t3code-antigravity-pin.py} \
                                  ${./packages/t3code-release.json} \
                                  ${./packages/antigravity-acp-release.json}

                                if python3 -I ${./tests/t3code-antigravity-pin.py} \
                                  nonexistent.json \
                                  ${./packages/antigravity-acp-release.json} >/dev/null 2>&1; then
                                  echo "t3code-antigravity-pin passed with a missing pin file" >&2
                                  exit 1
                                fi

                                python3 - <<'PY'
                import json
                d = json.load(open('${./packages/t3code-release.json}'))
                del d["antigravity"]["x86_64-linux"]
                with open("missing-system.json", "w") as f:
                    json.dump(d, f)
                PY
                                if python3 -I ${./tests/t3code-antigravity-pin.py} \
                                  missing-system.json \
                                  ${./packages/antigravity-acp-release.json} >/dev/null 2>&1; then
                                  echo "t3code-antigravity-pin passed with a missing supported system" >&2
                                  exit 1
                                fi

                                python3 - <<'PY'
                import base64, json
                d = json.load(open('${./packages/t3code-release.json}'))
                d["antigravity"]["x86_64-linux"]["sha256"] = "0" * 64
                d["antigravity"]["x86_64-linux"]["hash"] = "sha256-" + base64.b64encode(bytes.fromhex("0" * 64)).decode("ascii")
                with open("differing-sha.json", "w") as f:
                    json.dump(d, f)
                PY
                                if python3 -I ${./tests/t3code-antigravity-pin.py} \
                                  differing-sha.json \
                                  ${./packages/antigravity-acp-release.json} >/dev/null 2>&1; then
                                  echo "t3code-antigravity-pin passed when sha256 differed" >&2
                                  exit 1
                                fi

                                python3 - <<'PY'
                src = open('${./tests/t3code-antigravity-pin.py}').read()
                mutant = src.replace("if val_a != val_b:", "if False and val_a != val_b:")
                assert mutant != src, "equality comparison mutation failed to apply"
                with open("mutant.py", "w") as f:
                    f.write(mutant)
                PY
                                if ! python3 -I mutant.py differing-sha.json ${./packages/antigravity-acp-release.json} >/dev/null 2>&1; then
                                  echo "self-test: mutant script without equality comparison still failed mismatched pins" >&2
                                  exit 1
                                fi

                                touch $out
              '';
          # scripts/t3code-antigravity-link derives each instance home the way
          # the pinned T3 Code does: the hex SHA-256 of the instance id under
          # providers/antigravity. A T3 Code bump that changes either fails
          # here instead of leaving the links in homes T3 Code no longer reads.
          # The plugin skills reach each home only through T3 Code's own link
          # of antigravity-cli/skills, so that link is checked as well: the
          # directories, the loop that symlinks each one, and the call from
          # profile preparation, so a helper left unused does not pass.
          t3code-antigravity-layout = pkgs.runCommand "t3code-antigravity-layout" { } ''
            bundle=${self.packages.${system}.t3code-cli}/libexec/t3code/t3
            for fragment in \
              'crypto.digest("SHA-256", new TextEncoder().encode(instanceId))' \
              'profile: path.join(stateDir, "providers", "antigravity", key),' \
              'const geminiHome = path.resolve(input.profileDirectory);' \
              'return [path.join(geminiHome, "config", "skills"), path.join(geminiHome, "antigravity-cli", "skills")];' \
              'const targets = antigravityUserSkillDirectories(path, path.join(input.userHome, ".gemini"));' \
              'for (const [link, target] of [[links[0], targets[0]], [links[1], targets[1]]])' \
              'NodeFSP.symlink(target, link, input.platform === "win32" ? "junction" : "dir")' \
              'yield* linkAntigravityUserSkills({'; do
              if ! grep -aqF "$fragment" "$bundle"; then
                echo "the pinned T3 Code no longer contains: $fragment" >&2
                exit 1
              fi
            done
            touch $out
          '';
          # Drives the packaged helper, so a package that lost nokogiri from its
          # interpreter fails here rather than in the update workflow.
          android-sdk-release =
            pkgs.runCommand "android-sdk-release-tests" { nativeBuildInputs = [ pkgs.python3 ]; }
              ''
                export PYTHONDONTWRITEBYTECODE=1
                export ANDROID_SDK_RELEASE=${pkgs.lib.getExe agentTools.androidSdkRelease}
                python ${./tests/test_android_sdk_release.py}
                touch $out
              '';
          android-sdk-repo-parity =
            pkgs.runCommand "android-sdk-repo-parity" { nativeBuildInputs = [ pkgs.python3 ]; }
              ''
                python ${./tests/android-sdk-repo-parity.py} \
                  ${./packages/android-sdk-repo.json} \
                  ${pkgs.path}/pkgs/development/mobile/androidenv/repo.json
                touch $out
              '';
          nix-ld = import ./tests/nix-ld.nix { inherit pkgs self; };
          agent-browser-deps = import ./tests/agent-browser-deps.nix { inherit pkgs self; };
          wifi-assertions = import ./tests/wifi-assertions.nix { inherit pkgs inputs; };
          tailscale-single-router =
            let
              # Counted over production configurations: a bootstrap output never
              # joins the tailnet as the router the production host is.
              routers = configurations.withTrait "my.tailscale.advertiseRoutes" (
                config: config.my.tailscale.advertiseRoutes
              );
              advertisers = map (entry: entry.name) (pkgs.lib.filter (entry: !entry.bootstrap) routers.enabled);
            in
            pkgs.runCommand "tailscale-single-router-tests" { } ''
              ${configurations.guard}
              ${routers.guard}
              ${
                if pkgs.lib.length advertisers > 1 then
                  ''
                    echo "more than one host advertises Tailscale subnet routes: ${pkgs.lib.concatStringsSep ", " advertisers}" >&2
                    exit 1
                  ''
                else
                  ""
              }
              touch $out
            '';
          publish-cli-auth =
            pythonScriptCheck "publish-cli-auth" ./scripts/publish-cli-auth
              ./tests/test_publish_cli_auth.py;
          docker-credential-sops =
            pythonScriptCheck "docker-credential-sops" ./scripts/docker-credential-sops
              ./tests/test_docker_credential_sops.py;
          podman-containers = import ./tests/podman-containers.nix { inherit pkgs self; };
          android-sdk = import ./tests/android-sdk.nix { inherit pkgs self; };
          session-variables = import ./tests/session-variables.nix {
            inherit pkgs self;
            fixtures = linuxFixtures;
          };
          antigravity-acp-path-profiles = import ./tests/antigravity-acp-path-profiles.nix {
            inherit pkgs self;
            fixtures = linuxFixtures;
          };
          serve-html-profiles = import ./tests/serve-html-profiles.nix {
            inherit pkgs self;
            fixtures = linuxFixtures;
          };
          kubernetes-tools = import ./tests/kubernetes-tools.nix {
            inherit pkgs self;
            fixtures = linuxFixtures;
          };
          minikube-autostart = import ./tests/minikube-autostart.nix {
            inherit pkgs self;
            fixtures = linuxFixtures;
          };
          zsh-prezto =
            let
              assertConfiguration =
                entry:
                let
                  files = entry.user.home.file or { };
                  # A missing file fails inside the builder with its name, rather
                  # than aborting evaluation on a null coercion.
                  assertSource =
                    file: pattern:
                    let
                      source = files.${file}.source or null;
                    in
                    if source == null then
                      ''
                        echo 'missing home.file ${file} on ${entry.name}' >&2
                        fail=1
                      ''
                    else
                      ''
                        if ! grep -q ${pkgs.lib.escapeShellArg pattern} ${source}; then
                          echo ${pkgs.lib.escapeShellArg "${file} does not contain ${pattern} on ${entry.name}"} >&2
                          fail=1
                        fi
                      '';
                  dotzshenv = files.".zshenv".text or "";
                  zshenv = "${entry.user.home.homeDirectory or "/nonexistent"}/.config/zsh/.zshenv";
                in
                ''
                  ${assertSource ".config/zsh/.zpreztorc" "zstyle ':prezto:load' pmodule"}
                  ${assertSource ".config/zsh/.zshenv" "runcoms/zshenv"}
                  ${assertSource ".config/zsh/.zshrc" "runcoms/zshrc"}
                  if ! grep -qF ${pkgs.lib.escapeShellArg "source ${zshenv}"} <<<${pkgs.lib.escapeShellArg dotzshenv}; then
                    echo ${pkgs.lib.escapeShellArg ".zshenv does not source ${zshenv} on ${entry.name}"} >&2
                    fail=1
                  fi
                '';
            in
            pkgs.runCommand "zsh-prezto-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
              ${forEveryUser assertConfiguration}
              touch $out
            '';
          ghostty-font =
            let
              assertConfiguration =
                entry:
                let
                  ghosttyConfig = entry.user.xdg.configFile."ghostty/config".source or null;
                  monospaceFonts = builtins.toJSON entry.config.fonts.fontconfig.defaultFonts.monospace;
                in
                ''
                  ${pkgs.lib.optionalString (ghosttyConfig == null) ''
                    echo 'missing xdg.configFile ghostty/config on ${entry.name}' >&2
                    fail=1
                  ''}
                  ${pkgs.lib.optionalString (ghosttyConfig != null) (
                    pkgs.lib.concatMapStrings
                      (font: ''
                        if ! grep -Fxq "font-family = ${font}" ${ghosttyConfig}; then
                          echo 'ghostty config does not set font-family = ${font} on ${entry.name}' >&2
                          fail=1
                        fi
                      '')
                      [
                        "JetBrainsMono Nerd Font"
                        "D2CodingLigature Nerd Font"
                        "D2KodingLigature Nerd Font"
                        "Twitter Color Emoji"
                      ]
                  )}
                  ${pkgs.lib.optionalString (ghosttyConfig != null) ''
                    # Twemoji covers ASCII digits and space, so it must stay
                    # after every text font.
                    if [ "$(grep '^font-family = ' ${ghosttyConfig} | tail -n 1)" != 'font-family = Twitter Color Emoji' ] \
                      || [ "$(grep -cFx 'font-family = Twitter Color Emoji' ${ghosttyConfig})" -ne 1 ]; then
                      echo 'ghostty config does not list Twitter Color Emoji once, last, on ${entry.name}' >&2
                      fail=1
                    fi
                  ''}
                  ${pkgs.lib.concatMapStrings
                    (font: ''
                      if ! echo '${monospaceFonts}' | grep -q "${font}"; then
                        echo 'default monospace fonts do not include ${font} on ${entry.name}' >&2
                        fail=1
                      fi
                    '')
                    [
                      "D2CodingLigature Nerd Font"
                      "D2KodingLigature Nerd Font"
                    ]
                  }
                '';
            in
            pkgs.runCommand "ghostty-font-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
              ${forEveryConfiguration assertConfiguration}
              touch $out
            '';
          python3-runtime =
            let
              assertConfiguration =
                entry:
                pkgs.lib.concatMapStrings
                  (
                    pname:
                    assertUserPackage {
                      inherit pname;
                      executables = [ ];
                      desktopEntries = [ ];
                    } entry
                  )
                  [
                    "python3"
                    "uv"
                  ];
            in
            pkgs.runCommand "python3-runtime-tests"
              {
                nativeBuildInputs = [
                  pkgs.python3
                  pkgs.uv
                ];
              }
              ''
                ${forEveryConfiguration assertConfiguration}
                python3 --version
                uv --version
                touch $out
              '';
          gpg-agent-no-cache =
            let
              assertConfiguration =
                entry:
                let
                  homedir = entry.user.programs.gpg.homedir or null;
                  text =
                    if homedir == null then null else entry.user.home.file."${homedir}/gpg-agent.conf".text or null;
                  gpgAgentConf = pkgs.writeText "gpg-agent-${entry.name}.conf" text;
                in
                ''
                  ${pkgs.lib.optionalString (text == null) ''
                    echo 'missing gpg-agent.conf on ${entry.name}' >&2
                    fail=1
                  ''}
                  ${pkgs.lib.optionalString (text != null) ''
                    if ! grep -Fxq 'default-cache-ttl 0' ${gpgAgentConf}; then
                      echo 'gpg-agent.conf no longer sets default-cache-ttl 0 on ${entry.name}' >&2
                      fail=1
                    fi
                    if ! grep -Fxq 'max-cache-ttl 0' ${gpgAgentConf}; then
                      echo 'gpg-agent.conf no longer sets max-cache-ttl 0 on ${entry.name}' >&2
                      fail=1
                    fi
                    # Any further cache lifetime, ssh variants included, reintroduces the
                    # agent-side cache the card PIN handling is built on doing without.
                    if grep -E 'cache-ttl' ${gpgAgentConf} | grep -qvE '^[a-z-]*cache-ttl(-ssh)? 0$'; then
                      echo 'gpg-agent.conf sets a non-zero cache lifetime on ${entry.name}' >&2
                      fail=1
                    fi
                  ''}
                '';
            in
            pkgs.runCommand "gpg-agent-no-cache-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
              set -x
              ${forEveryUser assertConfiguration}
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
          kleopatra-gui = pkgs.runCommand "kleopatra-gui-tests" { } ''
            set -x
            ${forEveryConfiguration (assertUserPackage {
              pname = "kleopatra";
              executables = [ "kleopatra" ];
              desktopEntries = [ "org.kde.kleopatra.desktop" ];
            })}
            touch $out
          '';
          telegram-desktop = pkgs.runCommand "telegram-desktop-tests" { } ''
            set -x
            ${forEveryConfiguration (assertUserPackage {
              pname = "telegram-desktop";
              executables = [ "Telegram" ];
              desktopEntries = [ "org.telegram.desktop.desktop" ];
            })}
            touch $out
          '';
          libreoffice-office = pkgs.runCommand "libreoffice-office-tests" { } ''
            set -x
            ${forEveryConfiguration (assertUserPackage {
              pname = "libreoffice";
              executables = [ "libreoffice" ];
              desktopEntries = [
                "writer.desktop"
                "calc.desktop"
                "impress.desktop"
              ];
            })}
            touch $out
          '';
          okular-pdf = pkgs.runCommand "okular-pdf-tests" { } ''
            set -x
            ${forEveryConfiguration (assertUserPackage {
              pname = "okular";
              executables = [ "okular" ];
              # okularApplication_pdf.desktop is NoDisplay and only proves PDF handling;
              # org.kde.okular.desktop is the entry the application launcher shows.
              desktopEntries = [
                "org.kde.okular.desktop"
                "okularApplication_pdf.desktop"
              ];
            })}
            touch $out
          '';
          discord = pkgs.runCommand "discord-tests" { } ''
            set -x
            ${forEveryConfiguration (assertUserPackage {
              pname = "discord";
              executables = [ "discord" ];
              desktopEntries = [ "discord.desktop" ];
            })}
            touch $out
          '';
          claude-desktop =
            let
              assertConfiguration =
                entry:
                let
                  hasKvmGroup = builtins.elem "kvm" entry.config.users.users.h82.extraGroups;
                  hasVhostVsock = builtins.elem "vhost_vsock" entry.config.boot.kernelModules;
                in
                ''
                  ${assertUserPackage {
                    pname = "claude-desktop";
                    executables = [ "claude-desktop" ];
                    desktopEntries = [ "com.anthropic.Claude.desktop" ];
                  } entry}
                  ${pkgs.lib.optionalString (!hasKvmGroup) ''
                    echo 'user h82 missing kvm group on ${entry.name}' >&2
                    fail=1
                  ''}
                  ${pkgs.lib.optionalString (!hasVhostVsock) ''
                    echo 'missing vhost_vsock kernel module on ${entry.name}' >&2
                    fail=1
                  ''}
                '';
            in
            pkgs.runCommand "claude-desktop-tests" { } ''
              set -x
              ${forEveryConfiguration assertConfiguration}
              touch $out
            '';
          claude-code =
            let
              # Presence and an executable bin/claude alone would stay green even if
              # the override silently fell back to nixpkgs' own bundled manifest, so
              # this also asserts the package's own version attribute matches this
              # repo's pinned version (AE1). Reading `claudePkg.version` rather than
              # re-invoking `--version` doesn't re-check anything new: nixpkgs'
              # claude-code derivation already runs `versionCheckHook` unconditionally
              # at build time, which fails the build unless the binary's own
              # `--version` output already matches this exact attribute.
              pinnedVersion =
                (builtins.fromJSON (builtins.readFile ./packages/claude-code-manifest.json)).version;
              assertConfiguration =
                entry:
                let
                  claudePkg = userPackageOf "claude-code" entry;
                  versionMismatch =
                    pkgs.lib.optionalString (claudePkg != null && claudePkg.version != pinnedVersion)
                      ''
                        echo "claude-code on ${entry.name} is built from version '${claudePkg.version}', expected pin ${pinnedVersion}" >&2
                        fail=1
                      '';
                in
                ''
                  ${assertUserPackage {
                    pname = "claude-code";
                    executables = [ "claude" ];
                    desktopEntries = [ ];
                  } entry}
                  ${versionMismatch}
                '';
            in
            pkgs.runCommand "claude-code-tests" { } ''
              set -x
              ${forEveryConfiguration assertConfiguration}
              touch $out
            '';
          codex-absent =
            let
              assertUser =
                entry:
                let
                  codexFiles = builtins.filter (pkgs.lib.hasPrefix ".codex/") (homeFileTargets entry);
                in
                ''
                  ${pkgs.lib.optionalString (userPackageOf "codex" entry != null) ''
                    echo 'codex is still in the user packages on ${entry.name}' >&2
                    fail=1
                  ''}
                  ${pkgs.lib.optionalString (codexFiles != [ ]) ''
                    echo 'home files under ~/.codex remain on ${entry.name}: ${toString codexFiles}' >&2
                    fail=1
                  ''}
                '';
            in
            pkgs.runCommand "codex-absent" { } ''
              ${forEveryUser assertUser}
              touch $out
            '';
          grok-absent =
            let
              inherit (pkgs) lib;
              isGrokName = name: lib.hasInfix "grok" (lib.toLower name);
              # Names that contain "grok" but are not Grok. None today.
              allowed = [ ];
              grokNamesOf =
                names: lib.unique (builtins.filter (name: isGrokName name && !lib.elem name allowed) names);
              # A package counts by its pname or its name, so a renamed wrapper
              # such as grok-cli is caught as well as grok-build or grok-bot.
              grokPackagesOf =
                packages:
                grokNamesOf (
                  lib.concatMap (p: [
                    (p.pname or "")
                    (p.name or "")
                  ]) packages
                );
              darwinApps = import ./modules/shared/darwin-apps.nix;
              grokApps = grokNamesOf (builtins.attrNames darwinApps.apps);
              report =
                names: message:
                lib.optionalString (names != [ ]) ''
                  echo ${lib.escapeShellArg "${message}: ${toString names}"} >&2
                  fail=1
                '';
              assertUser =
                entry:
                let
                  grokFiles = builtins.filter (target: target == ".grok" || lib.hasPrefix ".grok/" target) (
                    homeFileTargets entry
                  );
                in
                ''
                  ${report (grokPackagesOf (userPackagesOf entry)) "Grok packages are still in the user packages on ${entry.name}"}
                  ${report grokFiles "home files under ~/.grok remain on ${entry.name}"}
                '';
              assertNixos = entry: ''
                ${report (grokPackagesOf (
                  entry.config.environment.systemPackages or [ ]
                )) "Grok packages are still in environment.systemPackages on ${entry.name}"}
                ${report (grokNamesOf (
                  builtins.attrNames (entry.config.systemd.services or { })
                )) "${entry.name} still has Grok system units"}
                ${report (grokNamesOf (
                  builtins.attrNames (entry.config.systemd.user.services or { })
                )) "${entry.name} still has Grok user units"}
              '';
              assertFixture =
                fixture:
                let
                  smConfig = fixture.host.systemManager.config;
                in
                ''
                  ${report (grokNamesOf (builtins.attrNames smConfig.environment.etc)) "the system-manager configuration of ${fixture.name} still writes /etc files for Grok"}
                  ${report (grokNamesOf (builtins.attrNames smConfig.systemd.services)) "the system-manager configuration of ${fixture.name} still has Grok units"}
                '';
              # Real Mac hosts and the macOS fixtures alike, read from the
              # evaluated configuration, so a cask, App Store app, or package a
              # module adds outside modules/shared/darwin-apps.nix is caught too.
              darwinEntries =
                map (entry: { inherit (entry) name host; }) darwinFixtures
                ++ lib.mapAttrsToList (name: host: { inherit name host; }) self.darwinConfigurations;
              assertDarwin =
                entry:
                let
                  inherit (entry.host) config;
                  user = config.home-manager.users.${config.my.user.name} or { };
                in
                ''
                  ${report (grokNamesOf (
                    map (cask: cask.name) config.homebrew.casks
                  )) "the macOS casks of ${entry.name} still include Grok"}
                  ${report (grokNamesOf (builtins.attrNames config.homebrew.masApps)) "the App Store apps of ${entry.name} still include Grok"}
                  ${report (grokPackagesOf (
                    config.environment.systemPackages or [ ]
                  )) "Grok packages are still in environment.systemPackages on ${entry.name}"}
                  ${assertUser {
                    inherit (entry) name;
                    inherit user;
                  }}
                '';
              standaloneUsers = lib.mapAttrsToList (name: home: {
                inherit name;
                user = home.config;
              }) self.homeConfigurations;
            in
            pkgs.runCommand "grok-absent" { } ''
              ${configurations.userGuard}
              fail=0
              ${lib.concatMapStrings assertUser (configurations.userEntries ++ standaloneUsers)}
              ${lib.concatMapStrings assertNixos configurations.entries}
              ${lib.optionalString (configurations.linuxFixtures == [ ]) ''
                echo 'no non-NixOS fixture host of this architecture, so the system-manager side of this check would cover none' >&2
                fail=1
              ''}
              ${lib.concatMapStrings assertFixture configurations.linuxFixtures}
              ${lib.optionalString (darwinFixtures == [ ]) ''
                echo 'no macOS fixture host, so the evaluated-cask side of this check would cover none' >&2
                fail=1
              ''}
              ${lib.concatMapStrings assertDarwin darwinEntries}
              ${report grokApps "modules/shared/darwin-apps.nix still maps Grok apps"}
              [ "$fail" = 0 ] || exit 1
              touch $out
            '';
          opencode =
            let
              # The version is compared with the pin for the reason given on
              # the claude-code check. The switches are read from the
              # installed bin/opencode itself, because they are what hold
              # under the inline config and config directories T3 Code
              # supplies, and what keep a checkout's config and Claude Code's
              # files away from the key.
              pinnedVersion = (builtins.fromJSON (builtins.readFile ./packages/opencode-release.json)).version;
              switches = [
                "export OPENCODE_DISABLE_AUTOUPDATE=true"
                "export OPENCODE_DISABLE_PROJECT_CONFIG=true"
                "export OPENCODE_CONFIG_PROJECT_DISABLE=true"
                "export OPENCODE_DISABLE_CLAUDE_CODE=true"
              ];
              assertConfiguration =
                entry:
                let
                  opencodePkg = userPackageOf "opencode" entry;
                  versionMismatch =
                    pkgs.lib.optionalString (opencodePkg != null && opencodePkg.version != pinnedVersion)
                      ''
                        echo "opencode on ${entry.name} is built from version '${opencodePkg.version}', expected pin ${pinnedVersion}" >&2
                        fail=1
                      '';
                  switchesMissing = pkgs.lib.optionalString (opencodePkg != null) ''
                    for switch in ${pkgs.lib.escapeShellArgs switches}; do
                      if ! grep -qxF -- "$switch" ${opencodePkg}/bin/opencode; then
                        echo "opencode on ${entry.name} lacks the wrapper line $switch" >&2
                        fail=1
                      fi
                    done
                  '';
                in
                ''
                  ${assertUserPackage {
                    pname = "opencode";
                    executables = [ "opencode" ];
                    desktopEntries = [ ];
                  } entry}
                  ${versionMismatch}
                  ${switchesMissing}
                '';
            in
            pkgs.runCommand "opencode-tests" { } ''
              set -x
              ${forEveryConfiguration assertConfiguration}
              touch $out
            '';
          antigravity-cli =
            let
              # The version is compared with the pin for the reason given on the
              # claude-code check. The wrapper variable is read from the
              # installed bin/agy, because it keeps agy from updating itself
              # under any GEMINI_HOME, such as T3 Code's per-provider homes.
              pinnedVersion =
                (builtins.fromJSON (builtins.readFile ./packages/antigravity-cli-release.json)).version;
              assertConfiguration =
                entry:
                let
                  agyPkg = userPackageOf "antigravity-cli" entry;
                  versionMismatch = pkgs.lib.optionalString (agyPkg != null && agyPkg.version != pinnedVersion) ''
                    echo "antigravity-cli on ${entry.name} is built from version '${agyPkg.version}', expected pin ${pinnedVersion}" >&2
                    fail=1
                  '';
                  updaterDisabled = pkgs.lib.optionalString (agyPkg != null) ''
                    if ! grep -qxF "export AGY_CLI_DISABLE_AUTO_UPDATE='true'" ${agyPkg}/bin/agy; then
                      echo "agy on ${entry.name} does not turn its self-updater off" >&2
                      fail=1
                    fi
                  '';
                in
                ''
                  ${assertUserPackage {
                    pname = "antigravity-cli";
                    executables = [ "agy" ];
                    desktopEntries = [ ];
                  } entry}
                  ${versionMismatch}
                  ${updaterDisabled}
                '';
            in
            pkgs.runCommand "antigravity-cli-tests" { } ''
              set -x
              ${forEveryConfiguration assertConfiguration}
              touch $out
            '';
          t3code =
            let
              # Package-only: the derivations come straight from this flake's
              # outputs, so neither can be null and no interpolation needs a
              # guard. The binaries are run, not just inspected, because a
              # stripped SEA or a patched static-pie binary still exists and is
              # executable. The pinned version is read from the pin file, so a
              # binary that reports any other version fails.
              pinnedVersion = (builtins.fromJSON (builtins.readFile ./packages/t3code-release.json)).version;
              cli = self.packages.${system}.t3code-cli;
              desktop = self.packages.${system}.t3code;
              tree = "${cli}/libexec/t3code";
              fakeRuntimeDir = "/run/user/4242";
              ptyProbe = pkgs.writeText "t3code-pty-probe.cjs" ''
                const pty = require(process.env.T3CODE_TREE + "/node_modules/node-pty");
                let output = "";
                const child = pty.spawn("${pkgs.coreutils}/bin/echo", ["pty", "spawned"], {});
                child.onData((data) => { output += data; });
                child.onExit(({ exitCode }) => {
                  console.log("pty-probe exit=" + exitCode + " output=" + output.trim());
                });
              '';
            in
            pkgs.runCommand "t3code-tests" { } ''
              set -x
              fail=0
              export HOME="$TMPDIR"

              if ! version=$(${cli}/bin/t3 --version 2>&1); then
                echo "t3 --version fails: $version" >&2
                fail=1
              elif [ "$version" != "t3 v${pinnedVersion}" ]; then
                echo "t3 --version reports '$version', expected the pin ${pinnedVersion}" >&2
                fail=1
              fi

              # The SEA honours NODE_OPTIONS, so node-pty's native addon is
              # loaded by the patched binary itself and spawns a real pty.
              probe=$(T3CODE_TREE=${tree} NODE_OPTIONS="--require ${ptyProbe}" ${cli}/bin/t3 --version 2>&1) || true
              case $probe in
                *"pty-probe exit=0 output=pty spawned"*) ;;
                *)
                  echo "node-pty does not load and spawn from the t3code-cli tree: $probe" >&2
                  fail=1
                  ;;
              esac

              rg=${tree}/node_modules/@cursor/sdk-${cli.platformKey}/bin/rg
              if ! "$rg" --version > /dev/null 2>&1; then
                echo "the bundled static-pie rg in t3code-cli does not run" >&2
                fail=1
              fi

              monitor=${tree}/resource-monitor/${cli.platformKey}/t3-resource-monitor
              if ! timeout 10 "$monitor" < /dev/null > monitor.out 2>&1 \
                || ! grep -q '"type":"hello"' monitor.out; then
                echo "the bundled t3-resource-monitor does not run" >&2
                cat monitor.out >&2
                fail=1
              fi

              # Takes the literal value and escapes it for the extended regex.
              expect_setenv() {
                value=$(printf '%s' "$2" | sed 's/[].[*^$+?(){}|\\]/\\&/g')
                if ! grep -qE "^[[:space:]]*--setenv $1 $value( |\$)" ${desktop}/bin/t3code-desktop; then
                  echo "the t3code-desktop wrapper does not set $1 to $2" >&2
                  fail=1
                fi
              }
              expect_setenv T3CODE_DISABLE_AUTO_UPDATE 1
              expect_setenv SSL_CERT_FILE /etc/ssl/certs/ca-certificates.crt

              # Expanded under a fake runtime directory, so a path baked in at
              # build time cannot match.
              containerHost=$(
                XDG_RUNTIME_DIR=${fakeRuntimeDir}
                line=$(grep -E '^[[:space:]]*--setenv CONTAINER_HOST ' ${desktop}/bin/t3code-desktop) || exit 0
                eval "set -- $line"
                printf '%s' "$3"
              )
              if [ "$containerHost" != "unix://${fakeRuntimeDir}/podman/podman.sock" ]; then
                echo "t3code-desktop sandbox CONTAINER_HOST '$containerHost' is not the session Podman socket" >&2
                fail=1
              fi

              entry=${desktop}/share/applications/t3code.desktop
              if [ ! -f "$entry" ]; then
                echo "t3code-desktop ships no t3code.desktop entry" >&2
                fail=1
              else
                exec=$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$entry")
                if [ -z "$exec" ] || [ ! -x "${desktop}/bin/$exec" ]; then
                  echo "t3code.desktop Exec '$exec' names no binary in the t3code-desktop package" >&2
                  fail=1
                fi
              fi

              [ "$fail" = 0 ] || exit 1
              touch $out
            '';
          bootstrap-recipients = import ./tests/bootstrap-recipients.nix { inherit pkgs; };
          linux-host-secrets = import ./tests/linux-host-secrets.nix { inherit pkgs self; };
          update-dependencies-push-order =
            pkgs.runCommand "update-dependencies-push-order-tests" { nativeBuildInputs = [ pkgs.git ]; }
              ''
                export HOME=$TMPDIR
                bash ${./tests/update-dependencies-push-order.sh} \
                  ${./.github/workflows/update-dependencies.yml} \
                  ${./.gitignore}
                touch $out
              '';
          update-dependencies-verify-status =
            pkgs.runCommand "update-dependencies-verify-status-tests" { nativeBuildInputs = [ pkgs.gawk ]; }
              ''
                bash ${./tests/update-dependencies-verify-status.sh} \
                  ${./.github/workflows/update-dependencies.yml}
                touch $out
              '';
          update-dependencies-reconcile =
            pkgs.runCommand "update-dependencies-reconcile-tests"
              {
                nativeBuildInputs = [
                  pkgs.git
                  pkgs.jq
                  pkgs.gawk
                ];
              }
              ''
                export HOME=$TMPDIR
                bash ${./tests/update-dependencies-reconcile.sh} \
                  ${./.github/workflows/update-dependencies.yml}
                touch $out
              '';
          ci-workflow-docs-skip =
            pkgs.runCommand "ci-workflow-docs-skip-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; }
              ''
                bash ${./tests/check-workflow-docs-skip.sh} ${./.github/workflows/check.yml}
                touch $out
              '';
          desktop-autostart = import ./tests/desktop-autostart.nix { inherit pkgs self; };
          desktop-ssh = import ./tests/desktop-ssh.nix { inherit pkgs self; };
          desktop-ssh-sources = import ./tests/desktop-ssh-sources.nix { inherit pkgs self; };
          plasma-taskbar = import ./tests/plasma-taskbar.nix { inherit pkgs self; };
          kde-theme = import ./tests/kde-theme.nix { inherit pkgs self; };
          baloo-extractor = import ./tests/baloo-extractor.nix { inherit pkgs self; };
          emoji-font = import ./tests/emoji-font.nix { inherit pkgs self; };
          user-avatar = import ./tests/user-avatar.nix { inherit pkgs self; };
          logitech-wakeup = import ./tests/logitech-wakeup.nix { inherit pkgs self; };
          udev-device-access = import ./tests/udev-device-access.nix { inherit pkgs self; };
          kernel-sysctl = import ./tests/kernel-sysctl.nix { inherit pkgs self; };
          proton-vpn = import ./tests/proton-vpn.nix { inherit pkgs self; };
          wireplumber-bluetooth = import ./tests/wireplumber-bluetooth.nix { inherit pkgs self; };
          iphone-restore = import ./tests/iphone-restore.nix { inherit pkgs self; };
          printing = import ./tests/printing.nix { inherit pkgs self; };
          winbox = import ./tests/winbox.nix { inherit pkgs self; };
          wifiman = import ./tests/wifiman.nix { inherit pkgs self; };
          nixos-rebuild-helper = import ./tests/nixos-rebuild-helper.nix { inherit pkgs self; };
          host-name-guard = import ./tests/host-name-guard.nix { inherit pkgs self; };
          vm-checks-guard = import ./tests/vm-checks-guard.nix {
            inherit pkgs vmChecks;
            # removeAttrs does not force the removed value, so the guard never
            # evaluates itself.
            checks = builtins.removeAttrs self.checks.${system} [ "vm-checks-guard" ];
          };
          check-shards-guard = import ./tests/check-shards-guard.nix {
            inherit pkgs;
            # attrNames forces no check, so the guard never evaluates itself.
            checkNames = builtins.attrNames self.checks.${system};
            inherit (checkShards) members;
          };
          host-options = import ./tests/host-options.nix { inherit pkgs self; };
          host-secrets = import ./tests/host-secrets.nix { inherit pkgs; };
          inherit (import ./tests/non-nixos-scripts.nix { inherit pkgs; })
            install-user-age-identity
            nr-linux
            nr-darwin
            ;
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
          opencode-settings = import ./tests/opencode.nix { inherit pkgs self; };
          pi-settings = import ./tests/pi.nix {
            inherit pkgs self;
            fixtures = linuxFixtures;
          };
          opencode-session-info = import ./tests/opencode-session-info.nix {
            inherit pkgs self;
            fixtures = linuxFixtures;
          };
          pi-extension = import ./tests/pi-extension.nix {
            inherit pkgs self;
            fixtures = linuxFixtures;
          };
          text-template = import ./tests/text-template.nix { inherit pkgs; };
          tokscale = import ./tests/tokscale.nix { inherit pkgs self; };
          vscodium = import ./tests/vscodium.nix { inherit pkgs self; };
          tokscale-wrapper =
            let
              packaged = import ./packages/tokscale.nix {
                inherit pkgs;
                hostName = "test-host";
                tokenFile = "${pkgs.writeText "tokscale-fake-token" "fake-token-123\n"}";
              };
            in
            pkgs.runCommand "tokscale-wrapper-tests" { } ''
              export HOME=$TMPDIR
              mkdir -p scripts tests
              cp ${./scripts/tokscale} scripts/tokscale
              cp ${./tests/tokscale.sh} tests/tokscale.sh
              chmod +x scripts/tokscale
              patchShebangs scripts/tokscale
              bash tests/tokscale.sh scripts/tokscale
              bash tests/tokscale.sh --packaged ${packaged}/bin/tokscale test-host fake-token-123
              touch $out
            '';
          opencode-wrapper =
            let
              tokenFile = "/var/empty/opencode-test/synthetic_api_key";
              packaged = import ./packages/opencode.nix { inherit pkgs tokenFile; };
              # The token path lands inside single quotes in the wrapper.
              guardCases = [
                {
                  label = "a relative token path";
                  tokenFile = "run/secrets/cli-auth/synthetic_api_key";
                  accept = false;
                }
                {
                  label = "a quote in the token path";
                  tokenFile = "/run/secrets/bad'path";
                  accept = false;
                }
                {
                  label = "a space in the token path";
                  tokenFile = "/run/secrets/bad path";
                  accept = false;
                }
                {
                  label = "a plain absolute token path";
                  tokenFile = "/home/test-user/.local/state/nix-config/secrets/synthetic_api_key";
                  accept = true;
                }
              ];
              guardChecks = lib.concatMapStrings (
                case:
                let
                  evaluated =
                    builtins.tryEval
                      (import ./packages/opencode.nix {
                        inherit pkgs;
                        inherit (case) tokenFile;
                      }).drvPath;
                in
                lib.optionalString (evaluated.success != case.accept) ''
                  echo ${lib.escapeShellArg "packages/opencode.nix ${if case.accept then "rejects" else "accepts"} ${case.label}"} >&2
                  exit 1
                ''
              ) guardCases;
            in
            pkgs.runCommand "opencode-wrapper-tests"
              {
                nativeBuildInputs = [ pkgs.procps ];
              }
              ''
                export HOME=$TMPDIR
                ${guardChecks}
                mkdir -p scripts tests
                cp ${./scripts/opencode} scripts/opencode
                cp ${./tests/opencode.sh} tests/opencode.sh
                chmod +x scripts/opencode
                patchShebangs scripts/opencode
                bash tests/opencode.sh scripts/opencode
                bash tests/opencode.sh --packaged ${packaged}/bin/opencode ${tokenFile}

                # The shared instructions reach OpenCode only as
                # ~/.config/opencode/AGENTS.md, which no config output reports.
                # The pinned payload must keep global instruction discovery on
                # unless a caller passes `global: false`, which no run here does.
                if ! grep -aqE 'project:[A-Za-z_$]+\?\.project!==!1,global:[A-Za-z_$]+\?\.global!==!1' ${packaged}/libexec/opencode/opencode; then
                  echo "the pinned OpenCode no longer loads ~/.config/opencode/AGENTS.md by default; recheck how the shared instructions reach it" >&2
                  exit 1
                fi

                # The pinned binary, not only the wrapper's export, must keep a
                # checkout's opencode.json out of the process holding the key.
                # The bare binary loading the canary proves the probe can see it.
                # debug config asks a server; with the service disabled each
                # probe starts its own and stops it on exit, instead of leaving
                # the detached background server running in the sandbox.
                export XDG_CONFIG_HOME=$TMPDIR/config XDG_STATE_HOME=$TMPDIR/state XDG_DATA_HOME=$TMPDIR/data
                mkdir -p "$XDG_CONFIG_HOME/opencode"
                printf '{"disabled": true}\n' > "$XDG_CONFIG_HOME/opencode/service.json"
                mkdir -p project
                printf '{"username": "canary-project-config"}\n' > project/opencode.json
                (cd project && ${packaged}/libexec/opencode/opencode debug config) > bare.json
                (cd project && ${packaged}/bin/opencode debug config) > wrapped.json
                # v2 reads OPENCODE_CONFIG_PROJECT_DISABLE first, so a caller's
                # value for it must not turn project config back on either.
                (cd project && OPENCODE_CONFIG_PROJECT_DISABLE=0 ${packaged}/bin/opencode debug config) > wrapped-override.json
                if ! grep -qF canary-project-config bare.json; then
                  echo "opencode debug config no longer reports a project opencode.json; the probe is blind" >&2
                  exit 1
                fi
                if grep -qF canary-project-config wrapped.json; then
                  echo "the pinned opencode loads a project opencode.json despite OPENCODE_DISABLE_PROJECT_CONFIG" >&2
                  exit 1
                fi
                if grep -qF canary-project-config wrapped-override.json; then
                  echo "a caller's OPENCODE_CONFIG_PROJECT_DISABLE=0 turns project config back on through the wrapper" >&2
                  exit 1
                fi
                # A missing pgrep would read as "no server", so its absence fails.
                # A per-run server may take a moment to exit after its client; the
                # detached shared server never does.
                command -v pgrep >/dev/null || { echo "pgrep is missing; the leftover-server probe is blind" >&2; exit 1; }
                for _ in $(seq 50); do
                  pgrep -f ${packaged}/libexec/opencode/opencode >/dev/null || break
                  sleep 0.1
                done
                if pgrep -f ${packaged}/libexec/opencode/opencode; then
                  echo "opencode debug config left a server running despite the disabled service" >&2
                  exit 1
                fi
                touch $out
              '';
          pi-wrapper =
            let
              syntheticKeyFile = "/var/empty/pi-test/synthetic_api_key";
              exaKeyFile = "/var/empty/pi-test/exa_api_key";
              packaged = import ./packages/pi.nix { inherit pkgs syntheticKeyFile exaKeyFile; };
              # Both paths land inside single quotes in a script or a string literal.
              unsafePaths = [
                {
                  label = "a relative path";
                  path = "run/secrets/cli-auth/key";
                }
                {
                  label = "a quote in the path";
                  path = "/run/secrets/bad'path";
                }
                {
                  label = "a space in the path";
                  path = "/run/secrets/bad path";
                }
              ];
              guardCases =
                lib.concatMap
                  (
                    param:
                    map (case: {
                      label = "${case.label} as ${param}";
                      args.${param} = case.path;
                      accept = false;
                    }) unsafePaths
                  )
                  [
                    "syntheticKeyFile"
                    "exaKeyFile"
                  ]
                ++ [
                  {
                    label = "plain absolute key paths";
                    args = {
                      syntheticKeyFile = "/home/test-user/.local/state/cli-auth/synthetic_api_key";
                      exaKeyFile = "/home/test-user/.local/state/cli-auth/exa_api_key";
                    };
                    accept = true;
                  }
                ];
              guardChecks = lib.concatMapStrings (
                case:
                let
                  evaluated = builtins.tryEval (import ./packages/pi.nix ({ inherit pkgs; } // case.args)).drvPath;
                in
                lib.optionalString (evaluated.success != case.accept) ''
                  echo ${lib.escapeShellArg "packages/pi.nix ${if case.accept then "rejects" else "accepts"} ${case.label}"} >&2
                  exit 1
                ''
              ) guardCases;
            in
            pkgs.runCommand "pi-wrapper-tests" { } ''
              export HOME=$TMPDIR
              ${guardChecks}
              mkdir -p scripts tests
              cp ${./scripts/pi} scripts/pi
              cp ${./scripts/pi-synthetic-key} scripts/pi-synthetic-key
              cp ${./tests/pi.sh} tests/pi.sh
              chmod +x scripts/pi scripts/pi-synthetic-key
              patchShebangs scripts
              bash tests/pi.sh scripts/pi scripts/pi-synthetic-key
              bash tests/pi.sh --packaged ${packaged}/bin ${syntheticKeyFile}
              touch $out
            '';
          pi-acp =
            let
              # Records what pi-acp hands Pi, then exits before answering.
              recordingPi = pkgs.writeShellScriptBin "pi" ''
                printf '%s\n' "$@" > "$PI_STUB_LOG/argv"
                env > "$PI_STUB_LOG/env"
                exit 1
              '';
              exitingPi = pkgs.writeShellScriptBin "pi" "exit 0";
              acpxOver =
                pi:
                import ./packages/acpx.nix {
                  inherit pkgs;
                  piAcp = import ./packages/pi-acp.nix { inherit pkgs pi; };
                };
              recording = acpxOver recordingPi;
              packaged = import ./packages/acpx.nix { inherit pkgs; };
              packagedPi = packaged.piAcp.pi;
            in
            pkgs.runCommand "pi-acp-tests" { nativeBuildInputs = [ pkgs.jq ]; } ''
              bash ${./tests/pi-acp.sh} stub ${recording} \
                ${recordingPi}/bin/pi ${recording.piAcp}/libexec/pi-readonly
              bash ${./tests/pi-acp.sh} real ${packaged} ${packagedPi}
              bash ${./tests/pi-acp.sh} mutant ${acpxOver exitingPi} ${packagedPi}
              touch $out
            '';
          lint-staged-markdown =
            let
              miseToml = builtins.fromTOML (builtins.readFile ./mise.toml);
              miseLock = builtins.fromTOML (builtins.readFile ./mise.lock);
              tomlVersion = miseToml.tools."npm:markdownlint-cli2";
              lockVersion = (builtins.head miseLock.tools."npm:markdownlint-cli2").version;
              nixpkgsVersion = pkgs.markdownlint-cli2.version;
              taskRun = miseToml.tasks."lint-staged-markdown".run;
            in
            pkgs.runCommand "lint-staged-markdown-tests"
              {
                nativeBuildInputs = [
                  pkgs.bash
                  pkgs.git
                  pkgs.markdownlint-cli2
                ];
              }
              ''
                export HOME=$TMPDIR
                mkdir -p scripts tests .githooks
                cp ${./scripts/lint-staged-markdown} scripts/lint-staged-markdown
                cp ${./tests/lint-staged-markdown.sh} tests/lint-staged-markdown.sh
                cp ${./.githooks/pre-commit} .githooks/pre-commit
                cp ${./.markdownlint-cli2.jsonc} .markdownlint-cli2.jsonc
                chmod +x scripts/lint-staged-markdown .githooks/pre-commit
                patchShebangs scripts/lint-staged-markdown .githooks/pre-commit tests/lint-staged-markdown.sh

                bash tests/lint-staged-markdown.sh scripts/lint-staged-markdown .githooks/pre-commit .markdownlint-cli2.jsonc "${tomlVersion}" "${lockVersion}" "${nixpkgsVersion}" "${taskRun}"
                touch $out
              '';
          ci-docs-only-paths =
            pkgs.runCommand "ci-docs-only-paths-tests" { nativeBuildInputs = [ pkgs.bash ]; }
              ''
                mkdir -p scripts tests
                cp ${./scripts/ci-docs-only-paths} scripts/ci-docs-only-paths
                cp ${./tests/ci-docs-only-paths.sh} tests/ci-docs-only-paths.sh
                chmod +x scripts/ci-docs-only-paths
                patchShebangs scripts/ci-docs-only-paths
                bash tests/ci-docs-only-paths.sh scripts/ci-docs-only-paths
                touch $out
              '';
          markdown-lint =
            pkgs.runCommand "markdown-lint-tests" { nativeBuildInputs = [ pkgs.markdownlint-cli2 ]; }
              ''
                export HOME=$TMPDIR
                cd ${self}
                markdownlint-cli2
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
          non-nixos-outputs = import ./tests/non-nixos-outputs.nix {
            inherit pkgs self;
            fixtures = linuxFixtures;
          };
          t3code-traits = import ./tests/t3code-traits.nix {
            inherit pkgs self;
            fixtures = linuxFixtures;
          };
        }
        // fixtureChecksFor system;
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
