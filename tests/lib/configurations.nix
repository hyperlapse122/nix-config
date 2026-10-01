/*
  Helper interface:

    configurations = import ./lib/configurations.nix { inherit pkgs self; };

  `fixtures` may also be passed (tests/lib/linux-fixtures.nix), so a caller
  that already built the fixture hosts does not assemble them again.

  Turns `self.nixosConfigurations` into the one list every host-dependent check
  iterates, so a host added under hosts/ is covered the day it is added and no
  check names a host.

  - `entries`: one `{ name, config, bootstrap, user }` per configuration, where
    `name` is the flake output name, `bootstrap` is `config.my.bootstrap`, and
    `user` is the `h82` Home Manager configuration (`{ }` when absent, so a
    removed user fails inside the builder rather than during evaluation).
    Checks identify a bootstrap output by `bootstrap`, never by the output
    name, because both outputs of a host share one `networking.hostName`.
  - `production` and `bootstraps`: `entries` split by `bootstrap`.
  - `guard`: a script fragment that fails the builder when `entries` is empty
    or holds no bootstrap output. Every check splices it before its per-entry
    assertions, so an empty list is a failure, never a silent pass.
  - `withTrait label predicate`: `{ enabled, disabled, guard }` for the trait
    `predicate config` computes, where `label` is the trait's option path
    (`my.keyd.enable`). `enabled` and `disabled` split `entries`; `guard`
    fails the builder when no production configuration enables the trait, so
    a check's positive branch can never cover zero configurations. When no
    configuration leaves the trait off, `disabled` holds each production
    configuration re-evaluated with `label` forced to `false`, so the
    negative branch never covers zero configurations either.

  - `userEntries`: one `{ name, kind, bootstrap, user }` per Home Manager
    user environment the flake builds for this architecture: the NixOS
    configurations' `h82` users (`kind = "nixos"`) and the standalone Home
    Manager outputs of the non-NixOS fixture hosts (`kind = "linux"`). Checks
    that assert only Home Manager state run over this list, so they cover
    both host kinds.
  - `userGuard`: fails the builder when `userEntries` holds no bootstrap
    output or no entry of either kind.

  Trait options are read without `or` fallbacks: the shared profile imports
  every trait module, so each trait option exists on every configuration and a
  missing one is an evaluation error worth seeing.
*/
{
  pkgs,
  self,
  # tests/lib/linux-fixtures.nix. The flake passes the list it already built,
  # so the fixtures are assembled once per evaluation.
  fixtures ? import ./linux-fixtures.nix { inherit (self) inputs; },
}:
let
  inherit (pkgs) lib;

  entryOf = name: host: {
    inherit name;
    inherit (host) config;
    bootstrap = host.config.my.bootstrap;
    user = host.config.home-manager.users.h82 or { };
  };

  entries = lib.mapAttrsToList entryOf self.nixosConfigurations;

  # A production configuration with the trait at `label` forced off, for a
  # fleet in which every configuration enables it.
  withTraitForcedOff =
    label: entry:
    entryOf "${entry.name} with ${label} forced off" (
      self.nixosConfigurations.${entry.name}.extendModules {
        modules = [ (lib.setAttrByPath (lib.splitString "." label) (lib.mkForce false)) ];
      }
    );

  production = lib.filter (entry: !entry.bootstrap) entries;

  # Only fixtures of the builder's architecture: a check interpolates their
  # store paths, and another architecture's paths cannot build here.
  linuxFixtures = lib.filter (entry: entry.host.system == pkgs.stdenv.hostPlatform.system) fixtures;

  userEntries =
    map (entry: {
      inherit (entry) name bootstrap user;
      kind = "nixos";
    }) entries
    ++ map (entry: {
      inherit (entry) name bootstrap;
      kind = "linux";
      user = entry.host.home.config;
    }) linuxFixtures;
in
{
  inherit entries production userEntries;

  userGuard =
    let
      missing = lib.filter (kind: !lib.any (entry: entry.kind == kind) userEntries) [
        "nixos"
        "linux"
      ];
    in
    lib.optionalString (missing != [ ]) ''
      echo ${lib.escapeShellArg "tests/lib/configurations.nix: no Home Manager user of kind ${lib.concatStringsSep ", " missing}, so this check would cover no such host"} >&2
      exit 1
    ''
    + lib.optionalString (lib.all (entry: !entry.bootstrap) userEntries) ''
      echo 'tests/lib/configurations.nix: no Home Manager user comes from a bootstrap output, so this check would cover none' >&2
      exit 1
    '';

  bootstraps = lib.filter (entry: entry.bootstrap) entries;

  guard =
    if entries == [ ] then
      ''
        echo 'tests/lib/configurations.nix: self.nixosConfigurations is empty, so this check would cover no configuration' >&2
        exit 1
      ''
    else
      lib.optionalString (lib.all (entry: !entry.bootstrap) entries) ''
        echo 'tests/lib/configurations.nix: no configuration sets my.bootstrap, so this check would cover no bootstrap output' >&2
        exit 1
      '';

  withTrait =
    label: predicate:
    let
      disabled = lib.filter (entry: !predicate entry.config) entries;
    in
    {
      enabled = lib.filter (entry: predicate entry.config) entries;
      disabled = if disabled != [ ] then disabled else map (withTraitForcedOff label) production;
      guard = lib.optionalString (!lib.any (entry: predicate entry.config) production) ''
        echo ${lib.escapeShellArg "tests/lib/configurations.nix: no production configuration enables ${label}, so this check's positive branch would cover no configuration"} >&2
        exit 1
      '';
    };
}
