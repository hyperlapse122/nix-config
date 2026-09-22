{ pkgs, self }:
let
  inherit (pkgs) lib;

  esc = value: lib.escapeShellArg (toString value);

  packagedReconciler = (import ../packages/orca-tools.nix { inherit pkgs; }).orcaSettingsReconcile;

  assertHost =
    hostName: host:
    let
      userConfig = host.config.home-manager.users.h82;

      orcaPackage = lib.lists.findFirst (p: (p.pname or "") == "orca-ide") null (
        userConfig.home.packages or [ ]
      );

      service = userConfig.systemd.user.services.orca-settings-reconcile or null;
      serviceEnabled = if service == null then false else (service.enable or true);
      serviceType = if service == null then "" else (service.Service.Type or "");

      activation = userConfig.home.activation.orcaSettings or null;
      activationScript = if activation == null then "" else (activation.data or "");
      runsAfterPackages = lib.elem "installPackages" (
        if activation == null then [ ] else (activation.after or [ ])
      );

      packageAbsent = lib.optionalString (orcaPackage == null) ''
        echo 'missing orca-ide in home.packages on ${hostName}' >&2
        failed=1
      '';

      packagePresent = lib.optionalString (orcaPackage != null) ''
        if ! [ -f "${orcaPackage}/bin/orca-ide" ]; then
          echo 'orca package missing bin/orca-ide on ${hostName}' >&2
          failed=1
        fi
        if ! [ -f "${orcaPackage}/share/applications/orca.desktop" ]; then
          echo 'orca package missing share/applications/orca.desktop on ${hostName}' >&2
          failed=1
        fi
      '';

      serviceAbsent = lib.optionalString (service == null) ''
        echo 'missing systemd.user.services.orca-settings-reconcile on ${hostName}' >&2
        failed=1
      '';

      servicePresent = lib.optionalString (service != null) ''
        if [ ${esc (lib.boolToString serviceEnabled)} != "true" ]; then
          echo 'orca-settings-reconcile service must be enabled on ${hostName}' >&2
          failed=1
        fi
        if [ ${esc serviceType} != "oneshot" ]; then
          echo 'orca-settings-reconcile service must be type oneshot on ${hostName}, got: ${esc serviceType}' >&2
          failed=1
        fi
      '';

      activationAbsent = lib.optionalString (activation == null) ''
        echo 'missing home.activation.orcaSettings on ${hostName}' >&2
        failed=1
      '';

      activationPresent = lib.optionalString (activation != null) ''
        if [ ${esc (lib.boolToString runsAfterPackages)} != "true" ]; then
          echo 'home.activation.orcaSettings must run after installPackages on ${hostName}' >&2
          failed=1
        fi

        if ! printf '%s' ${esc activationScript} | grep -qF '/bin/orca-settings-reconcile'; then
          echo 'home.activation.orcaSettings must invoke orca-settings-reconcile on ${hostName}' >&2
          failed=1
        fi
      '';
    in
    ''
      ${packageAbsent}
      ${packagePresent}
      ${serviceAbsent}
      ${servicePresent}
      ${activationAbsent}
      ${activationPresent}
    '';

  hostChecks = lib.concatStringsSep "\n" [
    (assertHost "ThinkPad-X1-Carbon-Gen-11" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11)
    (assertHost "ThinkPad-X1-Carbon-Gen-11-bootstrap" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap)
  ];
in
pkgs.runCommand "orca-checks"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.bash
    ];
  }
  ''
    export PYTHONDONTWRITEBYTECODE=1

    # 1. Run reconciler unit tests with Python
    mkdir -p scripts tests
    cp ${../scripts/orca-settings-reconcile} scripts/orca-settings-reconcile
    chmod +x scripts/orca-settings-reconcile
    cp ${./test_orca_settings.py} tests/test_orca_settings.py
    python tests/test_orca_settings.py

    # 2. Verify packaged reconciler carries a store interpreter and executes cleanly
    interpreter=$(head -1 ${packagedReconciler}/bin/orca-settings-reconcile)
    case "$interpreter" in
      '#!'/nix/store/*) ;;
      *)
        echo "packaged reconciler must carry a store interpreter, got: $interpreter" >&2
        exit 1
        ;;
    esac
    ${packagedReconciler}/bin/orca-settings-reconcile --help >/dev/null

    # 3. Assert evaluated configuration across hosts
    failed=0
    ${hostChecks}

    if [ "$failed" -ne 0 ]; then
      exit 1
    fi

    touch $out
  ''
