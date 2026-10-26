/*
  Check interface:

    import ./tests/gemini.nix { inherit pkgs self; }

  Asserts that implicit memory is disabled declaratively for the Gemini CLI
  for user `h82` on every configuration `tests/lib/configurations.nix` yields,
  production and bootstrap alike, since none of it depends on a host trait
  or on `my.bootstrap`.

  Verifies, per configuration:
  - ~/.gemini/settings.json sets experimental.autoMemory = false.
  - no Home Manager file targets .gemini/antigravity-cli/settings.json.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self; };

  assertHost =
    entry:
    let
      hostName = entry.name;
      userConfig = entry.user;
      homeFiles = userConfig.home-files or null;

      antigravityTargeted = lib.any (
        file: (file.target or "") == ".gemini/antigravity-cli/settings.json"
      ) (lib.attrValues (userConfig.home.file or { }));

      geminiDelivery =
        if homeFiles == null then
          "echo 'missing Gemini home-files on ${hostName}' >&2; failed=1"
        else
          ''
            if ! ${pkgs.jq}/bin/jq -e '.experimental.autoMemory == false' ${homeFiles}/.gemini/settings.json >/dev/null; then
              echo 'missing or incorrect delivered Gemini settings on ${hostName}' >&2
              failed=1
            fi
          '';

      symlinkPresent = lib.optionalString antigravityTargeted ''
        echo 'Home Manager must not target ~/.gemini/antigravity-cli/settings.json on ${hostName}' >&2
        failed=1
      '';
    in
    ''
      ${geminiDelivery}
      ${symlinkPresent}
    '';
in
pkgs.runCommand "gemini-tests" { nativeBuildInputs = [ pkgs.diffutils ]; } ''
  set -x
  ${configurations.userGuard}
  failed=0

  ${lib.concatMapStringsSep "\n" assertHost configurations.userEntries}

  if [ "$failed" != "0" ]; then
    exit 1
  fi

  touch $out
''
