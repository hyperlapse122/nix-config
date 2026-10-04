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
  Today every configuration enables both traits, so the forced-off
  configurations are what keep each "exactly when" from passing on the
  positive side alone. Some production and some bootstrap configuration must
  enable each trait.

  On every non-NixOS fixture host's bootstrap variant, re-assembled through
  lib/linux-host.nix with my.t3.desktop.enable forced on, Home Manager
  refuses to evaluate, while the fixture as declared evaluates. Home Manager
  throws on a failed assertion before its output can be read, so
  home/h82/t3code.nix is also evaluated on its own: on a non-NixOS kind its
  assertion reports that the desktop app is NixOS-only and the desktop
  package is not added; on NixOS nothing fails and the package is added.

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

  profileEntries = configurations.entries ++ cliTrait.disabled ++ desktopTrait.disabled;

  assertProfile = entry: ''
    checkProfile ${esc entry.name} ${
      esc (entry.user.home.path or "")
    } ${lib.boolToString (cliEnabled entry.config)} ${lib.boolToString (desktopEnabled entry.config)}
  '';

  desktopMessage = "the T3 Code desktop app is NixOS-only";

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

  # The module on its own, so the assertion's message and the packages it
  # would otherwise let through can be read. NixOS is the control: there the
  # desktop app installs and nothing fails.
  moduleOn =
    kind:
    let
      config =
        (lib.evalModules {
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
      failed = map (a: a.message) (lib.filter (a: !a.assertion) config.assertions);
      desktopInstalled = lib.elem "t3code-desktop" (map lib.getName config.home.packages);
    };

  assertModule =
    let
      linux = moduleOn "linux";
      nixos = moduleOn "nixos";
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

  checkProfile() {
    local name=$1 profile=$2 cli=$3 desktop=$4 present target exe
    if [ -z "$profile" ] || [ ! -d "$profile" ]; then
      echo "$name: Home Manager renders no home.path" >&2
      fail=1
      return
    fi

    present=false
    resolvesInto "$profile/bin/t3" t3code-cli && present=true
    if [ "$present" != "$cli" ]; then
      echo "$name: bin/t3 from t3code-cli is present=$present, my.t3.cli.enable is $cli" >&2
      fail=1
    fi

    present=false
    resolvesInto "$profile/share/applications/t3code.desktop" t3code-desktop && present=true
    if [ "$present" != "$desktop" ]; then
      echo "$name: the t3code.desktop entry is present=$present, my.t3.desktop.enable is $desktop" >&2
      fail=1
    fi

    present=false
    resolvesInto "$profile/bin/t3code-desktop" t3code-desktop && present=true
    if [ "$present" != "$desktop" ]; then
      echo "$name: bin/t3code-desktop is present=$present, my.t3.desktop.enable is $desktop" >&2
      fail=1
    fi

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

  ${lib.concatMapStrings assertProfile profileEntries}
  ${lib.concatMapStrings assertFixture (lib.filter (entry: entry.bootstrap) fixtures)}
  ${assertModule}

  [ "$fail" = 0 ] || exit 1
  touch "$out"
''
