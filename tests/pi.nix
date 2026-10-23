/*
  Check interface:

    import ./tests/pi.nix { inherit pkgs self fixtures; }

  Asserts that every Home Manager user environment `tests/lib/configurations.nix`
  yields (the NixOS configurations' h82 users and the non-NixOS fixture hosts')
  gives h82 Pi and the declared merges of its model and settings files. It
  reads what the generations materialize -- home-path and the rendered
  activation script -- rather than the options they come from. The expected
  values are literals stated in tests/pi_declared.py, independently of
  home/h82/agents/pi.nix, except the model IDs, which come from
  home/h82/agents/synthetic-models.nix, and the prices, which come from the
  committed snapshot, home/h82/agents/synthetic-catalog.json.

  Verifies, on every user:
  - home-path/bin/pi is the packaged wrapper, and home-path/bin/pi-synthetic-key
    and home-path/bin/pi-openrouter-key the packaged key helpers.
  - home.activation.piModels and home.activation.piSettings each run after
    installPackages, invoke the packaged merger without swallowing its exit
    status (the script, run with a failing merger in its place, fails too),
    point it at ~/.pi/agent/models.json and ~/.pi/agent/settings.json
    respectively, and pass the declared document tests/pi_declared.py checks:
    - the Synthetic provider's api, baseUrl, and an apiKey that is the `!`
      command naming the installed key helper's store path, with no key and no
      key-file path in the document;
    - exactly one model per source entry, each carrying the catalog's name,
      context window, output limit, input modalities, and prices times one
      million, and a thinkingLevelMap that sends exactly the efforts the
      snapshot lists (GLM 5.3 has no xhigh key; DeepSeek sends off as none);
    - settings.json declaring the synthetic provider, the source's default
      model, defaultProjectTrust never, and each model's startup level, with
      DeepSeek at its text-generation effort.
    - the retired-model list, hf:moonshotai/Kimi-K3 today, as one removeEntries entry over
      providers.synthetic.models by id and one removePaths entry per ID
      under modelThinkingLevels.
  - running that exact merger over those documents keeps a hand-added model
    and a second provider in models.json, reasserts the declared entries, is
    idempotent, creates a missing file, and writes mode 0600 (AE4), and,
    with a fixture ID added to a copy of each declaration, drops that ID's
    model entry and thinking level while a hand-added model's stay; a
    seeded hf:moonshotai/Kimi-K3 entry and thinking level go under the real
    declaration.
  - no Home Manager file targets .pi/agent/models.json or .pi/agent/settings.json,
    because Pi rewrites both.

  Pi reads both API keys: the Synthetic key through the key helper and Exa
  through its web search. Verifies, on every NixOS configuration (a separate
  pass behind `configurations.guard`, because the non-NixOS fixtures have no
  sops manifest): a production configuration decrypts `synthetic_api_key` and
  `exa_api_key` to cli-auth/ with mode 0400 owned by h82, and its gh/glab
  publisher reads neither; a bootstrap configuration decrypts neither; and one
  production configuration re-evaluated with `my.cliAuth.enableSyntheticApiKey`
  or `my.cliAuth.enableExaApiKey` forced off drops only its own key. Which side
  a configuration is on comes from the helper's `bootstrap` field, never from
  the sops manifest under test.

  This check never runs Pi: extension loading, thinking levels, and the
  provider's behavior are covered by the live probes in docs/verification.md.

  Every lookup carries an `or` fallback so a mutation that removes an entry
  reaches the builder as shell rather than failing evaluation. See
  .compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md
  The helper's guard runs first, so an empty list, or one with no bootstrap
  output or no user of either kind, fails the build instead of passing it. The
  builder collects every failure, so one red build names every broken
  assertion across every user.
*/
{
  pkgs,
  self,
  fixtures ? import ./lib/linux-fixtures.nix { inherit (self) inputs; },
}:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self fixtures; };

  esc = value: lib.escapeShellArg (toString value);

  models = import ../home/h82/agents/synthetic-models.nix;
  ids = builtins.toJSON {
    glm = models.glm.id;
    glmFlash = models.glmFlash.id;
    deepseek = models.deepseek.id;
  };
  snapshot = ../home/h82/agents/synthetic-catalog.json;
  checker = ./pi_declared.py;

  # The file each merge must target, below the user's home directory.
  merges = [
    {
      name = "piModels";
      file = ".pi/agent/models.json";
    }
    {
      name = "piSettings";
      file = ".pi/agent/settings.json";
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
      if [ "$settingsArg" != ${esc "${hm.home.homeDirectory}/${spec.file}"} ]; then
        fail ${host'}": the ${spec.name} merger must be pointed at ~/${spec.file}, got: '$settingsArg'"
      fi

      declaredPath=$(printf '%s' "$flat" \
        | grep -oE -- '--declared[[:space:]]+/nix/store/[^[:space:]]+' | head -1 | awk '{print $2}' || true)
      if [ -z "$declaredPath" ]; then
        fail ${host'}": the ${spec.name} activation script passes no declared document"
      fi
      declared_${spec.name}=$declaredPath
    '';

  assertEntry =
    entry:
    let
      host' = esc "${entry.name} (${entry.kind})";
      hm = entry.user;
      homePath = hm.home.path or null;

      targeted = lib.any (
        file:
        lib.elem (file.target or "") [
          ".pi/agent/models.json"
          ".pi/agent/settings.json"
        ]
      ) (lib.attrValues (hm.home.file or { }));
    in
    ''
      declared_piModels=
      declared_piSettings=
      helper=
      merger=
      ${
        if homePath == null then
          ''
            fail ${host'}": no home-path"
          ''
        else
          ''
            if [ ! -x ${homePath}/bin/pi ]; then
              fail ${host'}": home-path has no executable bin/pi"
            else
              resolved=$(readlink -f ${homePath}/bin/pi)
              case "$resolved" in
                /nix/store/*-pi-*/bin/pi) ;;
                *) fail ${host'}": bin/pi is not the packaged wrapper: $resolved" ;;
              esac
            fi
            if [ ! -x ${homePath}/bin/pi-synthetic-key ]; then
              fail ${host'}": home-path has no executable bin/pi-synthetic-key"
            else
              helper=$(readlink -f ${homePath}/bin/pi-synthetic-key)
              case "$helper" in
                /nix/store/*-pi-*/bin/pi-synthetic-key) ;;
                *) fail ${host'}": bin/pi-synthetic-key is not the packaged helper: $helper"; helper= ;;
              esac
            fi
            if [ ! -x ${homePath}/bin/pi-openrouter-key ]; then
              fail ${host'}": home-path has no executable bin/pi-openrouter-key"
            else
              case "$(readlink -f ${homePath}/bin/pi-openrouter-key)" in
                /nix/store/*-pi-*/bin/pi-openrouter-key) ;;
                *) fail ${host'}": bin/pi-openrouter-key is not the packaged helper: $(readlink -f ${homePath}/bin/pi-openrouter-key)" ;;
              esac
            fi
          ''
      }
      ${lib.concatMapStringsSep "\n" (assertMerge host' hm) merges}

      if [ ${esc (lib.boolToString targeted)} != "false" ]; then
        fail ${host'}": Home Manager must not target .pi/agent/models.json or settings.json; Pi rewrites them"
      fi

      # One run of the semantic checks per distinct merger, pair of documents
      # and helper: users sharing them would repeat the same runs.
      if [ -n "$declared_piModels" ] && [ -n "$declared_piSettings" ] && [ -n "$helper" ] && [ -n "$merger" ]; then
        if [ -z "''${checked["$merger $declared_piModels $declared_piSettings $helper"]:-}" ]; then
          checked["$merger $declared_piModels $declared_piSettings $helper"]=1
          runs=$((runs + 1))
          if ! output=$(python3 -I ${checker} "$merger" "$declared_piModels" "$declared_piSettings" ${snapshot} "$helper" "$TMPDIR/work-$runs" ${esc ids} 2>&1); then
            fail ${host'}": the declared Pi documents failed:"$'\n'"$output"
          fi
        fi
      fi
    '';

  # The API keys a production configuration decrypts, each with the option
  # that gates it.
  apiKeySecrets = [
    {
      label = "Synthetic";
      match = "synthetic";
      file = "synthetic_api_key";
      option = "my.cliAuth.enableSyntheticApiKey";
    }
    {
      label = "Exa";
      match = "exa_api";
      file = "exa_api_key";
      option = "my.cliAuth.enableExaApiKey";
    }
  ];

  # One production configuration re-evaluated with each key option forced
  # off, so the check proves the option, not only the bootstrap split, gates
  # that secret and leaves the other.
  keyForcedOff = lib.concatMap (
    secret:
    map (
      entry:
      configurations.withTraitForcedOff secret.option entry
      // {
        forcedOff = secret.option;
      }
    ) (lib.take 1 configurations.production)
  ) apiKeySecrets;

  assertApiKeys =
    entry:
    let
      forcedOff = entry.forcedOff or null;
      host' = esc entry.name;

      # sops-nix installs through a systemd unit when my.cliAuth is enabled
      # and through the setupSecrets activation script otherwise, so both
      # places are searched for the manifests they hand the installer.
      sopsService = entry.config.systemd.services.sops-install-secrets or { };
      installers = lib.concatStringsSep " " (
        lib.toList (sopsService.serviceConfig.ExecStart or [ ])
        ++ [ (entry.config.system.activationScripts.setupSecrets.text or "") ]
      );
      publisher = lib.concatStringsSep " " (lib.toList (sopsService.serviceConfig.ExecStartPost or [ ]));
    in
    ''
      manifests=$(printf '%s' ${esc installers} | grep -oE '/nix/store/[^[:space:]]+-manifest\.json' || true)
      if [ -z "$manifests" ]; then
        fail ${host'}": found no sops manifest"
      fi
      publisher=$(printf '%s' ${esc publisher} | grep -oE '/nix/store/[^[:space:]]+/bin/publish-cli-auth' | head -1 || true)
      ${lib.concatMapStringsSep "\n" (
        secret:
        let
          decrypts = !entry.bootstrap && forcedOff != secret.option;
        in
        ''
          secrets=$(python3 - ${secret.match} $manifests <<'PY'
          import json, sys
          match = sys.argv[1]
          for path in sys.argv[2:]:
              for found in json.load(open(path)).get("secrets", []):
                  if match in found.get("name", "") or match in found.get("key", ""):
                      print(found.get("name"), found.get("key"), found.get("owner"), found.get("mode"))
          PY
          )
          ${
            if decrypts then
              ''
                if [ "$secrets" != "cli-auth/${secret.file} ${secret.file} h82 0400" ]; then
                  fail ${host'}": expected cli-auth/${secret.file} owned by h82 with mode 0400, got: '$secrets'"
                fi
                if [ -z "$publisher" ]; then
                  fail ${host'}": sops-install-secrets no longer runs publish-cli-auth"
                elif grep -q ${secret.file} "$publisher"; then
                  fail ${host'}": publish-cli-auth must not read the ${secret.label} API key"
                fi
              ''
            else
              ''
                if [ -n "$secrets" ]; then
                  fail ${host'}": a bootstrap configuration, or one with ${secret.option} off, must not decrypt the ${secret.label} secret, got: '$secrets'"
                fi
              ''
          }
        ''
      ) apiKeySecrets}
    '';
in
pkgs.runCommand "pi-settings-tests" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  ${configurations.userGuard}
  ${configurations.guard}
  ${lib.optionalString (lib.length keyForcedOff != lib.length apiKeySecrets) ''
    echo "no production configuration to re-evaluate with each API key option off" >&2
    exit 1
  ''}
  failed=0
  fail() {
    echo "$1" >&2
    failed=1
  }
  declare -A checked
  runs=0

  ${lib.concatMapStringsSep "\n" assertEntry configurations.userEntries}

  ${lib.concatMapStringsSep "\n" assertApiKeys (configurations.entries ++ keyForcedOff)}

  if [ "$failed" != 0 ]; then
    exit 1
  fi
  touch $out
''
