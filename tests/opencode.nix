/*
  Check interface:

    import ./tests/opencode.nix { inherit pkgs self; }

  Asserts that every configuration `tests/lib/configurations.nix` yields gives
  h82 the OpenCode wrapper and the declared config merge, and that only the
  production configurations decrypt the Synthetic API key. Which side a
  configuration is on comes from the helper's `bootstrap` field, never from
  the sops manifest under test. It reads what the generations materialize --
  home-path, the rendered activation script and the sops manifests -- rather
  than the options they come from. Expected values are literals stated here,
  independently of home/h82/agents/opencode.nix and opencode-model.nix.

  Verifies, on every configuration:
  - home-path/bin/opencode is the packaged wrapper, reading the key from
    /run/secrets/cli-auth/synthetic_api_key.
  - home.activation.opencodeSettings and home.activation.opencodeService each
    run after installPackages, invoke the packaged merger without swallowing
    its exit status (the script, run with a failing merger in its place, fails
    too), point it at ~/.config/opencode/opencode.json and
    ~/.config/opencode/service.json respectively, and pass a declared document
    equal to the one stated here.
  - running that exact merger with that exact declared document reasserts the
    declared values and leaves every other key as it was, against a seeded
    divergent file (an MCP server, a 1.x plugin key, a user plugins entry, a
    user-added provider entry, and the stale syn: model alias that the
    declaration removes in opencode.json, a password and a port in
    service.json), and creates a missing file holding only the
    declared keys. The result is mode 0600 in every case. opencode.json drops
    the retired autoupdate key and the stale syn: alias, and allowlists the
    synthetic provider; service.json disables OpenCode's shared
    background server.
  - no Home Manager file targets .config/opencode/opencode.json or
    .config/opencode/service.json, and the generation's home-files hold no
    .config/opencode/AGENTS.md, which OpenCode loads in reviewer runs too.
  - home.activation.opencodeServiceStop runs after opencodeService and runs
    the installed wrapper's `opencode service stop`, so a server started
    before the service was disabled does not keep running.
  - a production configuration's sops manifest carries
    cli-auth/synthetic_api_key owned by h82 with mode 0400, its gh/glab
    publisher does not read that key, and a bootstrap configuration's
    manifests carry no Synthetic secret at all. Neither does one production
    configuration re-evaluated with my.cliAuth.enableSyntheticApiKey forced
    off.

  The wrapper's run-time behaviour is covered by the opencode-wrapper check,
  and the installed version and switches by the opencode check. This check
  never runs OpenCode.

  Every lookup carries an `or` fallback so a mutation that removes an entry
  reaches the builder as shell rather than failing evaluation. See
  .compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md
  The helper's guard runs first, so an empty configuration list, or one with no
  bootstrap output, fails the build instead of passing it. The builder collects
  every failure, so one red build names every broken assertion across every
  configuration.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self; };

  esc = value: lib.escapeShellArg (toString value);

  # Written as JSON text rather than a Nix attribute set so the comparison
  # cannot share a rendering path with the module.
  declaredExpected = pkgs.writeText "opencode-expected-settings.json" ''
    {
      "set": {
        "$schema": "https://opencode.ai/config.json",
        "model": "synthetic/hf:zai-org/GLM-5.3-Flash",
        "update": "disable",
        "share": "disabled"
      },
      "remove": ["autoupdate"],
      "own": {
        "enabled_providers": ["synthetic"]
      },
      "removePaths": [
        {"path": ["provider", "synthetic", "models"], "key": "syn:large:text"}
      ]
    }
  '';

  seededSettings = pkgs.writeText "opencode-seeded-settings.json" ''
    {
      "model": "anthropic/claude-sonnet",
      "autoupdate": true,
      "share": "auto",
      "theme": "tokyonight",
      "plugin": ["opencode-example-plugin"],
      "plugins": ["opencode-user-plugin@1.2.0"],
      "mcp": {
        "example": {"type": "local", "command": ["example-mcp"], "enabled": true}
      },
      "provider": {
        "anthropic": {"options": {"timeout": 600000}},
        "synthetic": {
          "options": {"timeout": 300000},
          "models": {
            "hf:zai-org/GLM-4.7": {"name": "GLM 4.7"},
            "syn:large:text": {"name": "syn:large:text"}
          }
        }
      }
    }
  '';

  mergedExpected = pkgs.writeText "opencode-merged-settings.json" ''
    {
      "$schema": "https://opencode.ai/config.json",
      "model": "synthetic/hf:zai-org/GLM-5.3-Flash",
      "update": "disable",
      "share": "disabled",
      "enabled_providers": ["synthetic"],
      "theme": "tokyonight",
      "plugin": ["opencode-example-plugin"],
      "plugins": ["opencode-user-plugin@1.2.0"],
      "mcp": {
        "example": {"type": "local", "command": ["example-mcp"], "enabled": true}
      },
      "provider": {
        "anthropic": {"options": {"timeout": 600000}},
        "synthetic": {
          "options": {"timeout": 300000},
          "models": {
            "hf:zai-org/GLM-4.7": {"name": "GLM 4.7"}
          }
        }
      }
    }
  '';

  createdExpected = pkgs.writeText "opencode-created-settings.json" ''
    {
      "$schema": "https://opencode.ai/config.json",
      "model": "synthetic/hf:zai-org/GLM-5.3-Flash",
      "update": "disable",
      "share": "disabled",
      "enabled_providers": ["synthetic"]
    }
  '';

  # OpenCode v2 shares one detached background server, spawned with the first
  # client's environment, unless service.json says disabled.
  serviceDeclaredExpected = pkgs.writeText "opencode-expected-service.json" ''
    {
      "set": {"disabled": true}
    }
  '';

  serviceSeeded = pkgs.writeText "opencode-seeded-service.json" ''
    {
      "disabled": false,
      "password": "fake-password",
      "port": 4096
    }
  '';

  serviceMergedExpected = pkgs.writeText "opencode-merged-service.json" ''
    {
      "disabled": true,
      "password": "fake-password",
      "port": 4096
    }
  '';

  serviceCreatedExpected = pkgs.writeText "opencode-created-service.json" ''
    {
      "disabled": true
    }
  '';

  # One declared merge entry: the activation name, the file it must target,
  # the declared document it must pass, and the seeded cases it is driven
  # through. A null seed is a file that does not exist yet.
  merges = [
    {
      name = "opencodeSettings";
      file = "/home/h82/.config/opencode/opencode.json";
      declared = declaredExpected;
      cases = [
        {
          label = "seeded";
          seed = seededSettings;
          expected = mergedExpected;
        }
        {
          label = "missing";
          seed = null;
          expected = createdExpected;
        }
      ];
    }
    {
      name = "opencodeService";
      file = "/home/h82/.config/opencode/service.json";
      declared = serviceDeclaredExpected;
      cases = [
        {
          label = "seeded";
          seed = serviceSeeded;
          expected = serviceMergedExpected;
        }
        {
          label = "missing";
          seed = null;
          expected = serviceCreatedExpected;
        }
      ];
    }
  ];

  assertMerge =
    host': hm: spec:
    let
      activation = hm.home.activation.${spec.name} or null;
      script = if activation == null then "" else (activation.data or "");
      runsAfterPackages = lib.elem "installPackages" (
        if activation == null then [ ] else (activation.after or [ ])
      );

    in
    ''
      ${lib.optionalString (activation == null) ''
        fail ${host'}": missing home.activation.${spec.name}"
      ''}
      if [ ${esc (lib.boolToString runsAfterPackages)} != "true" ]; then
        fail ${host'}": home.activation.${spec.name} must run after installPackages"
      fi

      script=${esc script}
      # Comment lines are stripped so an explanatory sentence cannot match.
      # The merger call spans several lines, so the whole block is searched.
      # A here-string, not a pipe: under pipefail an early grep -q match can
      # fail the writer and turn the condition false.
      uncommented=$(grep -v '^[[:space:]]*#' <<<"$script" || true)
      if grep -qE '(\|\|[[:space:]]*(true|:|echo)|;[[:space:]]*true|set \+e)' <<<"$uncommented"; then
        fail ${host'}": the ${spec.name} activation script swallows the merger exit status"
      fi

      flat=$(printf '%s' "$script" | tr '\n' ' ')
      merger=$(printf '%s' "$flat" \
        | grep -oE -- '/nix/store/[^[:space:]]+/bin/agent-settings' | head -1 || true)
      if [ -z "$merger" ]; then
        fail ${host'}": the ${spec.name} activation script does not invoke the packaged merger"
      else
        # Whatever form a suppression takes, the script run the way activation
        # runs it must fail when the merger does.
        stub=$TMPDIR/failing-agent-settings
        printf '#!%s\nexit 3\n' "$(command -v bash)" > "$stub"
        chmod +x "$stub"
        stubbed=''${script//"$merger"/"$stub"}
        if [ "$stubbed" = "$script" ]; then
          fail ${host'}": could not substitute a failing merger into the ${spec.name} activation script"
        elif bash -euo pipefail -c "$stubbed" >/dev/null 2>&1; then
          fail ${host'}": the ${spec.name} activation script succeeds when the merger fails"
        fi
      fi

      settingsArg=$(printf '%s' "$flat" \
        | grep -oE -- '--settings[[:space:]]+[^[:space:]]+' | head -1 | awk '{print $2}' || true)
      if [ "$settingsArg" != ${esc spec.file} ]; then
        fail ${host'}": the ${spec.name} merger must be pointed at ${spec.file}, got: '$settingsArg'"
      fi

      declaredPath=$(printf '%s' "$flat" \
        | grep -oE -- '--declared[[:space:]]+/nix/store/[^[:space:]]+' | head -1 | awk '{print $2}' || true)
      if [ -z "$declaredPath" ]; then
        fail ${host'}": the ${spec.name} activation script passes no declared document"
      elif ! python3 "$compareJson" "$declaredPath" ${spec.declared}; then
        fail ${host'}": the declared settings drifted from the asserted values"
      elif [ -n "$merger" ] && [ -z "''${merged["$merger $declaredPath"]:-}" ]; then
        # Keys OpenCode and its CLI wrote survive while the declared keys
        # return, driven through the exact merger and document activation uses.
        # Hosts sharing that merger and document would repeat the same runs.
        merged["$merger $declaredPath"]=1
        ${lib.concatMapStringsSep "\n" (case: ''
          target=$TMPDIR/${spec.name}-${case.label}.json
          rm -f "$target"
          ${lib.optionalString (case.seed != null) ''
            cp ${case.seed} "$target"
            chmod 644 "$target"
          ''}
          if ! env -i "$merger" --label ${esc spec.name} --settings "$target" --declared "$declaredPath"; then
            fail ${host'}": the ${spec.name} merger refused the ${case.label} file"
          elif ! python3 "$compareJson" "$target" ${case.expected} 600; then
            fail ${host'}": merging the ${case.label} ${spec.name} file did not yield the expected document at mode 0600"
          fi
        '') spec.cases}
      fi
    '';

  assertEntry =
    entry:
    let
      hostName = entry.name;
      # A production configuration decrypts the key unless the option is
      # forced off; the forced-off entries prove the option still gates it.
      decryptsKey = !entry.bootstrap && !(entry.keyForcedOff or false);
      hm = entry.user;
      homePath = hm.home.path or null;

      settingsTargeted = lib.any (
        file:
        lib.elem (file.target or "") [
          ".config/opencode/opencode.json"
          ".config/opencode/service.json"
        ]
      ) (lib.attrValues (hm.home.file or { }));

      # OpenCode v2 always loads this file, reviewer runs included, so the
      # instructions must reach it through the wrapper's added config instead.
      homeFiles = hm.home-files or null;
      globalAgents = if homeFiles == null then "" else "${homeFiles}/.config/opencode/AGENTS.md";

      serviceStop = hm.home.activation.opencodeServiceStop or null;
      serviceStopScript = if serviceStop == null then "" else (serviceStop.data or "");
      serviceStopAfterMerge = lib.elem "opencodeService" (
        if serviceStop == null then [ ] else (serviceStop.after or [ ])
      );

      # sops-nix installs through a systemd unit when my.cliAuth is enabled
      # and through the setupSecrets activation script otherwise, so both
      # places are searched for the manifests they hand the installer.
      sopsService = entry.config.systemd.services.sops-install-secrets or { };
      installers = lib.concatStringsSep " " (
        lib.toList (sopsService.serviceConfig.ExecStart or [ ])
        ++ [ (entry.config.system.activationScripts.setupSecrets.text or "") ]
      );
      publisher = lib.concatStringsSep " " (lib.toList (sopsService.serviceConfig.ExecStartPost or [ ]));

      host' = esc hostName;
    in
    ''
      ${
        if homePath == null then
          ''
            resolved=
            fail ${host'}": no home-path"
          ''
        else
          ''
            wrapper=${homePath}/bin/opencode
            if [ ! -x "$wrapper" ]; then
              fail ${host'}": home-path has no executable bin/opencode"
            else
              resolved=$(readlink -f "$wrapper")
              case "$resolved" in
                /nix/store/*-opencode-*/bin/opencode) ;;
                *) fail ${host'}": bin/opencode is not the packaged wrapper: $resolved" ;;
              esac
              if ! grep -Fxq -- "TOKEN_FILE='/run/secrets/cli-auth/synthetic_api_key'" "$resolved"; then
                fail ${host'}": the wrapper does not read /run/secrets/cli-auth/synthetic_api_key"
              fi
            fi
          ''
      }
      ${lib.concatMapStringsSep "\n" (assertMerge host' hm) merges}

      if [ ${esc (lib.boolToString settingsTargeted)} != "false" ]; then
        fail ${host'}": Home Manager must not target .config/opencode/opencode.json or service.json; OpenCode rewrites them"
      fi

      if [ -z ${esc globalAgents} ]; then
        fail ${host'}": no home-files"
      elif [ -e ${esc globalAgents} ] || [ -L ${esc globalAgents} ]; then
        fail ${host'}": Home Manager installs .config/opencode/AGENTS.md, which OpenCode loads in reviewer runs too"
      fi

      ${lib.optionalString (serviceStop == null) ''
        fail ${host'}": missing home.activation.opencodeServiceStop"
      ''}
      if [ ${esc (lib.boolToString serviceStopAfterMerge)} != "true" ]; then
        fail ${host'}": home.activation.opencodeServiceStop must run after opencodeService"
      fi
      # The stop must run the wrapper home-path installs, so it reaches the
      # server the same binary and config directory started.
      stopUncommented=$(grep -v '^[[:space:]]*#' <<<${esc serviceStopScript} || true)
      stopCommand=$(grep -oE '/nix/store/[^[:space:]]+/bin/opencode service stop' <<<"$stopUncommented" | head -1 || true)
      if [ -z "$stopCommand" ]; then
        fail ${host'}": home.activation.opencodeServiceStop does not run the packaged opencode service stop"
      elif [ -n "''${resolved:-}" ] && [ "$stopCommand" != "$resolved service stop" ]; then
        fail ${host'}": home.activation.opencodeServiceStop runs '$stopCommand', not the installed wrapper $resolved"
      fi

      manifests=$(printf '%s' ${esc installers} | grep -oE '/nix/store/[^[:space:]]+-manifest\.json' || true)
      if [ -z "$manifests" ]; then
        fail ${host'}": found no sops manifest"
      fi
      syntheticSecrets=$(python3 - $manifests <<'PY'
      import json, sys
      for path in sys.argv[1:]:
          for secret in json.load(open(path)).get("secrets", []):
              if "synthetic" in secret.get("name", "") or "synthetic" in secret.get("key", ""):
                  print(secret.get("name"), secret.get("key"), secret.get("owner"), secret.get("mode"))
      PY
      )
      ${
        if decryptsKey then
          ''
            if [ "$syntheticSecrets" != "cli-auth/synthetic_api_key synthetic_api_key h82 0400" ]; then
              fail ${host'}": expected cli-auth/synthetic_api_key owned by h82 with mode 0400, got: '$syntheticSecrets'"
            fi
            publisher=$(printf '%s' ${esc publisher} | grep -oE '/nix/store/[^[:space:]]+/bin/publish-cli-auth' | head -1 || true)
            if [ -z "$publisher" ]; then
              fail ${host'}": sops-install-secrets no longer runs publish-cli-auth"
            elif grep -q synthetic_api_key "$publisher"; then
              fail ${host'}": publish-cli-auth must not read the Synthetic API key"
            fi
          ''
        else
          ''
            if [ -n "$syntheticSecrets" ]; then
              fail ${host'}": a bootstrap configuration, or one with my.cliAuth.enableSyntheticApiKey off, must not decrypt a Synthetic secret, got: '$syntheticSecrets'"
            fi
          ''
      }
    '';

  # One production configuration re-evaluated with the key option forced off,
  # so the check proves the option, not only the bootstrap split, gates the
  # secret.
  keyForcedOff = map (
    entry:
    configurations.withTraitForcedOff "my.cliAuth.enableSyntheticApiKey" entry
    // {
      keyForcedOff = true;
    }
  ) (lib.take 1 configurations.production);

  compareJson = pkgs.writeText "compare-json.py" ''
    import json, os, stat, sys
    same = json.load(open(sys.argv[1])) == json.load(open(sys.argv[2]))
    mode_ok = len(sys.argv) < 4 or stat.S_IMODE(os.stat(sys.argv[1]).st_mode) == int(sys.argv[3], 8)
    sys.exit(0 if same and mode_ok else 1)
  '';
in
pkgs.runCommand "opencode-settings-tests" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  ${configurations.guard}
  ${lib.optionalString (keyForcedOff == [ ]) ''
    echo "no production configuration to re-evaluate with my.cliAuth.enableSyntheticApiKey off" >&2
    exit 1
  ''}
  failed=0
  fail() {
    echo "$1" >&2
    failed=1
  }
  compareJson=${compareJson}
  declare -A merged

  ${lib.concatMapStringsSep "\n" assertEntry (configurations.entries ++ keyForcedOff)}

  if [ "$failed" != 0 ]; then
    exit 1
  fi
  touch $out
''
