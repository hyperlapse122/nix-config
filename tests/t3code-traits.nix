/*
  Check interface:

    import ./tests/t3code-traits.nix { inherit pkgs self fixtures; }

  `fixtures` is tests/lib/linux-fixtures.nix. Guards the two T3 Code traits,
  my.t3.cli.enable and my.t3.desktop.enable, which home/h82/t3code.nix turns
  into user packages.

  On every NixOS configuration, production and bootstrap, and on each
  production configuration re-evaluated with one trait forced off, the
  materialized user profile (home.path, which useUserPackages makes the
  per-user profile) is read rather than the package list:
  - bin/t3 resolves into the t3code-cli package exactly when the CLI trait is
    on;
  - share/applications/t3code.desktop and bin/t3code-desktop resolve into the
    t3code-desktop package exactly when the desktop trait is on;
  - nothing else on PATH comes from a T3 Code package, so T3 Code brings no
    codex or claude of its own and its sessions run the flake's.
  - home.activation.t3codeSettings and home.activation.t3codeClientSettings
    exist exactly when either trait is on and run after installPackages. Each
    script is executed with the packaged merger swapped for a stub that
    records its arguments: on a live run the stub must run with its file under
    ~/.t3/userdata, which the desktop app and the CLI share (settings.json and
    client-settings.json), and a declaration equal to one rendered here, the
    settings that differ from the pinned T3 Code's defaults; a failing stub
    must fail the script; and with Home Manager's `run` turned into a no-op,
    as on a dry run, the stub must not run. T3 Code rewrites both files at
    runtime, so the keys are merged rather than the files owned.
  - home.activation.t3codeAntigravity exists exactly when either trait is on
    and runs after installPackages. Its script is executed the same way with
    the packaged installer swapped for a stub: on a live run the stub must
    run with --base-dir ~/.t3, --runtime in the antigravity-acp package this
    system pins, and --pin the pin record of packages/t3code-release.json for
    this system; a failing stub must fail the script; and a dry run must not
    run it. The paths are compared as strings, so the runtime, about 1.3 GB
    unpacked, is never built here.
  The same holds on each non-NixOS fixture host of the builder's
  architecture, production and bootstrap, and on each bootstrap fixture
  re-assembled with only the CLI trait forced on, since the CLI is the T3
  Code those hosts support.
  Today every NixOS configuration enables both traits, so the forced-off
  configurations, including one per production configuration with both traits
  off, are what keep each "exactly when" from passing on the positive side
  alone. Some production and some bootstrap configuration must enable each
  trait.

  On every non-NixOS fixture host's bootstrap variant, re-assembled through
  lib/linux-host.nix with my.t3.desktop.enable forced on, Home Manager
  refuses to evaluate, while the fixture as declared evaluates. Home Manager
  throws on a failed assertion before its output can be read, so
  home/h82/t3code.nix is also evaluated on its own: on a non-NixOS Linux kind
  its assertion reports that the desktop app runs on NixOS and macOS only and
  the desktop package is not added; on NixOS nothing fails and the package is
  added; on macOS nothing fails, the package is added, and a launchd agent
  sets T3CODE_DISABLE_AUTO_UPDATE=1 for GUI launches, which NixOS does not get.
  On NixOS and macOS the module also declares both settings merges, checked
  the same way as on the assembled configurations, since no macOS
  configuration is evaluated here.

  Every failure is collected in one build and names the configuration.
*/
{
  pkgs,
  self,
  fixtures,
}:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self fixtures; };

  esc = value: lib.escapeShellArg (toString value);

  fail = message: ''
    echo ${esc message} >&2
    fail=1
  '';

  cliEnabled = config: config.my.t3.cli.enable;
  desktopEnabled = config: config.my.t3.desktop.enable;

  cliTrait = configurations.withTrait "my.t3.cli.enable" cliEnabled;
  desktopTrait = configurations.withTrait "my.t3.desktop.enable" desktopEnabled;

  bootstrapGuard =
    label: predicate:
    lib.optionalString (!lib.any (entry: predicate entry.config) configurations.bootstraps) (
      fail "no bootstrap configuration enables ${label}, so the bootstrap profile is never checked for it"
    );

  # Each trait forced off alone leaves the other on, so the settings merge
  # needs configurations with both off for its negative side. Their profiles
  # are not read: the single-trait configurations already cover each package,
  # and reading them would build another home.path per host.
  bothOff = map (
    entry:
    configurations.entryOf "${entry.name} with both T3 Code traits forced off" (
      self.nixosConfigurations.${entry.name}.extendModules {
        modules = [
          {
            my.t3.cli.enable = lib.mkForce false;
            my.t3.desktop.enable = lib.mkForce false;
          }
        ];
      }
    )
  ) configurations.production;

  profileEntries = configurations.entries ++ cliTrait.disabled ++ desktopTrait.disabled;

  # Rendered here rather than read back from the module, so a mutation of the
  # declaration turns the check red. Scalars are assigned, objects T3 Code
  # may extend are declared leaf by leaf, and the model selections, which T3
  # Code writes whole, are owned whole.
  settingsExpected = pkgs.writeText "t3code-expected-settings.json" (
    builtins.toJSON {
      set = {
        addProjectBaseDirectory = "~/src";
        autoResumeLimitedThreads = true;
        branchNamingMode = "semantic";
        defaultAutoPull = true;
        defaultThreadEnvMode = "worktree";
        enableAgentDeviceAccess = true;
        enableDeviceSupport = true;
        snoozeLimitedThreads = true;
      };
      setPaths = [
        {
          path = [
            "providers"
            "antigravity"
            "enabled"
          ];
          value = true;
        }
        {
          path = [
            "sourceControlWritingStyle"
            "mode"
          ];
          value = "conventional_commits";
        }
        {
          path = [
            "storageCleanup"
            "browserArtifactsAfterDays"
          ];
          value = 8;
        }
        {
          path = [
            "storageCleanup"
            "logsAfterDays"
          ];
          value = 8;
        }
        {
          path = [
            "storageCleanup"
            "worktreeAfterDays"
          ];
          value = 8;
        }
        {
          path = [
            "storageCleanup"
            "worktreeOnDelete"
          ];
          value = true;
        }
        {
          path = [
            "storageCleanup"
            "worktreeOnMerge"
          ];
          value = true;
        }
        {
          path = [
            "storageCleanup"
            "worktreeUnchanged"
          ];
          value = true;
        }
      ];
      own = {
        defaultModelSelection = {
          instanceId = "claudeAgent";
          model = "claude-opus-5-5";
        };
        textGenerationModelSelection = {
          instanceId = "antigravity";
          model = "gemini-3.8-flash-low";
        };
      };
    }
  );

  clientSettingsExpected = pkgs.writeText "t3code-expected-client-settings.json" (
    builtins.toJSON {
      set.fontFamilyCode = "JetBrains Mono";
      setPaths = [ ];
      own = { };
    }
  );

  # Without string context, so neither the runtime nor the scripts the
  # activation names are built: the check compares the paths, and the paths
  # are the store hashes of what the module would install.
  noContext = builtins.unsafeDiscardStringContext;
  releasePin = builtins.fromJSON (builtins.readFile ../packages/t3code-release.json);
  runtimeExpected = noContext "${
    import ../packages/antigravity-acp.nix { inherit pkgs; }
  }/libexec/antigravity-acp";
  pinExpected = noContext "${pkgs.writeText "antigravity-acp-pin.json" (
    builtins.toJSON (releasePin.antigravity.${pkgs.stdenv.hostPlatform.system} or { })
  )}";

  merges = [
    {
      attr = "t3codeSettings";
      file = "settings.json";
      expected = settingsExpected;
    }
    {
      attr = "t3codeClientSettings";
      file = "client-settings.json";
      expected = clientSettingsExpected;
    }
  ];

  # Every lookup has an `or` fallback, so a removed declaration reaches the
  # builder as an empty argument instead of failing evaluation.
  assertSettings =
    name: user: expected:
    lib.concatMapStrings (
      merge:
      let
        activation = user.home.activation.${merge.attr} or null;
      in
      ''
        checkSettings ${esc name} ${merge.attr} ${lib.boolToString expected} ${
          lib.boolToString (activation != null)
        } ${esc (activation.data or "")} ${
          lib.boolToString (lib.elem "installPackages" (activation.after or [ ]))
        } ${esc "${user.home.homeDirectory or ""}/.t3/userdata/${merge.file}"} ${merge.expected}
      ''
    ) merges
    + (
      let
        activation = user.home.activation.t3codeAntigravity or null;
      in
      ''
        checkRuntime ${esc name} ${lib.boolToString expected} ${lib.boolToString (activation != null)} ${
          esc (noContext (activation.data or ""))
        } ${
          lib.boolToString (lib.elem "installPackages" (activation.after or [ ]))
        } ${esc "${user.home.homeDirectory or ""}/.t3"}
      ''
    );

  assertSettingsOn =
    entry:
    assertSettings entry.name entry.user (cliEnabled entry.config || desktopEnabled entry.config);

  assertProfile = entry: ''
    checkProfile ${esc entry.name} ${
      esc (entry.user.home.path or "")
    } ${lib.boolToString (cliEnabled entry.config)} ${lib.boolToString (desktopEnabled entry.config)}
    ${assertSettingsOn entry}
  '';

  desktopMessage = "the T3 Code desktop app runs on NixOS and macOS only";

  # Home Manager throws on a failed assertion before any part of the output
  # can be read, so an assembled fixture can only show that evaluation is
  # refused. The same fixture without the trait must evaluate, so the refusal
  # is the trait's. Only bootstrap variants are re-assembled: production needs
  # the fixtures' fake secrets, and without them it fails on its own.
  evaluates = home: (builtins.tryEval home.config.home.username).success;

  mkLinuxHost = import ../lib/linux-host.nix { inherit (self) inputs; };

  assertFixture =
    entry:
    let
      forced = mkLinuxHost {
        hostName = entry.fixture;
        dir = ./fixtures/hosts + "/${entry.fixture}";
        bootstrap = true;
        extraModules.home = [ { my.t3.desktop.enable = true; } ];
      };
    in
    lib.concatStrings [
      (lib.optionalString (!evaluates entry.host.home) (
        fail "${entry.name}: the fixture as declared does not evaluate"
      ))
      (lib.optionalString (evaluates forced.home) (
        fail "${entry.name} with my.t3.desktop.enable forced on: Home Manager evaluates instead of refusing the desktop app"
      ))
    ];

  # The CLI is the T3 Code a non-NixOS host supports, and no fixture of every
  # architecture enables it, so the merge's positive side is checked on a
  # bootstrap fixture with the CLI forced on. Only this architecture's
  # fixtures, because the activation script interpolates their store paths.
  assertFixtureCli =
    entry:
    let
      forced = mkLinuxHost {
        hostName = entry.fixture;
        dir = ./fixtures/hosts + "/${entry.fixture}";
        bootstrap = true;
        extraModules.home = [
          {
            my.t3.cli.enable = lib.mkForce true;
            my.t3.desktop.enable = lib.mkForce false;
          }
        ];
      };
    in
    assertSettings "${entry.name} with only my.t3.cli.enable forced on" forced.home.config true;

  # The module reaches lib.hm, which only Home Manager's extended lib carries.
  hmLib = import "${self.inputs.home-manager}/modules/lib/stdlib-extended.nix" lib;

  # The module on its own, so the assertion's message and the packages it
  # would otherwise let through can be read. NixOS is the control: there the
  # desktop app installs and nothing fails.
  moduleOn =
    kind:
    let
      config =
        (hmLib.evalModules {
          specialArgs = { inherit pkgs; };
          modules = [
            ../modules/shared/host.nix
            ../home/h82/t3code.nix
            {
              options.assertions = lib.mkOption {
                type = lib.types.listOf lib.types.unspecified;
                default = [ ];
              };
              options.home.packages = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [ ];
              };
              options.launchd.agents = lib.mkOption {
                type = lib.types.attrsOf lib.types.unspecified;
                default = { };
              };
              options.home.activation = lib.mkOption {
                type = lib.types.attrsOf lib.types.unspecified;
                default = { };
              };
              options.home.homeDirectory = lib.mkOption {
                type = lib.types.str;
                default = "/home/probe";
              };
              config.my = {
                hostName = "probe";
                inherit kind;
                t3.desktop.enable = true;
              };
            }
          ];
        }).config;
    in
    {
      inherit config;
      failed = map (a: a.message) (lib.filter (a: !a.assertion) config.assertions);
      desktopInstalled = lib.elem "t3code-desktop" (map lib.getName config.home.packages);
      updaterOff =
        let
          agent = config.launchd.agents.t3code-disable-auto-update or { };
        in
        (agent.enable or false)
        &&
          (agent.config.ProgramArguments or [ ]) == [
            "/bin/launchctl"
            "setenv"
            "T3CODE_DISABLE_AUTO_UPDATE"
            "1"
          ];
    };

  assertModule =
    let
      linux = moduleOn "linux";
      nixos = moduleOn "nixos";
      darwin = moduleOn "darwin";
    in
    lib.concatStrings [
      (lib.optionalString (!lib.any (lib.hasInfix desktopMessage) linux.failed) (
        fail "non-NixOS with my.t3.desktop.enable: no assertion reports that ${desktopMessage}; failed assertions: ${builtins.toJSON linux.failed}"
      ))
      (lib.optionalString linux.desktopInstalled (
        fail "non-NixOS with my.t3.desktop.enable: the T3 Code desktop package is added, so the host fails a build rather than the assertion"
      ))
      (lib.optionalString (nixos.failed != [ ]) (
        fail "NixOS with my.t3.desktop.enable: assertions fail: ${builtins.toJSON nixos.failed}"
      ))
      (lib.optionalString (!nixos.desktopInstalled) (
        fail "NixOS with my.t3.desktop.enable: the T3 Code desktop package is not added"
      ))
      (lib.optionalString nixos.updaterOff (
        fail "NixOS with my.t3.desktop.enable: the macOS updater-off launchd agent is declared"
      ))
      (lib.optionalString (darwin.failed != [ ]) (
        fail "macOS with my.t3.desktop.enable: assertions fail: ${builtins.toJSON darwin.failed}"
      ))
      (lib.optionalString (!darwin.desktopInstalled) (
        fail "macOS with my.t3.desktop.enable: the T3 Code desktop package is not added"
      ))
      (lib.optionalString (!darwin.updaterOff) (
        fail "macOS with my.t3.desktop.enable: no launchd agent runs launchctl setenv T3CODE_DISABLE_AUTO_UPDATE 1, so the copied app can update itself off the nightly pin"
      ))
      (assertSettings "NixOS module with my.t3.desktop.enable" nixos.config true)
      (assertSettings "macOS module with my.t3.desktop.enable" darwin.config true)
    ];
in
pkgs.runCommand "t3code-traits" { } ''
  fail=0
  ${configurations.guard}
  ${cliTrait.guard}
  ${desktopTrait.guard}
  ${bootstrapGuard "my.t3.cli.enable" cliEnabled}
  ${bootstrapGuard "my.t3.desktop.enable" desktopEnabled}
  ${lib.optionalString (fixtures == [ ]) (fail "tests/fixtures/hosts holds no fixture host")}

  # True when $1 exists and resolves into a store path of package $2.
  resolvesInto() {
    [ -e "$1" ] || return 1
    case $(readlink -f "$1") in
      /nix/store/*-"$2"-*) return 0 ;;
    esac
    return 1
  }

  # Fails unless $3 resolving into package $4 matches the trait value $5.
  expectPresence() {
    local name=$1 what=$2 path=$3 pkg=$4 expected=$5 trait=$6 present=false
    resolvesInto "$path" "$pkg" && present=true
    if [ "$present" != "$expected" ]; then
      echo "$name: $what is present=$present, $trait is $expected" >&2
      fail=1
    fi
  }

  checkProfile() {
    local name=$1 profile=$2 cli=$3 desktop=$4 target exe
    if [ -z "$profile" ] || [ ! -d "$profile" ]; then
      echo "$name: Home Manager renders no home.path" >&2
      fail=1
      return
    fi

    expectPresence "$name" "bin/t3 from t3code-cli" "$profile/bin/t3" t3code-cli "$cli" my.t3.cli.enable
    expectPresence "$name" "the t3code.desktop entry" "$profile/share/applications/t3code.desktop" t3code-desktop "$desktop" my.t3.desktop.enable
    expectPresence "$name" "bin/t3code-desktop" "$profile/bin/t3code-desktop" t3code-desktop "$desktop" my.t3.desktop.enable

    for exe in "$profile"/bin/*; do
      target=$(readlink -f "$exe")
      case $target in
        /nix/store/*-t3code-cli-* | /nix/store/*-t3code-desktop-*)
          case ''${exe##*/} in
            t3 | t3code-desktop) ;;
            *)
              echo "$name: bin/''${exe##*/} on PATH comes from a T3 Code package ($target)" >&2
              fail=1
              ;;
          esac
          ;;
      esac
    done
  }

  # Stands in for the packaged merger: records one argument per line and exits
  # with STUB_STATUS.
  cat > merger-stub <<'EOF'
  #!${pkgs.runtimeShell}
  printf '%s\n' "$@" > "$STUB_ARGS"
  exit "''${STUB_STATUS:-0}"
  EOF
  chmod +x merger-stub

  # Runs the activation script in `script`, with the merger swapped for the
  # stub, under Home Manager's shell options. $1 defines `run`: "$@" on a live
  # run, nothing on a dry run. $2 is the stub's exit status.
  exercise() {
    rm -f args
    { printf 'run() { %s; }\n' "$1"; cat swapped; } > exercise.sh
    STUB_ARGS=$PWD/args STUB_STATUS=$2 bash -eu -o pipefail exercise.sh
  }

  # Prints the argument that follows $1 in the stub's recorded arguments.
  argAfter() {
    awk -v flag="$1" 'previous == flag { print; exit } { previous = $0 }' args
  }

  # $2 names the activation entry, $3 says whether the merge belongs on this
  # configuration, $4 whether it is declared; $5 is its script, $6 whether it
  # runs after installPackages, $7 the settings file it must name, and $8 the
  # declaration it must pass. The script is executed rather than
  # matched, so a merger that is only mentioned, echoed, or has its exit
  # status swallowed fails.
  checkSettings() {
    local name=$1 attr=$2 expected=$3 present=$4 after=$6 settings=$7 want=$8 merger actual declared
    if [ "$present" != "$expected" ]; then
      echo "$name: home.activation.$attr is present=$present, either T3 Code trait on is $expected" >&2
      fail=1
      return
    fi
    [ "$present" = true ] || return 0

    if [ "$after" != true ]; then
      echo "$name: home.activation.$attr must run after installPackages" >&2
      fail=1
    fi

    printf '%s\n' "$5" > script
    merger=$(grep -oE '/nix/store/[^[:space:]]+/bin/agent-settings' script | head -n 1 || true)
    if [ -z "$merger" ]; then
      echo "$name: the $attr activation names no packaged merger" >&2
      fail=1
      return
    fi
    sed "s|$merger|$PWD/merger-stub|g" script > swapped

    if ! exercise '"$@"' 0 || [ ! -f args ]; then
      echo "$name: on a live run the $attr activation does not run the merger" >&2
      fail=1
      return
    fi
    actual=$(argAfter --settings)
    if [ "$actual" != "$settings" ]; then
      echo "$name: the merger must be pointed at $settings, got '$actual'" >&2
      fail=1
    fi
    declared=$(argAfter --declared)
    if [ -z "$declared" ] || ! cmp -s "$declared" "$want"; then
      echo "$name: the $attr declaration must equal $want, got '$declared'" >&2
      fail=1
    fi

    if exercise '"$@"' 23; then
      echo "$name: the $attr activation swallows the merger's exit status" >&2
      fail=1
    fi

    exercise ':' 0 || true
    if [ -f args ]; then
      echo "$name: the $attr activation runs the merger outside Home Manager's run, so a dry run changes the settings file" >&2
      fail=1
    fi
  }

  # $2 says whether the runtime install belongs on this configuration, $3
  # whether it is declared; $4 is its script, $5 whether it runs after
  # installPackages, and $6 the base directory it must name.
  checkRuntime() {
    local name=$1 expected=$2 present=$3 after=$5 base=$6 installer actual
    if [ "$present" != "$expected" ]; then
      echo "$name: home.activation.t3codeAntigravity is present=$present, either T3 Code trait on is $expected" >&2
      fail=1
      return
    fi
    [ "$present" = true ] || return 0

    if [ "$after" != true ]; then
      echo "$name: home.activation.t3codeAntigravity must run after installPackages" >&2
      fail=1
    fi

    printf '%s\n' "$4" > script
    installer=$(grep -oE '/nix/store/[^[:space:]]+/bin/t3code-antigravity-install' script | head -n 1 || true)
    if [ -z "$installer" ]; then
      echo "$name: the t3codeAntigravity activation names no packaged installer" >&2
      fail=1
      return
    fi
    sed "s|$installer|$PWD/merger-stub|g" script > swapped

    if ! exercise '"$@"' 0 || [ ! -f args ]; then
      echo "$name: on a live run the t3codeAntigravity activation does not run the installer" >&2
      fail=1
      return
    fi
    actual=$(argAfter --base-dir)
    if [ "$actual" != "$base" ]; then
      echo "$name: the installer must be pointed at $base, got '$actual'" >&2
      fail=1
    fi
    actual=$(argAfter --runtime)
    if [ "$actual" != ${esc runtimeExpected} ]; then
      echo "$name: the installer must link ${runtimeExpected}, the runtime this system pins, got '$actual'" >&2
      fail=1
    fi
    actual=$(argAfter --pin)
    if [ "$actual" != ${esc pinExpected} ]; then
      echo "$name: the installer must read ${pinExpected}, this system's pin record, got '$actual'" >&2
      fail=1
    fi

    if exercise '"$@"' 23; then
      echo "$name: the t3codeAntigravity activation swallows the installer's exit status" >&2
      fail=1
    fi

    exercise ':' 0 || true
    if [ -f args ]; then
      echo "$name: the t3codeAntigravity activation runs the installer outside Home Manager's run, so a dry run changes ~/.t3" >&2
      fail=1
    fi
  }

  ${lib.concatMapStrings assertProfile profileEntries}
  ${lib.concatMapStrings assertSettingsOn bothOff}
  ${lib.concatMapStrings (
    entry:
    let
      home = entry.host.home.config;
    in
    assertSettings entry.name home (home.my.t3.cli.enable || home.my.t3.desktop.enable)
  ) configurations.linuxFixtures}
  ${lib.concatMapStrings assertFixtureCli (
    lib.filter (entry: entry.bootstrap) configurations.linuxFixtures
  )}
  ${lib.concatMapStrings assertFixture (lib.filter (entry: entry.bootstrap) fixtures)}
  ${assertModule}

  [ "$fail" = 0 ] || exit 1
  touch "$out"
''
