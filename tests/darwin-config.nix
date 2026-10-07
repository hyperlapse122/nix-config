/*
  Check interface:

    import ./tests/darwin-config.nix { inherit pkgs self linuxFixtures darwinFixtures; }

  `linuxFixtures` and `darwinFixtures` are tests/lib/linux-fixtures.nix and
  tests/lib/darwin-fixtures.nix. Evaluates the macOS fixture hosts on Linux,
  where no darwin derivation can be built, and renders what their options say
  into the builder. The materialized generation is read on a macOS builder by
  tests/darwin-outputs.nix.

  - Host discovery: every fixture whose host.nix names kind darwin is a macOS
    fixture and no other kind is; every macOS fixture yields a production and
    a bootstrap output.
  - GUI apps (home/h82/darwin-apps.nix): every package a NixOS user has and no
    non-NixOS Linux fixture has, plus the 1Password GUI where NixOS enables
    it, has a macOS decision, and each decision is exactly one of a cask, a
    Nix package, or left out. The set is derived from the evaluated
    configurations, so a package added on NixOS fails here until it has one.
  - Homebrew: the casks are exactly the mapping's casks plus its macOS-only
    ones; an apply never removes an unlisted app and upgrades listed ones;
    every third-party cask's tap is tapped and trusted.
  - The user environment takes the non-NixOS path: production runs the
    host-secrets steps and the docker credHelpers merge and bootstrap runs
    none; ~/.ssh/config names the host key; no Podman variable or
    containers/ file is present; `nr` is nr-darwin; the YubiKey pinentry is
    the darwin filter, with pinentry_mac's Keychain checkbox unticked by
    default; VSCodium's settings live under Application Support; Ghostty has
    the NixOS font families and no nixpkgs package.
  - The system layer turns off store auto-optimisation, installs the shared
    font list, and records the host and variant in /etc/nix-config-host.

  Every comparison is rendered into the builder, so a failure names the
  fixture and the reason instead of aborting evaluation. No darwin store path
  is interpolated, so the check builds on Linux.
*/
{
  pkgs,
  self,
  linuxFixtures,
  darwinFixtures,
}:
let
  inherit (pkgs) lib;

  fail = message: ''
    echo ${lib.escapeShellArg message} >&2
    fail=1
  '';

  check = condition: message: lib.optionalString (!condition) (fail message);

  plain = builtins.unsafeDiscardStringContext;

  namesOf = packages: lib.unique (map (p: p.pname or (lib.getName p)) packages);

  hosts = import ../lib/hosts.nix { inherit lib; } ./fixtures/hosts;
  kindOf = fixture: (import (./fixtures/hosts + "/${fixture}/host.nix")).kind or null;

  assertDiscovery = lib.concatStrings [
    (check (hosts.darwin != [ ]) "tests/fixtures/hosts holds no macOS fixture host")
    (lib.concatMapStrings (
      fixture:
      check (
        kindOf fixture == "darwin"
      ) "${fixture}: listed as macOS, but host.nix names kind ${toString (kindOf fixture)}"
    ) hosts.darwin)
    (lib.concatMapStrings (
      fixture:
      check (
        kindOf fixture != "darwin"
      ) "${fixture}: host.nix names kind darwin, but it is listed as a Linux host"
    ) hosts.linux)
    (check (
      lib.sort lib.lessThan (lib.unique (map (e: e.fixture) darwinFixtures))
      == lib.sort lib.lessThan hosts.darwin
    ) "the macOS fixture assembly does not cover exactly the macOS fixture hosts")
    (lib.concatMapStrings (
      fixture:
      let
        variants = map (e: e.bootstrap) (lib.filter (e: e.fixture == fixture) darwinFixtures);
      in
      check (
        lib.elem false variants && lib.elem true variants
      ) "${fixture}: expected a production and a bootstrap output"
    ) hosts.darwin)
  ];

  # The NixOS-only package set the mapping must cover.
  nixosConfigs = lib.attrValues (
    lib.filterAttrs (name: _: !lib.hasSuffix "-bootstrap" name) self.nixosConfigurations
  );
  nixosNames = lib.unique (
    lib.concatMap (c: namesOf c.config.home-manager.users.h82.home.packages) nixosConfigs
  );
  linuxNames = lib.unique (lib.concatMap (e: namesOf e.host.home.config.home.packages) linuxFixtures);
  onePassword = lib.optional (lib.any (
    c: c.config.programs._1password-gui.enable
  ) nixosConfigs) "1password";
  required = lib.subtractLists linuxNames nixosNames ++ onePassword;

  mapping = import ../home/h82/darwin-apps.nix;
  kinds = [
    "cask"
    "nix"
    "leftOut"
  ];
  expectedCasks =
    lib.mapAttrsToList (_: app: app.cask) (lib.filterAttrs (_: app: app ? cask) mapping.apps)
    ++ mapping.darwinOnly;

  assertMapping = lib.concatStrings [
    (check (required != [ ]) "no package is NixOS-only, so the mapping check would pass vacuously")
    (lib.concatMapStrings (
      name:
      check (
        mapping.apps ? ${name}
      ) "${name}: installed on NixOS but has no macOS decision in home/h82/darwin-apps.nix"
    ) required)
    (lib.concatStrings (
      lib.mapAttrsToList (
        name: app:
        check (
          lib.length (lib.attrNames app) == 1 && lib.elem (lib.head (lib.attrNames app)) kinds
        ) "${name}: the macOS decision must be exactly one of cask, nix, or leftOut"
      ) mapping.apps
    ))
    (check (lib.elem "orbstack" mapping.darwinOnly) "OrbStack is not among the macOS-only casks")
  ];

  sort = lib.sort lib.lessThan;

  assertEntry =
    entry:
    let
      config = entry.host.config;
      user = config.home-manager.users.${config.my.user.name};
      activation = user.home.activation;
      pnames = namesOf user.home.packages;
      casks = map (cask: cask.name) config.homebrew.casks;
      taps = map (tap: tap.name) config.homebrew.taps;
      thirdParty = lib.filter (cask: lib.length (lib.splitString "/" cask) == 3) expectedCasks;
      tapOf = cask: lib.concatStringsSep "/" (lib.take 2 (lib.splitString "/" cask));
      sessionVariables = lib.attrNames user.home.sessionVariables;
      podmanVariables = [
        "DOCKER_HOST"
        "REGISTRY_AUTH_FILE"
        "TESTCONTAINERS_RYUK_CONTAINER_PRIVILEGED"
        "TESTCONTAINERS_RYUK_PRIVILEGED"
      ];
      leakedVariables = lib.filter (name: lib.elem name sessionVariables) podmanVariables;
      containerFiles = lib.filter (name: lib.hasPrefix "containers/" name) (
        lib.attrNames (lib.filterAttrs (_: file: file.enable) user.xdg.configFile)
      );
      sshText = plain user.my.ssh.configFile.drvAttrs.text;
      pinentry = user.services.gpg-agent.pinentry.package;
      vscodiumData = plain (activation.vscodiumSettings.data or "");
      marker = config.environment.etc."nix-config-host".text or "";
      production = !entry.bootstrap;
    in
    lib.concatStrings [
      (check (sort casks == sort expectedCasks)
        "${entry.name}: homebrew.casks is ${builtins.toJSON (sort casks)}, the mapping gives ${builtins.toJSON (sort expectedCasks)}"
      )
      (check (config.homebrew.onActivation.cleanup == "none")
        "${entry.name}: homebrew cleanup is ${config.homebrew.onActivation.cleanup}, so an apply removes apps installed outside the list"
      )
      (check config.homebrew.onActivation.upgrade "${entry.name}: homebrew upgrade is off, so an apply never updates listed apps")
      (lib.concatMapStrings (
        cask:
        check (
          lib.elem (tapOf cask) taps && lib.elem cask config.nix-homebrew.trust.casks
        ) "${entry.name}: ${cask} needs its tap tapped and the cask trusted"
      ) thirdParty)
      (check config.nix-homebrew.enable "${entry.name}: nix-homebrew is off, so a new Mac needs Homebrew installed by hand")
      (check (
        activation ? nixConfigSecretsStage == production
        && activation ? nixConfigSecretsPublish == production
      ) "${entry.name}: the host-secrets steps must run in production and never in bootstrap")
      (check
        (
          activation ? dockerCredHelpers == production
          && (!production || lib.elem "linkGeneration" (activation.dockerCredHelpers.after or [ ]))
        )
        "${entry.name}: the docker credHelpers merge must run after linkGeneration in production and never in bootstrap"
      )
      (check (
        lib.hasInfix "IdentityFile ${user.my.secrets.sshKey}" sshText
        && !lib.hasInfix "IdentityAgent" sshText
      ) "${entry.name}: ~/.ssh/config must name the host key and no agent socket")
      (check (leakedVariables == [ ])
        "${entry.name}: Podman session variables reached macOS: ${lib.concatStringsSep ", " leakedVariables}"
      )
      (check (containerFiles == [ ])
        "${entry.name}: Podman containers/ files reached macOS: ${lib.concatStringsSep ", " containerFiles}"
      )
      (check (
        lib.elem "nr-darwin" pnames && !lib.elem "nr" pnames && !lib.elem "nr-linux" pnames
      ) "${entry.name}: nr must be nr-darwin")
      (check (
        lib.hasInfix "pinentry-card-darwin" (plain (pinentry.drvAttrs.installPhase or ""))
        && lib.hasInfix "pinentry-mac" (plain (pinentry.drvAttrs.installPhase or ""))
      ) "${entry.name}: the YubiKey pinentry must be the darwin filter in front of pinentry_mac")
      (check ((user.targets.darwin.defaults."org.gpgtools.pinentry-mac".UseKeychain or null) == false)
        "${entry.name}: pinentry_mac's UseKeychain default must be false, or Save in Keychain starts ticked"
      )
      (check (lib.hasInfix "Library/Application Support/VSCodium/User/settings.json" vscodiumData) "${entry.name}: the VSCodium settings merge must target Library/Application Support/VSCodium/User")
      (check (
        user.programs.ghostty.package == null
      ) "${entry.name}: Ghostty must come from the cask, not nixpkgs")
      (check (
        user.programs.ghostty.settings.font-family or [ ] == [
          "JetBrainsMono Nerd Font"
          "D2CodingLigature Nerd Font"
          "D2KodingLigature Nerd Font"
          "Twitter Color Emoji"
        ]
      ) "${entry.name}: Ghostty's font-family differs from the NixOS terminal's")
      (check (
        !config.nix.settings.auto-optimise-store
      ) "${entry.name}: auto-optimise-store must be off on macOS")
      (check (
        namesOf config.fonts.packages == namesOf (import ../modules/shared/font-packages.nix pkgs)
      ) "${entry.name}: the macOS font list differs from modules/shared/font-packages.nix")
      (check (
        lib.hasInfix "host=${entry.fixture}\n" marker
        && lib.hasInfix "variant=${if entry.bootstrap then "bootstrap" else "production"}\n" marker
      ) "${entry.name}: /etc/nix-config-host must record the host and variant")
    ];
in
pkgs.runCommand "darwin-config" { } ''
  fail=0
  ${lib.optionalString (darwinFixtures == [ ]) (
    fail "tests/fixtures/hosts holds no macOS fixture host"
  )}
  ${assertDiscovery}
  ${assertMapping}
  ${lib.concatMapStrings assertEntry darwinFixtures}
  [ "$fail" = 0 ] || exit 1
  touch "$out"
''
