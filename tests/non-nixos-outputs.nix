/*
  Check interface:

    import ./tests/non-nixos-outputs.nix { inherit pkgs self fixtures; }

  `fixtures` is tests/lib/linux-fixtures.nix. Asserts what the non-NixOS
  assembly produces for every fixture host, both variants:

  - every fixture yields a production and a bootstrap output;
  - the Home Manager activation package is built for the fixture's own
    architecture, so an aarch64 host never receives x86_64 binaries;
  - the account and home directory follow the host's `my.user` values;
  - no desktop configuration reaches the user environment, even on a fixture
    that declares the laptop trait: no KDE lid activation, no Plasma or
    autostart files, no GUI packages.

  Every comparison is rendered into the builder, so a failure names the
  fixture and the reason instead of aborting evaluation.
*/
{
  pkgs,
  self,
  fixtures,
}:
let
  inherit (pkgs) lib;

  # GUI packages the NixOS desktop installs; none may reach a non-NixOS host.
  guiPackages = [
    "discord"
    "google-chrome"
    "kleopatra"
    "ksshaskpass"
    "okular"
    "libreoffice-qt"
    "telegram-desktop"
    "yubioath-flutter"
    "claude-desktop"
    "orca"
    "vscodium"
    "ghostty"
  ];

  fail = message: ''
    echo ${lib.escapeShellArg message} >&2
    fail=1
  '';

  check = condition: message: lib.optionalString (!condition) (fail message);

  fixtureNames = lib.unique (map (entry: entry.fixture) fixtures);

  assertPairs = lib.concatMapStrings (
    fixture:
    let
      variants = map (entry: entry.bootstrap) (lib.filter (entry: entry.fixture == fixture) fixtures);
    in
    check (
      lib.elem false variants && lib.elem true variants
    ) "${fixture}: expected a production and a bootstrap output"
  ) fixtureNames;

  assertEntry =
    entry:
    let
      home = entry.host.home;
      hm = home.config;
      pnames = map (p: p.pname or (lib.getName p)) hm.home.packages;
      leakedGui = lib.filter (name: lib.elem name pnames) guiPackages;
      desktopFiles = lib.filter (
        name: lib.hasPrefix "autostart/" name || lib.hasPrefix "plasma" name || lib.hasPrefix "kde" name
      ) (lib.attrNames hm.xdg.configFile);
    in
    lib.concatStrings [
      (check (home.activationPackage.system == entry.host.system)
        "${entry.name}: activation package is built for ${home.activationPackage.system}, the host is ${entry.host.system}"
      )
      (check (
        hm.home.username == hm.my.user.name
      ) "${entry.name}: home.username is ${hm.home.username}, my.user.name is ${hm.my.user.name}")
      (check (hm.home.homeDirectory == hm.my.user.home)
        "${entry.name}: home.homeDirectory is ${hm.home.homeDirectory}, my.user.home is ${hm.my.user.home}"
      )
      (check (
        !(hm.home.activation ? kdePowerLid)
      ) "${entry.name}: the KDE lid activation reached a non-NixOS host")
      (check (
        leakedGui == [ ]
      ) "${entry.name}: GUI packages reached a non-NixOS host: ${lib.concatStringsSep ", " leakedGui}")
      (check (desktopFiles == [ ])
        "${entry.name}: desktop configuration reached a non-NixOS host: ${lib.concatStringsSep ", " desktopFiles}"
      )
    ];

  # The laptop trait must be exercised, or the desktop assertions above could
  # pass only because no fixture asked for anything desktop-shaped.
  laptopFixtures = lib.filter (entry: entry.host.home.config.my.laptop.enable) fixtures;
in
pkgs.runCommand "non-nixos-outputs" { } ''
  fail=0
  ${lib.optionalString (fixtures == [ ]) (fail "tests/fixtures/hosts holds no fixture host")}
  ${lib.optionalString (laptopFixtures == [ ]) (fail "no fixture declares my.laptop.enable")}
  ${assertPairs}
  ${lib.concatMapStrings assertEntry fixtures}
  [ "$fail" = 0 ] || exit 1
  touch "$out"
''
