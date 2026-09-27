/*
  Check interface:

    import ./tests/tokscale.nix { inherit pkgs self; }

  Asserts that every host configuration gives h82 the Tokscale wrapper, the
  declared settings merge, and the custom pricing file, and that only the
  production hosts decrypt the Tokscale token. It reads what the generations
  materialize -- home-path, home-files, the rendered activation script and the
  sops manifests -- rather than the options they come from. Expected values
  are literals stated here, independently of home/h82/agents/tokscale.nix.

  Verifies, on ThinkPad-X1-Carbon-Gen-11, ThinkPad-X1-Carbon-Gen-11-bootstrap,
  MS-7D91, and MS-7D91-bootstrap:
  - home-path/bin/tokscale is the packaged wrapper, and the host name baked
    into it is that configuration's networking.hostName with the token read
    from /run/secrets/cli-auth/tokscale_token.
  - home.activation.tokscaleSettings runs after installPackages, invokes the
    packaged merger without swallowing its exit status, points it at
    ~/.config/tokscale/settings.json, and passes a declared document equal to
    the one stated here.
  - running that exact merger with that exact declared document against a
    seeded, divergent settings file reasserts the five declared values and
    leaves every other key, nested siblings included, as it was.
  - no Home Manager file targets .config/tokscale/settings.json.
  - .config/tokscale/custom-pricing.json parses to the dotfiles document.
  - a production host's sops manifest carries cli-auth/tokscale_token owned by
    h82 with mode 0400, its gh/glab publisher does not read that token, and a
    bootstrap host's manifests carry no Tokscale secret at all.

  The wrapper's run-time behaviour (token precedence, Codex directories, exit
  status) is covered by the tokscale-wrapper check. This check never runs bun
  or Tokscale.

  Every lookup carries an `or` fallback so a mutation that removes an entry
  reaches the builder as shell rather than failing evaluation. See
  .compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md
  The builder collects every failure, so one red build names every broken
  assertion across all four hosts.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  esc = value: lib.escapeShellArg (toString value);

  declaredExpected = pkgs.writeText "tokscale-expected-settings.json" (
    builtins.toJSON {
      set = {
        colorPalette = "blue";
        autoRefreshEnabled = true;
        autoRefreshMs = 30000;
      };
      setPaths = [
        {
          path = [
            "scanner"
            "bucketTimezone"
          ];
          value = "Asia/Seoul";
        }
        {
          path = [
            "autosubmit"
            "enabled"
          ];
          value = false;
        }
      ];
    }
  );

  # Written as JSON text rather than a Nix attribute set so the comparison
  # cannot share a rendering path with the module.
  pricingExpected = pkgs.writeText "tokscale-expected-pricing.json" ''
    {
      "$schema": "https://tokscale.ai/custom-pricing.schema.json",
      "models": {
        "gemini-3.1-pro": {
          "input_cost_per_million_tokens": 4,
          "output_cost_per_million_tokens": 18,
          "cache_read_input_token_cost_per_million_tokens": 0.4,
          "cache_creation_input_token_cost_per_million_tokens": 0.375
        },
        "claude-fable-5-1": {
          "input_cost_per_million_tokens": 10,
          "output_cost_per_million_tokens": 50,
          "cache_read_input_token_cost_per_million_tokens": 0.25,
          "cache_creation_input_token_cost_per_million_tokens": 12.5
        }
      }
    }
  '';

  assertHost =
    hostName: production: host:
    let
      hm = host.config.home-manager.users.h82;
      homePath = hm.home.path or null;
      homeFiles = hm.home-files or null;

      activation = hm.home.activation.tokscaleSettings or null;
      script = if activation == null then "" else (activation.data or "");
      runsAfterPackages = lib.elem "installPackages" (
        if activation == null then [ ] else (activation.after or [ ])
      );

      settingsTargeted = lib.any (file: (file.target or "") == ".config/tokscale/settings.json") (
        lib.attrValues (hm.home.file or { })
      );

      # sops-nix installs through a systemd unit when my.cliAuth is enabled
      # and through the setupSecrets activation script otherwise, so both
      # places are searched for the manifests they hand the installer.
      sopsService = host.config.systemd.services.sops-install-secrets or { };
      installers = lib.concatStringsSep " " (
        lib.toList (sopsService.serviceConfig.ExecStart or [ ])
        ++ [ (host.config.system.activationScripts.setupSecrets.text or "") ]
      );
      publisher = lib.concatStringsSep " " (lib.toList (sopsService.serviceConfig.ExecStartPost or [ ]));

      host' = esc hostName;
    in
    ''
      expectedHost=${esc (host.config.networking.hostName or "")}
      ${
        if homePath == null then
          ''fail ${host'}": no home-path"''
        else
          ''
            wrapper=${homePath}/bin/tokscale
            if [ ! -x "$wrapper" ]; then
              fail ${host'}": home-path has no executable bin/tokscale"
            else
              resolved=$(readlink -f "$wrapper")
              case "$resolved" in
                /nix/store/*-tokscale-*/bin/tokscale) ;;
                *) fail ${host'}": bin/tokscale is not the packaged wrapper: $resolved" ;;
              esac
              if ! grep -Fxq -- "HOST_NAME='$expectedHost'" "$resolved"; then
                fail ${host'}": the wrapper does not carry the host name $expectedHost"
              fi
              if ! grep -Fxq -- "TOKEN_FILE='/run/secrets/cli-auth/tokscale_token'" "$resolved"; then
                fail ${host'}": the wrapper does not read /run/secrets/cli-auth/tokscale_token"
              fi
            fi
          ''
      }
      ${lib.optionalString (activation == null) ''
        fail ${host'}": missing home.activation.tokscaleSettings"
      ''}
      if [ ${esc (lib.boolToString runsAfterPackages)} != "true" ]; then
        fail ${host'}": home.activation.tokscaleSettings must run after installPackages"
      fi

      script=${esc script}
      # Comment lines are stripped so an explanatory sentence cannot match.
      # The merger call spans several lines, so the whole block is searched.
      if printf '%s' "$script" | grep -v '^[[:space:]]*#' \
        | grep -qE '(\|\|[[:space:]]*(true|:|echo)|;[[:space:]]*true|set \+e)'; then
        fail ${host'}": the tokscaleSettings activation script swallows the merger exit status"
      fi

      merger=$(printf '%s' "$script" | tr '\n' ' ' \
        | grep -oE -- '/nix/store/[^[:space:]]+/bin/agent-settings' | head -1 || true)
      if [ -z "$merger" ]; then
        fail ${host'}": the tokscaleSettings activation script does not invoke the packaged merger"
      fi

      settingsArg=$(printf '%s' "$script" | tr '\n' ' ' \
        | grep -oE -- '--settings[[:space:]]+[^[:space:]]+' | head -1 | awk '{print $2}' || true)
      if [ "$settingsArg" != /home/h82/.config/tokscale/settings.json ]; then
        fail ${host'}": the merger must be pointed at ~/.config/tokscale/settings.json, got: '$settingsArg'"
      fi

      declaredPath=$(printf '%s' "$script" | tr '\n' ' ' \
        | grep -oE -- '--declared[[:space:]]+/nix/store/[^[:space:]]+' | head -1 | awk '{print $2}' || true)
      if [ -z "$declaredPath" ]; then
        fail ${host'}": the tokscaleSettings activation script passes no declared document"
      elif ! python3 "$compareJson" "$declaredPath" ${declaredExpected}; then
        fail ${host'}": the declared settings drifted from the asserted values"
      elif [ -n "$merger" ]; then
        # AE3: runtime state and TUI-only keys survive while declared keys
        # return, driven through the exact merger and document activation uses.
        seeded=$TMPDIR/${hostName}-settings.json
        cp ${seededSettings} "$seeded"
        chmod 600 "$seeded"
        if ! env -i "$merger" --label Tokscale --settings "$seeded" --declared "$declaredPath"; then
          fail ${host'}": the activation merger refused the seeded settings file"
        elif ! python3 "$compareJson" "$seeded" ${mergedExpected}; then
          fail ${host'}": merging the seeded settings file did not yield the expected document"
        fi
      fi

      if [ ${esc (lib.boolToString settingsTargeted)} != "false" ]; then
        fail ${host'}": Home Manager must not target .config/tokscale/settings.json; Tokscale owns it"
      fi

      ${
        if homeFiles == null then
          ''fail ${host'}": no home-files"''
        else
          ''
            pricing=${homeFiles}/.config/tokscale/custom-pricing.json
            if [ ! -f "$pricing" ]; then
              fail ${host'}": missing .config/tokscale/custom-pricing.json"
            elif ! python3 "$compareJson" "$pricing" ${pricingExpected}; then
              fail ${host'}": custom-pricing.json differs from the dotfiles document"
            fi
          ''
      }

      manifests=$(printf '%s' ${esc installers} | grep -oE '/nix/store/[^[:space:]]+-manifest\.json' || true)
      if [ -z "$manifests" ]; then
        fail ${host'}": found no sops manifest"
      fi
      tokscaleSecrets=$(python3 - $manifests <<'PY'
      import json, sys
      for path in sys.argv[1:]:
          for secret in json.load(open(path)).get('secrets', []):
              if 'tokscale' in secret.get("name", "") or 'tokscale' in secret.get("key", ""):
                  print(secret.get('name'), secret.get('key'), secret.get('owner'), secret.get('mode'))
      PY
      )
      ${
        if production then
          ''
            if [ "$tokscaleSecrets" != "cli-auth/tokscale_token tokscale_token h82 0400" ]; then
              fail ${host'}": expected cli-auth/tokscale_token owned by h82 with mode 0400, got: '$tokscaleSecrets'"
            fi
            publisher=$(printf '%s' ${esc publisher} | grep -oE '/nix/store/[^[:space:]]+/bin/publish-cli-auth' | head -1 || true)
            if [ -z "$publisher" ]; then
              fail ${host'}": sops-install-secrets no longer runs publish-cli-auth"
            elif grep -q tokscale "$publisher"; then
              fail ${host'}": publish-cli-auth must not read the Tokscale token"
            fi
          ''
        else
          ''
            if [ -n "$tokscaleSecrets" ]; then
              fail ${host'}": a bootstrap host must not decrypt a Tokscale secret, got: '$tokscaleSecrets'"
            fi
          ''
      }
    '';

  seededSettings = pkgs.writeText "tokscale-seeded-settings.json" (
    builtins.toJSON {
      colorPalette = "green";
      autoRefreshEnabled = false;
      autoRefreshMs = 60000;
      tuiLightMode = true;
      usage.disabledProviders = [ "x" ];
      scanner = {
        opencodeDbPaths = [ "/tmp/db" ];
        bucketTimezone = "UTC";
      };
      autosubmit = {
        enabled = true;
        lastRunAtMs = 1700000000000;
        lastError = "boom";
      };
    }
  );

  mergedExpected = pkgs.writeText "tokscale-merged-settings.json" (
    builtins.toJSON {
      colorPalette = "blue";
      autoRefreshEnabled = true;
      autoRefreshMs = 30000;
      tuiLightMode = true;
      usage.disabledProviders = [ "x" ];
      scanner = {
        opencodeDbPaths = [ "/tmp/db" ];
        bucketTimezone = "Asia/Seoul";
      };
      autosubmit = {
        enabled = false;
        lastRunAtMs = 1700000000000;
        lastError = "boom";
      };
    }
  );

  compareJson = pkgs.writeText "compare-json.py" ''
    import json, sys
    sys.exit(0 if json.load(open(sys.argv[1])) == json.load(open(sys.argv[2])) else 1)
  '';
in
pkgs.runCommand "tokscale-tests" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  failed=0
  fail() {
    echo "$1" >&2
    failed=1
  }
  compareJson=${compareJson}

  ${assertHost "ThinkPad-X1-Carbon-Gen-11" true self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11}
  ${assertHost "ThinkPad-X1-Carbon-Gen-11-bootstrap" false
    self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap
  }
  ${assertHost "MS-7D91" true self.nixosConfigurations.MS-7D91}
  ${assertHost "MS-7D91-bootstrap" false self.nixosConfigurations.MS-7D91-bootstrap}

  if [ "$failed" != 0 ]; then
    exit 1
  fi
  touch $out
''
