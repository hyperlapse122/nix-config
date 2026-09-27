/*
  Helper interface:

    configurations = import ./lib/configurations.nix { inherit pkgs self; };

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
    `predicate config` computes. `enabled` and `disabled` split `entries`;
    `guard` fails the builder when no production configuration enables the
    trait, so a check's positive branch can never cover zero configurations.

  Trait options are read without `or` fallbacks: the shared profile imports
  every trait module, so each trait option exists on every configuration and a
  missing one is an evaluation error worth seeing.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  entries = lib.mapAttrsToList (name: host: {
    inherit name;
    inherit (host) config;
    bootstrap = host.config.my.bootstrap;
    user = host.config.home-manager.users.h82 or { };
  }) self.nixosConfigurations;

  production = lib.filter (entry: !entry.bootstrap) entries;
in
{
  inherit entries production;

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

  withTrait = label: predicate: {
    enabled = lib.filter (entry: predicate entry.config) entries;
    disabled = lib.filter (entry: !predicate entry.config) entries;
    guard = lib.optionalString (!lib.any (entry: predicate entry.config) production) ''
      echo ${lib.escapeShellArg "tests/lib/configurations.nix: no production configuration enables ${label}, so this check's positive branch would cover no configuration"} >&2
      exit 1
    '';
  };
}
