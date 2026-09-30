/*
  Helper interface:

    linuxFixtures = import ./lib/linux-fixtures.nix { inherit inputs; };

  The non-NixOS fixture hosts under tests/fixtures/hosts/, assembled through
  the same lib/linux-host.nix the flake uses for real hosts. They stand in for
  real non-NixOS hosts, which need card-encrypted material under secrets/ and
  so cannot live in hosts/ for testing.

  Returns one `{ name, fixture, bootstrap, host }` per fixture and variant,
  where `name` is the output name (`<fixture>` or `<fixture>-bootstrap`),
  `fixture` the directory name, and `host` the result of mkLinuxHost
  (`{ system, home, systemManager }`). Fixture names are read from the
  directory, never written out, so host-name-guard can keep them out of code.
*/
{ inputs }:
let
  inherit (inputs.nixpkgs) lib;

  mkLinuxHost = import ../../lib/linux-host.nix { inherit inputs; };

  fixtureNames = import ./directories.nix { inherit lib; } ../fixtures/hosts;

  # Fixtures have no card-encrypted material under secrets/, so production
  # decrypts fake secrets built for the fixture's own architecture.
  fakeSecretsModule =
    { pkgs, ... }:
    let
      fakeSecrets = import ./fake-secrets.nix { inherit pkgs; };
    in
    {
      my.secrets = {
        tokensFile = "${fakeSecrets}/tokens.yaml";
        sshKeyFile = "${fakeSecrets}/ssh.yaml";
      };
    };

  entryOf = fixture: bootstrap: {
    name = if bootstrap then "${fixture}-bootstrap" else fixture;
    inherit fixture bootstrap;
    host = mkLinuxHost {
      hostName = fixture;
      dir = ../fixtures/hosts + "/${fixture}";
      inherit bootstrap;
      extraModules.home = [ fakeSecretsModule ];
    };
  };
in
lib.concatMap (fixture: [
  (entryOf fixture false)
  (entryOf fixture true)
]) fixtureNames
