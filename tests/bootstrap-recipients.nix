/*
  Check interface:

    import ./tests/bootstrap-recipients.nix { inherit pkgs; }

  Asserts that every per-host bootstrap recipient can actually decrypt the
  encrypted token document.

  Verifies:
  - Each secrets/bootstrap/<host>/ directory holds both age-key.asc and
    recipient.txt.
  - Each recorded recipient appears as an age recipient in .sops.yaml.

  secrets/tokens.yaml is encrypted to the recipients .sops.yaml names, so a
  host whose recipient is missing there installs a valid-looking identity and
  then fails at activation, far from the cause. Regenerating a host's identity
  without re-encrypting the tokens produces exactly that, and nothing else in
  the tree notices.
*/
{ pkgs }:
let
  inherit (pkgs) lib;

  bootstrap = ../secrets/bootstrap;

  hosts = lib.attrNames (lib.filterAttrs (_: kind: kind == "directory") (builtins.readDir bootstrap));

  sopsConfig = builtins.readFile ../.sops.yaml;

  recipientOf = host: lib.strings.trim (builtins.readFile (bootstrap + "/${host}/recipient.txt"));

  hasFile = host: name: builtins.pathExists (bootstrap + "/${host}/${name}");

  checkHost =
    host:
    if !hasFile host "age-key.asc" then
      ''
        echo 'secrets/bootstrap/${host} has no age-key.asc' >&2
        exit 1
      ''
    else if !hasFile host "recipient.txt" then
      ''
        echo 'secrets/bootstrap/${host} has no recipient.txt' >&2
        exit 1
      ''
    else if !lib.strings.hasInfix (recipientOf host) sopsConfig then
      ''
        echo 'the recipient recorded for ${host} does not appear in .sops.yaml, so that host cannot decrypt secrets/tokens.yaml' >&2
        exit 1
      ''
    else
      ''
        echo 'ok: ${host}'
      '';

  noHosts = lib.optionalString (hosts == [ ]) ''
    echo 'no per-host bootstrap material under secrets/bootstrap' >&2
    exit 1
  '';
in
pkgs.runCommand "bootstrap-recipients-tests" { } ''
  set -x
  ${noHosts}
  ${lib.concatStringsSep "\n" (map checkHost hosts)}
  touch $out
''
