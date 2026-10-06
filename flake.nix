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
      url = "github:EveryInc/compound-engineering-plugin/compound-engineering-v3.30.3";
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
      # holds host.nix is a non-NixOS host; every other one is a NixOS host.
      hosts = import ./lib/hosts.nix { inherit lib; } ./hosts;

      # Both variants of every non-NixOS host, keyed by output name.
      mkLinuxHost = import ./lib/linux-host.nix { inherit inputs; };
      linuxHosts = lib.listToAttrs (
        lib.concatMap (hosts.withVariants (
          hostName: bootstrap:
          mkLinuxHost {
            inherit hostName bootstrap;
            dir = ./hosts + "/${hostName}";
          }
        )) hosts.linux
      );

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
          "desktop-ssh"
          "emoji-font"
          "iphone-restore"
          "kde-dark-theme"
          "keyd-remap"
          "nix-cleanup"
          "non-nixos-outputs"
          "printing"
          "proton-vpn"
          "thunderbolt"
          "user-avatar"
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
        chatgpt-release = agentTools.chatgptRelease;
        chatgpt = import ./packages/chatgpt.nix { inherit pkgs; };
        claude-code-release = agentTools.claudeCodeRelease;
        claude-code = import ./packages/claude-code.nix { inherit pkgs; };
        mise-release = agentTools.miseRelease;
        mise = import ./packages/mise.nix { inherit pkgs; };
        codex-release = agentTools.codexRelease;
        codex = import ./packages/codex.nix { inherit pkgs; };
        t3code-release = agentTools.t3codeRelease;
        t3code = import ./packages/t3code.nix { inherit pkgs; };
        t3code-cli = import ./packages/t3code-cli.nix { inherit pkgs; };
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
          boot-layout-invariants = import ./tests/boot-layout-invariants.nix { inherit pkgs; };
          keyd-remap = import ./tests/keyd-remap.nix { inherit pkgs self; };
          claude = import ./tests/claude.nix { inherit pkgs self; };
          codex-settings = import ./tests/codex.nix { inherit pkgs self; };
          agent-settings =
            let
              tools = import ./packages/agent-tools.nix { inherit pkgs; };
              inherit (tools) agentSettingsPython;
              packaged = tools.agentSettings;
            in
            pkgs.runCommand "agent-settings-tests" { nativeBuildInputs = [ agentSettingsPython ]; } ''
              export PYTHONDONTWRITEBYTECODE=1
              mkdir -p scripts tests
              cp ${./scripts/agent-settings} scripts/agent-settings
              cp ${./tests/test_agent_settings.py} tests/test_agent_settings.py
              python tests/test_agent_settings.py

              # Activation runs the packaged binary, not this source copy, and its
              # unit's PATH carries no python3. Exercise the built file so a lost
              # +x bit or an unpatched `#!/usr/bin/env python3` fails here rather
              # than on the laptop.
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
              # starts stale with an extra event, and Orca's entry beside it must
              # come through byte for byte.
              mkdir -p home/.gemini/config
              printf '{"orca-status":{"enabled":true,"Stop":[{"type":"command","command":"orca-hook","timeout":10}]},"repo-owned":{"enabled":false,"Stop":[]}}\n' \
                > home/.gemini/config/hooks.json
              printf '{"own":{"repo-owned":{"enabled":true,"SessionStart":[{"type":"command","command":"x","timeout":10}]}}}\n' \
                > owned.json
              env -i ${packaged}/bin/agent-settings --label 'Antigravity hooks' \
                --settings "$PWD/home/.gemini/config/hooks.json" --declared "$PWD/owned.json"
              ${pkgs.python3}/bin/python3 - <<'PY'
              import json
              merged = json.load(open('home/.gemini/config/hooks.json'))
              assert merged['orca-status'] == {'enabled': True, 'Stop': [{'type': 'command', 'command': 'orca-hook', 'timeout': 10}]}, merged
              assert merged['repo-owned'] == {'enabled': True, 'SessionStart': [{'type': 'command', 'command': 'x', 'timeout': 10}]}, merged
              PY

              # TOML mode through the packaged binary, which proves the built
              # interpreter carries tomlkit: a comment and a table the merge does
              # not own must survive, and the declared leaves start divergent.
              mkdir -p home/.codex
              printf '# keep me\ncheck_for_update_on_startup = true\n\n[features]\nmemories = true\n\n[plugins."x"]\nenabled = true\n' \
                > home/.codex/config.toml
              printf '{"setPaths":[{"path":["check_for_update_on_startup"],"value":false},{"path":["features","memories"],"value":false},{"path":["features","daemon_auto_start"],"value":false}]}\n' \
                > codex.json
              env -i ${packaged}/bin/agent-settings --format toml --label Codex \
                --settings "$PWD/home/.codex/config.toml" --declared "$PWD/codex.json"
              grep -qxF '# keep me' home/.codex/config.toml
              ${pkgs.python3}/bin/python3 - <<'PY'
              import tomllib
              merged = tomllib.load(open('home/.codex/config.toml', 'rb'))
              assert merged == {'check_for_update_on_startup': False, 'features': {'memories': False, 'daemon_auto_start': False}, 'plugins': {'x': {'enabled': True}}}, merged
              PY

              # Malformed TOML must fail the process and leave the file alone.
              printf 'model = "unterminated\n' > home/.codex/config.toml
              if env -i ${packaged}/bin/agent-settings --format toml --label Codex \
                  --settings "$PWD/home/.codex/config.toml" --declared "$PWD/codex.json"; then
                echo "packaged merger accepted malformed TOML" >&2
                exit 1
              fi
              if [ "$(cat home/.codex/config.toml)" != 'model = "unterminated' ]; then
                echo "refused TOML merge still rewrote the settings file" >&2
                exit 1
              fi

              touch $out
            '';
          gemini = import ./tests/gemini.nix { inherit pkgs self; };
          ghq = import ./tests/ghq.nix { inherit pkgs self; };
          git-lfs = import ./tests/git-lfs.nix { inherit pkgs self; };
          git-trim = import ./tests/git-trim.nix { inherit pkgs self; };
          shell-utilities = import ./tests/shell-utilities.nix { inherit pkgs self; };
          mise-settings = import ./tests/mise-settings.nix { inherit pkgs self; };
          nix-cleanup = import ./tests/nix-cleanup.nix { inherit pkgs self; };
          boot-splash = import ./tests/boot-splash.nix { inherit pkgs self; };
          agent-plugins = import ./tests/agent-plugins.nix { inherit pkgs self; };
          retire-orca-skills = import ./tests/retire-orca-skills.nix { inherit pkgs self; };
          agent-instructions = import ./tests/agent-instructions.nix { inherit pkgs self; };
          agent-plugin-sync =
            pkgs.runCommand "agent-plugin-sync-tests" { nativeBuildInputs = [ pkgs.python3 ]; }
              ''
                export PYTHONDONTWRITEBYTECODE=1
                mkdir -p scripts tests
                cp ${./scripts/agent-plugin-sync} scripts/agent-plugin-sync
                cp ${./tests/test_agent_plugin_sync.py} tests/test_agent_plugin_sync.py
                python tests/test_agent_plugin_sync.py
                touch $out
              '';
          agent-plugin-release =
            pkgs.runCommand "agent-plugin-release-tests" { nativeBuildInputs = [ pkgs.python3 ]; }
              ''
                export PYTHONDONTWRITEBYTECODE=1
                mkdir -p scripts tests
                cp ${./scripts/agent-plugin-release} scripts/agent-plugin-release
                cp ${./tests/test_agent_plugin_release.py} tests/test_agent_plugin_release.py
                python tests/test_agent_plugin_release.py
                touch $out
              '';
          claude-desktop-release =
            pkgs.runCommand "claude-desktop-release-tests" { nativeBuildInputs = [ pkgs.python3 ]; }
              ''
                export PYTHONDONTWRITEBYTECODE=1
                mkdir -p scripts tests
                cp ${./scripts/claude-desktop-release} scripts/claude-desktop-release
                cp ${./tests/test_claude_desktop_release.py} tests/test_claude_desktop_release.py
                python tests/test_claude_desktop_release.py
                touch $out
              '';
          chatgpt-release =
            pkgs.runCommand "chatgpt-release-tests" { nativeBuildInputs = [ pkgs.python3 ]; }
              ''
                export PYTHONDONTWRITEBYTECODE=1
                mkdir -p scripts tests
                cp ${./scripts/chatgpt-release} scripts/chatgpt-release
                cp ${./tests/test_chatgpt_release.py} tests/test_chatgpt_release.py
                python tests/test_chatgpt_release.py
                touch $out
              '';
          claude-code-release =
            pkgs.runCommand "claude-code-release-tests" { nativeBuildInputs = [ pkgs.python3 ]; }
              ''
                export PYTHONDONTWRITEBYTECODE=1
                mkdir -p scripts tests
                cp ${./scripts/claude-code-release} scripts/claude-code-release
                cp ${./tests/test_claude_code_release.py} tests/test_claude_code_release.py
                python tests/test_claude_code_release.py
                touch $out
              '';
          mise-release = pkgs.runCommand "mise-release-tests" { nativeBuildInputs = [ pkgs.python3 ]; } ''
            export PYTHONDONTWRITEBYTECODE=1
            mkdir -p scripts tests
            cp ${./scripts/mise-release} scripts/mise-release
            cp ${./tests/test_mise_release.py} tests/test_mise_release.py
            python tests/test_mise_release.py
            touch $out
          '';
          codex-release = pkgs.runCommand "codex-release-tests" { nativeBuildInputs = [ pkgs.python3 ]; } ''
            export PYTHONDONTWRITEBYTECODE=1
            mkdir -p scripts tests
            cp ${./scripts/codex-release} scripts/codex-release
            cp ${./tests/test_codex_release.py} tests/test_codex_release.py
            python tests/test_codex_release.py
            touch $out
          '';
          t3code-release = pkgs.runCommand "t3code-release-tests" { nativeBuildInputs = [ pkgs.python3 ]; } ''
            export PYTHONDONTWRITEBYTECODE=1
            mkdir -p scripts tests
            cp ${./scripts/t3code-release} scripts/t3code-release
            cp ${./tests/test_t3code_release.py} tests/test_t3code_release.py
            python tests/test_t3code_release.py
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
          pam-fingerprint = import ./tests/pam-fingerprint.nix { inherit pkgs self; };
          enroll-fingerprint =
            let
              fingerprint = configurations.withTrait "my.fingerprint.enable" (
                config: config.my.fingerprint.enable
              );

              # The configuration's own copy, not a fresh build of the package
              # file: a module that stopped installing the helper would otherwise
              # leave this check green while the system ships an enrollment PAM
              # service and no program that uses it. Whether a configuration
              # should ship it comes from the trait and the bootstrap flag, never
              # from the module under test.
              assertConfiguration =
                entry:
                let
                  expected = entry.config.my.fingerprint.enable && !entry.bootstrap;
                  packaged = pkgs.lib.lists.findFirst (
                    p: (p.pname or "") == "enroll-fingerprint"
                  ) null entry.config.environment.systemPackages;
                in
                if !expected then
                  pkgs.lib.optionalString (packaged != null) ''
                    echo 'an enroll-fingerprint package reaches the system path on ${entry.name}, whose trait or bootstrap flag withholds it' >&2
                    fail=1
                  ''
                else
                  ''
                    ${pkgs.lib.optionalString (packaged == null) ''
                      echo "no enroll-fingerprint package reaches the system path on ${entry.name}" >&2
                      fail=1
                    ''}
                    ${pkgs.lib.optionalString (packaged != null) ''
                      helper=${packaged}/bin/enroll-fingerprint
                      configuration=${entry.name}
                      assert_line 'PAMTESTER="${pkgs.pamtester}/bin/pamtester"'
                      assert_line 'FPRINTD_ENROLL="${pkgs.fprintd}/bin/fprintd-enroll"'
                      assert_line 'FPRINTD_LIST="${pkgs.fprintd}/bin/fprintd-list"'
                      assert_line 'SUDO="/run/wrappers/bin/sudo"'
                      assert_line 'PAM_SERVICE=enroll-fingerprint'
                      test -x ${pkgs.pamtester}/bin/pamtester || {
                        echo "the authenticator the helper names is not executable on ${entry.name}" >&2
                        fail=1
                      }

                      # A mutation that deletes a substitution line reddens the
                      # package derivation itself, via --replace-fail, so it never
                      # reaches these assertions. The mutation that exercises them is
                      # substituting a constant for the wrong store path.
                      if grep -qE '@[A-Z_]+@' "$helper"; then
                        echo "packaged helper still carries an unsubstituted placeholder on ${entry.name}" >&2
                        grep -nE '@[A-Z_]+@' "$helper" >&2
                        fail=1
                      fi
                      interpreter=$(head -1 "$helper")
                      case "$interpreter" in
                        '#!'/nix/store/*) ;;
                        *)
                          echo "packaged helper must carry a store interpreter on ${entry.name}, got: $interpreter" >&2
                          fail=1
                          ;;
                      esac

                      # Run it once, so a helper that cannot execute at all is
                      # distinguishable from one that merely reads correctly.
                      if "$helper" --nonsense >/dev/null 2>&1; then
                        echo "packaged helper accepted an unknown argument on ${entry.name}" >&2
                        fail=1
                      elif [ $? -ne 2 ]; then
                        echo "packaged helper did not reject an unknown argument with status 2 on ${entry.name}" >&2
                        fail=1
                      fi
                    ''}
                  '';
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
                # sees the built file. Activation runs the built one, and what
                # matters there is not that substitution happened but WHAT it
                # produced: asserting only the absence of a placeholder would pass
                # a package that substituted the authenticator for coreutils'
                # `true`, and the installed helper would enroll with no password
                # at all while every check stayed green.
                assert_line() {
                  grep -qxF "$1" "$helper" || {
                    echo "packaged helper is missing the line on $configuration: $1" >&2
                    fail=1
                  }
                }
                ${fingerprint.guard}
                ${forEveryConfiguration assertConfiguration}

                touch $out
              '';
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
          android-sdk = import ./tests/android-sdk.nix { inherit pkgs self; };
          session-variables = import ./tests/session-variables.nix {
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
                  if ! printf '%s\n' ${pkgs.lib.escapeShellArg dotzshenv} | grep -qF ${pkgs.lib.escapeShellArg "source ${zshenv}"}; then
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
                      ]
                  )}
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
          orca-desktop =
            let
              assertConfiguration =
                entry:
                let
                  service = entry.user.systemd.user.services.orca-settings-reconcile or null;
                  activation = entry.user.home.activation.orcaSettings or null;
                  package = userPackageOf "orca-ide" entry;
                  dockerHost = entry.user.home.sessionVariables.DOCKER_HOST or "";
                  fakeRuntimeDir = "/run/user/4242";
                in
                ''
                  ${assertUserPackage {
                    pname = "orca-ide";
                    executables = [
                      "orca-ide"
                      "orca"
                    ];
                    desktopEntries = [ "orca.desktop" ];
                  } entry}
                  ${pkgs.lib.optionalString (package != null) ''
                    # Expand both values under one runtime directory, so a path
                    # baked in at build time cannot match the session's socket.
                    containerHost=$(
                      XDG_RUNTIME_DIR=${fakeRuntimeDir}
                      line=$(grep -E '^[[:space:]]*--setenv CONTAINER_HOST ' ${package}/bin/orca-ide) || exit 0
                      eval "set -- $line"
                      printf '%s' "$3"
                    )
                    dockerHost=$(
                      XDG_RUNTIME_DIR=${fakeRuntimeDir}
                      printf '%s' "${pkgs.lib.escape [ "\"" "\\" "`" ] dockerHost}"
                    )
                    if [ -z "$containerHost" ] || [ "$containerHost" != "$dockerHost" ] \
                      || [ "$containerHost" = "''${containerHost#*${fakeRuntimeDir}/}" ]; then
                      echo "orca-ide sandbox CONTAINER_HOST '$containerHost' is not the session Podman socket '$dockerHost' on ${entry.name}" >&2
                      fail=1
                    fi
                  ''}
                  ${pkgs.lib.optionalString (service != null) ''
                    echo 'unexpected systemd.user.services.orca-settings-reconcile on ${entry.name}' >&2
                    fail=1
                  ''}
                  ${pkgs.lib.optionalString (activation != null) ''
                    echo 'unexpected home.activation.orcaSettings on ${entry.name}' >&2
                    fail=1
                  ''}
                '';
            in
            pkgs.runCommand "orca-desktop-tests" { } ''
              set -x
              ${forEveryConfiguration assertConfiguration}
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
          chatgpt =
            let
              # No version-pin comparison: the package reads its version from the
              # pin file, so that assertion could only ever hold. The wrapper is
              # read for an ozone flag because upstream marks Wayland
              # experimental; the app must stay on its X11 default. The
              # bundled static binaries are run, because a patched one still
              # exists and is executable.
              assertConfiguration =
                entry:
                let
                  chatgptPkg = userPackageOf "chatgpt" entry;
                in
                ''
                  ${assertUserPackage {
                    pname = "chatgpt";
                    executables = [ "chatgpt" ];
                    desktopEntries = [ "chatgpt.desktop" ];
                  } entry}
                  ${pkgs.lib.optionalString (chatgptPkg != null) ''
                    if grep -q -- 'ozone' ${chatgptPkg}/bin/chatgpt; then
                      echo 'the chatgpt wrapper on ${entry.name} carries an ozone flag' >&2
                      fail=1
                    fi
                    # The bundled Codex sandboxes with bwrap, which NixOS has nowhere
                    # else on PATH.
                    if ! grep -qF -- '-bubblewrap-' ${chatgptPkg}/bin/chatgpt; then
                      echo 'the chatgpt wrapper on ${entry.name} puts no bubblewrap on PATH' >&2
                      fail=1
                    fi
                    # Run, not just inspect: autoPatchelf adding a runpath to these
                    # static-pie binaries leaves them segfaulting while every file
                    # still exists.
                    for binary in codex rg; do
                      if ! HOME="$TMPDIR" ${chatgptPkg}/lib/chatgpt/resources/$binary --version > /dev/null 2>&1; then
                        echo "the bundled $binary in chatgpt on ${entry.name} does not run" >&2
                        fail=1
                      fi
                    done
                  ''}
                '';
            in
            pkgs.runCommand "chatgpt-tests" { } ''
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
          codex =
            let
              # The version attribute is compared with the pin for the reason
              # given on the claude-code check: versionCheckHook already proves
              # the binary reports that attribute. The wrapper flags are read
              # from the installed bin/codex itself, because they are what keep
              # Codex from updating itself under Orca's CODEX_HOME, which never
              # receives the declared config.toml keys.
              pinnedVersion = (builtins.fromJSON (builtins.readFile ./packages/codex-release.json)).version;
              wrapperFlags = [
                "-c check_for_update_on_startup=false"
                "--disable in_app_updates"
                "--disable daemon_auto_start"
              ];
              assertConfiguration =
                entry:
                let
                  codexPkg = userPackageOf "codex" entry;
                  versionMismatch = pkgs.lib.optionalString (codexPkg != null && codexPkg.version != pinnedVersion) ''
                    echo "codex on ${entry.name} is built from version '${codexPkg.version}', expected pin ${pinnedVersion}" >&2
                    fail=1
                  '';
                  flagsMissing = pkgs.lib.optionalString (codexPkg != null) ''
                    for flag in ${pkgs.lib.escapeShellArgs wrapperFlags}; do
                      if ! grep -qF -- "$flag" ${codexPkg}/bin/codex; then
                        echo "codex on ${entry.name} lacks the wrapper flag $flag" >&2
                        fail=1
                      fi
                    done
                  '';
                  # Codex looks for codex-code-mode-host beside the binary the
                  # wrapper execs, never on PATH, so the host is found from that
                  # exec target. It is run, not just inspected, as the chatgpt
                  # check does for its bundled binaries.
                  codeModeHostMissing = pkgs.lib.optionalString (codexPkg != null) ''
                    target=$(sed -nE 's/^exec (-a "\$0" )?"([^"]+)".*/\2/p' ${codexPkg}/bin/codex)
                    if [ -z "$target" ]; then
                      echo "the codex wrapper on ${entry.name} execs no binary this check can find" >&2
                      fail=1
                    elif ! "$(dirname "$target")/codex-code-mode-host" --help > /dev/null 2>&1; then
                      echo "codex on ${entry.name} has no runnable codex-code-mode-host beside $target" >&2
                      fail=1
                    fi
                  '';
                in
                ''
                  ${assertUserPackage {
                    pname = "codex";
                    executables = [ "codex" ];
                    desktopEntries = [ ];
                  } entry}
                  ${versionMismatch}
                  ${flagsMissing}
                  ${codeModeHostMissing}
                '';
            in
            pkgs.runCommand "codex-tests" { } ''
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

              # Expanded under a fake runtime directory, as the orca-desktop
              # check does, so a path baked in at build time cannot match.
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
          kde-dark-theme = import ./tests/kde-dark-theme.nix { inherit pkgs self; };
          emoji-font = import ./tests/emoji-font.nix { inherit pkgs self; };
          user-avatar = import ./tests/user-avatar.nix { inherit pkgs self; };
          logind-lid-switch = import ./tests/logind-lid-switch.nix { inherit pkgs self; };
          logitech-wakeup = import ./tests/logitech-wakeup.nix { inherit pkgs self; };
          udev-device-access = import ./tests/udev-device-access.nix { inherit pkgs self; };
          kernel-sysctl = import ./tests/kernel-sysctl.nix { inherit pkgs self; };
          proton-vpn = import ./tests/proton-vpn.nix { inherit pkgs self; };
          wireplumber-bluetooth = import ./tests/wireplumber-bluetooth.nix { inherit pkgs self; };
          thunderbolt = import ./tests/thunderbolt.nix { inherit pkgs self; };
          iphone-restore = import ./tests/iphone-restore.nix { inherit pkgs self; };
          printing = import ./tests/printing.nix { inherit pkgs self; };
          winbox = import ./tests/winbox.nix { inherit pkgs self; };
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
          inherit (import ./tests/non-nixos-scripts.nix { inherit pkgs; }) install-user-age-identity nr-linux;
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
