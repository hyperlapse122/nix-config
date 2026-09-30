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
    autostart files, no GUI packages;
  - production runs the host-secrets activation steps and bootstrap never
    does; both carry the user-mode identity installer, and ~/.ssh/config
    names the host key rather than the 1Password agent;
  - the system layer manages no file the distribution owns: no user database,
    subordinate id range, login-shell list, or NVIDIA configuration;
  - on fixtures of the builder's own architecture, the materialized system
    layer runs pcscd with the ccid reader drivers, writes a nix.conf that keeps
    builds on the nixbld users and trusts only root, and records the host and
    variant in /etc/nix-config-host. Other architectures are proven by their
    own build in CI.

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
      sshConfig = hm.home.file.".ssh/config".text or "";
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
      (check (
        hm.home.activation ? nixConfigSecretsStage == !entry.bootstrap
        && hm.home.activation ? nixConfigSecretsPublish == !entry.bootstrap
      ) "${entry.name}: the secret activation steps must run in production and never in bootstrap")
      (check (lib.elem "install-user-age-identity" pnames) "${entry.name}: install-user-age-identity is missing, so the identity cannot be recovered")
      (check (
        lib.hasInfix "IdentityFile ~/.ssh/id_ed25519_nix_config" sshConfig
        && !lib.hasInfix "IdentityAgent" sshConfig
      ) "${entry.name}: ~/.ssh/config must name the host key and no agent socket")
      (check (desktopFiles == [ ])
        "${entry.name}: desktop configuration reached a non-NixOS host: ${lib.concatStringsSep ", " desktopFiles}"
      )
    ];

  # /etc paths the distribution owns, relative to /etc as environment.etc
  # keys are.
  distributionOwned = [
    "passwd"
    "group"
    "shadow"
    "gshadow"
    "subuid"
    "subgid"
    "shells"
  ];

  assertSystem =
    entry:
    let
      sm = entry.host.systemManager;
      managed = lib.attrNames (lib.filterAttrs (_: file: file.enable) sm.config.environment.etc);
      owned = lib.filter (
        name: lib.elem name distributionOwned || lib.hasPrefix "nvidia" name || lib.hasPrefix "../" name
      ) managed;
      variant = if entry.bootstrap then "bootstrap" else "production";
    in
    lib.concatStrings [
      (check (owned == [ ])
        "${entry.name}: the system layer manages distribution-owned files: ${lib.concatStringsSep ", " owned}"
      )
      (lib.optionalString (entry.host.system == pkgs.stdenv.hostPlatform.system) ''
        sm=${sm}
        unit=$(jq -r '.["pcscd.service"].storePath // empty' "$sm/services/services.json")
        if [ -z "$unit" ] || ! grep -q '^ExecStart=/nix/store/[^ ]*/bin/pcscd ' "$unit"; then
          ${fail "${entry.name}: pcscd.service is missing or does not run pcscd"}
        else
          dropdir=$(sed -n 's/^Environment="PCSCLITE_HP_DROPDIR=\(.*\)"$/\1/p' "$unit")
          if [ ! -d "$dropdir/ifd-ccid.bundle" ]; then
            ${fail "${entry.name}: pcscd's driver directory holds no ccid bundle"}
          fi
        fi
        if [ -z "$(jq -r '.["pcscd.socket"].storePath // empty' "$sm/services/services.json")" ]; then
          ${fail "${entry.name}: pcscd.socket is missing"}
        fi
        conf=$(jq -r '.entries["nix/nix.conf"].source // empty' "$sm/etcFiles/etcFiles.json")/nix/nix.conf
        if ! grep -qx 'build-users-group = nixbld' "$conf"; then
          ${fail "${entry.name}: nix.conf does not keep builds on the nixbld users"}
        fi
        if ! grep -qx 'trusted-users = root' "$conf"; then
          ${fail "${entry.name}: nix.conf trusts more than root"}
        fi
        marker=$(jq -r '.entries["nix-config-host"].source // empty' "$sm/etcFiles/etcFiles.json")/nix-config-host
        if ! grep -qx 'host=${entry.fixture}' "$marker" || ! grep -qx 'variant=${variant}' "$marker"; then
          ${fail "${entry.name}: /etc/nix-config-host does not record host ${entry.fixture}, variant ${variant}"}
        fi
      '')
    ];

  # The laptop trait must be exercised, or the desktop assertions above could
  # pass only because no fixture asked for anything desktop-shaped.
  laptopFixtures = lib.filter (entry: entry.host.home.config.my.laptop.enable) fixtures;
in
pkgs.runCommand "non-nixos-outputs" { nativeBuildInputs = [ pkgs.jq ]; } ''
  fail=0
  ${lib.optionalString (fixtures == [ ]) (fail "tests/fixtures/hosts holds no fixture host")}
  ${lib.optionalString (laptopFixtures == [ ]) (fail "no fixture declares my.laptop.enable")}
  ${assertPairs}
  ${lib.concatMapStrings assertEntry fixtures}
  ${lib.concatMapStrings assertSystem fixtures}
  [ "$fail" = 0 ] || exit 1
  touch "$out"
''
