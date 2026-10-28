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
  - home.activation.antigravityAcpSettings runs after installPackages and,
    executed in a scratch HOME through tests/lib/agent-activation.nix, sets
    auth.type = "oauth-personal" in ~/.gemini/antigravity-acp/settings.json
    while keeping the keys the runtime wrote, so the ACP runtime asks for the
    Google sign-in Compound Engineering's Antigravity route expects.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self; };

  executeActivation = import ./lib/agent-activation.nix { inherit pkgs; };

  acpSettingsFile = ".gemini/antigravity-acp/settings.json";

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

      acpActivation = userConfig.home.activation.antigravityAcpSettings or null;
      acpRunsAfterPackages = lib.elem "installPackages" (
        if acpActivation == null then [ ] else (acpActivation.after or [ ])
      );
      acpSettings =
        if acpActivation == null then
          ''
            echo 'missing home.activation.antigravityAcpSettings on ${hostName}' >&2
            failed=1
          ''
        else
          ''
            if [ ${lib.boolToString acpRunsAfterPackages} != true ]; then
              echo 'home.activation.antigravityAcpSettings must run after installPackages on ${hostName}' >&2
              failed=1
            fi
            ${executeActivation {
              script = acpActivation.data or "";
              home = userConfig.home.homeDirectory or "";
              contract = {
                file = acpSettingsFile;
                declared.setPaths = [
                  {
                    path = [
                      "auth"
                      "type"
                    ];
                    value = "oauth-personal";
                  }
                ];
                seed = {
                  auth = {
                    type = "gemini-api-key";
                    project = "kept";
                  };
                  model = "kept";
                };
                expected = {
                  auth = {
                    type = "oauth-personal";
                    project = "kept";
                  };
                  model = "kept";
                };
              };
            }}
          '';
    in
    ''
      ${geminiDelivery}
      ${symlinkPresent}
      ${acpSettings}
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
