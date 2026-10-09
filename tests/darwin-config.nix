/*
  Check interface:

    import ./tests/darwin-config.nix { inherit pkgs self linuxFixtures darwinFixtures; }

  `linuxFixtures` and `darwinFixtures` are tests/lib/linux-fixtures.nix and
  tests/lib/darwin-fixtures.nix. Evaluates the macOS fixture hosts on Linux,
  where no darwin derivation can be built, and renders what their options say
  into the builder. The materialized generation is read on a macOS builder by
  tests/darwin-outputs.nix.

  - Host discovery: every fixture whose host.nix names kind darwin is a macOS
    fixture and no other kind is; every macOS fixture yields a production and
    a bootstrap output.
  - GUI apps (modules/shared/darwin-apps.nix): every package a NixOS user has and no
    non-NixOS Linux fixture has, plus the 1Password GUI where NixOS enables
    it, has a macOS decision, and each decision is exactly one of a cask, a
    Nix package, or left out. The set is derived from the evaluated
    configurations, so a package added on NixOS fails here until it has one.
    Telegram maps to the telegram-desktop cask, the NixOS client, and the
    telegram cask (Telegram for macOS) is absent.
  - Homebrew: the casks are exactly the mapping's casks plus its macOS-only
    ones; an apply never removes an unlisted app and upgrades listed ones;
    every third-party cask's tap is tapped and trusted.
  - The user environment takes the non-NixOS path: production runs the
    host-secrets steps and bootstrap runs none; ~/.ssh/config names the host
    key; `nr` is nr-darwin; the YubiKey pinentry is
    the darwin filter, with pinentry_mac's Keychain checkbox unticked by
    default; VSCodium's settings live under Application Support; Ghostty has
    the NixOS font families and no nixpkgs package.
  - Containers: both variants init one rootful libkrun Podman machine with
    the configured memory and CPUs, reconcile an existing machine to them,
    keep the watchdog's VM alive across an agent reload at interactive
    priority, export the machine's socket to shells and GUI apps, write
    auth.json, and link `docker` to Podman; production adds the minikube
    login agent and bootstrap has none. No OrbStack cask, credHelpers merge,
    or Docker Hub index alias remains.
  - The system layer turns off store auto-optimisation, installs the shared
    font list, and records the host and variant in /etc/nix-config-host.
  - Xcode: postActivation installs (mas install, then mas get) or upgrades
    App Store id 497799835 before Home Manager runs, every mas call runs in
    the primary user's session with SUDO_UID and SUDO_GID, and every mas,
    xcode-select, and xcodebuild action sits in an `if !` guard, so none can
    abort the `set -e` activate script. homebrew.masApps stays empty and
    programs.mas off.
  - Android SDK: Home Manager links it at ~/Library/Android/sdk and declares
    no android-sdk data file; ANDROID_HOME and ANDROID_SDK_ROOT name that
    path, and the PATH assignment gains its emulator directory; the linked
    SDK builds one arm64-v8a Google APIs image per pinned platform and no
    x86_64 image.
  - Mobile devices: my.mobileDevices defaults to one ios and one android
    device and rejects an empty model or version; the mobileDevices step runs
    after linkGeneration and calls the mobile-devices helper only outside a
    dry run, from an `elif !` condition whose branch only echoes, so a
    failing helper cannot abort activation. The call passes /usr/bin/xcrun,
    the SDK root, every declared device, and the newest pinned API with an
    arm64-v8a image, which tests/lib/android-pin.nix reads from the pin. No
    non-NixOS Linux fixture has the step.

  Every comparison is rendered into the builder, so a failure names the
  fixture and the reason instead of aborting evaluation. No darwin store path
  is interpolated, so the check builds on Linux.
*/
{
  pkgs,
  self,
  linuxFixtures,
  darwinFixtures,
}:
let
  inherit (pkgs) lib;

  fail = message: ''
    echo ${lib.escapeShellArg message} >&2
    fail=1
  '';

  check = condition: message: lib.optionalString (!condition) (fail message);

  plain = builtins.unsafeDiscardStringContext;

  namesOf = packages: lib.unique (map (p: p.pname or (lib.getName p)) packages);

  androidPin = import ./lib/android-pin.nix { inherit lib; };

  hosts = import ../lib/hosts.nix { inherit lib; } ./fixtures/hosts;
  kindOf = fixture: (import (./fixtures/hosts + "/${fixture}/host.nix")).kind or null;

  assertDiscovery = lib.concatStrings [
    (check (hosts.darwin != [ ]) "tests/fixtures/hosts holds no macOS fixture host")
    (lib.concatMapStrings (
      fixture:
      check (
        kindOf fixture == "darwin"
      ) "${fixture}: listed as macOS, but host.nix names kind ${toString (kindOf fixture)}"
    ) hosts.darwin)
    (lib.concatMapStrings (
      fixture:
      check (
        kindOf fixture != "darwin"
      ) "${fixture}: host.nix names kind darwin, but it is listed as a Linux host"
    ) hosts.linux)
    (check (
      lib.sort lib.lessThan (lib.unique (map (e: e.fixture) darwinFixtures))
      == lib.sort lib.lessThan hosts.darwin
    ) "the macOS fixture assembly does not cover exactly the macOS fixture hosts")
    (lib.concatMapStrings (
      fixture:
      let
        variants = map (e: e.bootstrap) (lib.filter (e: e.fixture == fixture) darwinFixtures);
      in
      check (
        lib.elem false variants && lib.elem true variants
      ) "${fixture}: expected a production and a bootstrap output"
    ) hosts.darwin)
  ];

  # The NixOS-only package set the mapping must cover.
  nixosConfigs = lib.attrValues (
    lib.filterAttrs (name: _: !lib.hasSuffix "-bootstrap" name) self.nixosConfigurations
  );
  nixosNames = lib.unique (
    lib.concatMap (c: namesOf c.config.home-manager.users.h82.home.packages) nixosConfigs
  );
  linuxNames = lib.unique (lib.concatMap (e: namesOf e.host.home.config.home.packages) linuxFixtures);
  onePassword = lib.optional (lib.any (
    c: c.config.programs._1password-gui.enable
  ) nixosConfigs) "1password";
  required = lib.subtractLists linuxNames nixosNames ++ onePassword;

  mapping = import ../modules/shared/darwin-apps.nix;
  kinds = [
    "cask"
    "nix"
    "leftOut"
  ];
  expectedCasks = mapping.casks;

  assertMapping = lib.concatStrings [
    (check (required != [ ]) "no package is NixOS-only, so the mapping check would pass vacuously")
    (lib.concatMapStrings (
      name:
      check (
        mapping.apps ? ${name}
      ) "${name}: installed on NixOS but has no macOS decision in modules/shared/darwin-apps.nix"
    ) required)
    (lib.concatStrings (
      lib.mapAttrsToList (
        name: app:
        check (
          lib.length (lib.attrNames app) == 1 && lib.elem (lib.head (lib.attrNames app)) kinds
        ) "${name}: the macOS decision must be exactly one of cask, nix, or leftOut"
      ) mapping.apps
    ))
    # Pinned by name, not taken from the mapping: other assertions and the
    # docs rely on these casks, and dropping one from the mapping must fail.
    (lib.concatMapStrings
      (cask: check (lib.elem cask mapping.casks) "${cask} is not among the macOS casks")
      [
        "ghostty"
        "1password"
      ]
    )
    (check (!lib.elem "orbstack" mapping.casks) "orbstack is still among the macOS casks")
    # macOS runs the NixOS Telegram client, not Telegram for macOS.
    (check (
      mapping.apps.telegram-desktop or null == { cask = "telegram-desktop"; }
    ) "telegram-desktop: the macOS decision must be the telegram-desktop cask")
    (check (!lib.elem "telegram" mapping.casks) "telegram is still among the macOS casks")
  ];

  sort = lib.sort lib.lessThan;

  assertEntry =
    entry:
    let
      config = entry.host.config;
      user = config.home-manager.users.${config.my.user.name};
      activation = user.home.activation;
      pnames = namesOf user.home.packages;
      casks = map (cask: cask.name) config.homebrew.casks;
      taps = map (tap: tap.name) config.homebrew.taps;
      thirdParty = lib.filter (cask: mapping.tapOf cask != null) expectedCasks;
      sessionVariables = user.home.sessionVariables;
      ryukVariables = lib.filter (name: sessionVariables ? ${name}) [
        "TESTCONTAINERS_RYUK_CONTAINER_PRIVILEGED"
        "TESTCONTAINERS_RYUK_PRIVILEGED"
      ];
      # By target, so an entry renamed onto the drop-in directory is still caught.
      dropIns = lib.filter (target: lib.hasPrefix "containers/registries.conf.d" target) (
        map (file: file.target) (lib.filter (file: file.enable) (lib.attrValues user.xdg.configFile))
      );
      agents = user.launchd.agents;
      agentConfig = name: agents.${name}.config or { };
      watchdog = agentConfig "podman-machine-podman-machine-default";
      minikubeAgent = agentConfig "minikube";
      minikubeArgs = plain (lib.concatStringsSep " " (minikubeAgent.ProgramArguments or [ ]));
      minikubePath = plain (minikubeAgent.EnvironmentVariables.PATH or "");
      guiEnvironment = plain (
        lib.concatStringsSep " " ((agentConfig "container-environment").ProgramArguments or [ ])
      );
      machinesData = plain (activation.podmanMachines.data or "");
      machineInits = lib.length (lib.filter lib.isList (builtins.split "machine init " machinesData));
      resourcesStep = activation.podmanMachineResources or { };
      # The helper stops the machine, so a dry run must reach only the echo.
      resourcesBranches = lib.splitString "else" (plain (resourcesStep.data or ""));
      resourcesGuarded =
        lib.length resourcesBranches == 2
        && lib.hasInfix "if [[ -v DRY_RUN ]]; then" (lib.head resourcesBranches)
        && !lib.hasInfix "podman-machine-resources/bin" (lib.head resourcesBranches)
        && lib.hasInfix "podman-machine-resources/bin" (lib.last resourcesBranches);
      nixApps = lib.attrNames (lib.filterAttrs (_: app: app ? nix) mapping.apps);
      missingNixApps = lib.filter (
        name: !lib.elem name pnames && (name != "t3code-desktop" || user.my.t3.desktop.enable)
      ) nixApps;
      credentialHelper = lib.findFirst (
        p: (p.pname or "") == "docker-credential-sops"
      ) null user.home.packages;
      routingTable = credentialHelper.routingTable or { };
      codex = lib.findFirst (p: (p.pname or "") == "codex") null user.home.packages;
      sshText = plain user.my.ssh.configFile.drvAttrs.text;
      pinentry = user.services.gpg-agent.pinentry.package;
      vscodiumData = plain (activation.vscodiumSettings.data or "");
      marker = config.environment.etc."nix-config-host".text or "";
      production = !entry.bootstrap;
      # The Xcode step runs as root inside the activate script, which is
      # `set -e`; every command that can fail must sit in an `if !` condition.
      xcodeUser = config.system.primaryUser;
      masExe = plain (lib.getExe entry.host.pkgs.mas);
      postActivation = plain config.system.activationScripts.postActivation.text;
      homeManagerCall = "Activating home-manager configuration";
      beforeHomeManager = lib.head (lib.splitString homeManagerCall postActivation);
      xcodeLines = map lib.trim (lib.splitString "\n" beforeHomeManager);
      guarded = line: lib.hasPrefix "if ! " line || lib.hasPrefix "elif ! " line;
      masAsUser = ''/bin/launchctl asuser "$xcodeUid" /usr/bin/env SUDO_UID="$xcodeUid" SUDO_GID="$xcodeGid" ${masExe} '';
      masLines = lib.filter (lib.hasInfix masExe) xcodeLines;
      # Calls through the wrapper function, not its definition.
      masCalls = lib.filter (
        line: lib.hasInfix "xcodeMas " line && !lib.hasPrefix "xcodeMas()" line
      ) xcodeLines;
      xcodebuildActions = lib.filter (
        line:
        lib.hasInfix "-license accept" line
        || lib.hasInfix "-runFirstLaunch" line
        || lib.hasInfix "xcode-select -s" line
      ) xcodeLines;
      # Where T3 Code's device hub looks when ANDROID_HOME is unset.
      androidSdkRoot = "${config.my.user.home}/Library/Android/sdk";
      # By target, so an entry renamed onto the path is still found.
      androidSdkFile = lib.findFirst (file: file.enable && file.target == "Library/Android/sdk") null (
        lib.attrValues user.home.file
      );
      # One derivation per API level and image type, named after its ABIs.
      androidImages = map (image: image.name) (androidSdkFile.source.systemImages or [ ]);
      androidDataFiles = lib.filter (file: file.enable && file.target == "android-sdk") (
        lib.attrValues user.xdg.dataFile
      );
      # The PATH assignment itself, so another line naming the directory
      # cannot stand in for it.
      pathLines = lib.filter (lib.hasPrefix "export PATH=") (
        map lib.trim (lib.splitString "\n" (plain user.home.sessionVariablesExtra))
      );
      devicesStep = activation.mobileDevices or { };
      devicesData = plain (devicesStep.data or "");
      # The helper creates devices, so a dry run must reach only the echo:
      # its one call is the `elif !` condition after the DRY_RUN branch, and
      # activation is `set -e`, so a non-zero exit must reach only the one
      # echo of that branch, right before fi.
      devicesLines = lib.filter (line: line != "") (map lib.trim (lib.splitString "\n" devicesData));
      devicesCount = lib.length devicesLines;
      devicesLine =
        offset: if devicesCount > offset then lib.elemAt devicesLines (devicesCount - 1 - offset) else "";
      devicesCall = devicesLine 2;
      devicesGuarded =
        devicesCount >= 5
        && lib.head devicesLines == "if [[ -v DRY_RUN ]]; then"
        && lib.filter (lib.hasInfix "mobile-devices/bin/mobile-devices ") devicesLines == [ devicesCall ];
      devicesContained =
        lib.hasPrefix "elif ! " devicesCall
        && lib.hasSuffix "; then" devicesCall
        && lib.hasPrefix "echo \"mobileDevices: " (devicesLine 1)
        && lib.hasSuffix " >&2" (devicesLine 1)
        && devicesLine 0 == "fi";
      devices = user.my.mobileDevices or [ ];
      platformCount = platform: lib.length (lib.filter (device: device.platform == platform) devices);
    in
    lib.concatStrings [
      (check (sort casks == sort expectedCasks)
        "${entry.name}: homebrew.casks is ${builtins.toJSON (sort casks)}, the mapping gives ${builtins.toJSON (sort expectedCasks)}"
      )
      (check (config.homebrew.onActivation.cleanup == "none")
        "${entry.name}: homebrew cleanup is ${config.homebrew.onActivation.cleanup}, so an apply removes apps installed outside the list"
      )
      (check config.homebrew.onActivation.upgrade "${entry.name}: homebrew upgrade is off, so an apply never updates listed apps")
      (check config.homebrew.onActivation.autoUpdate "${entry.name}: homebrew autoUpdate is off, so brew bundle never refreshes cask metadata and upgrade sees no newer version")
      (check (missingNixApps == [ ])
        "${entry.name}: apps the mapping installs from Nix are missing: ${lib.concatStringsSep ", " missingNixApps}"
      )
      (check (user.my.t3.desktop.enable && lib.elem "t3code-desktop" pnames)
        "${entry.name}: the macOS fixture must enable and install the T3 Code desktop app, or its darwin-outputs assertions vanish"
      )
      (check (routingTable ? "docker.io" && !(routingTable ? "https://index.docker.io/v1/"))
        "${entry.name}: the credential helper must route docker.io and no longer the Docker Hub index alias"
      )
      (check (
        codex != null && !lib.hasInfix "bubblewrap" (plain (builtins.toJSON (codex.drvAttrs or { })))
      ) "${entry.name}: codex must be installed and must not run under bubblewrap")
      (lib.concatMapStrings (
        cask:
        check (
          lib.elem (mapping.tapOf cask) taps && lib.elem cask config.nix-homebrew.trust.casks
        ) "${entry.name}: ${cask} needs its tap tapped and the cask trusted"
      ) thirdParty)
      (check config.nix-homebrew.enable "${entry.name}: nix-homebrew is off, so a new Mac needs Homebrew installed by hand")
      (check (
        activation ? nixConfigSecretsStage == production
        && activation ? nixConfigSecretsPublish == production
      ) "${entry.name}: the host-secrets steps must run in production and never in bootstrap")
      (check (!activation ? dockerCredHelpers) "${entry.name}: the OrbStack credHelpers merge still runs")
      (check (
        lib.hasInfix "IdentityFile ${user.my.secrets.sshKey}" sshText
        && !lib.hasInfix "IdentityAgent" sshText
      ) "${entry.name}: ~/.ssh/config must name the host key and no agent socket")
      (check
        (
          machineInits == 1
          && lib.hasInfix "machine init podman-machine-default " machinesData
          && lib.hasInfix "--rootful" machinesData
          && lib.hasInfix "--memory 8192" machinesData
          && lib.hasInfix "--cpus 4" machinesData
        )
        "${entry.name}: activation must init exactly podman-machine-default, rootful, with 8192 MiB and 4 CPUs"
      )
      (check (
        (user.services.podman.settings.containers.machine.provider or null) == "libkrun"
        && activation ? podmanContainersConfig
      ) "${entry.name}: containers.conf must select the libkrun machine provider")
      (check
        (
          lib.elem "podmanMachines" (resourcesStep.after or [ ])
          && lib.hasInfix "podman-machine-resources" (plain (resourcesStep.data or ""))
          && lib.hasInfix "podman-machine-default 8192 4" (plain (resourcesStep.data or ""))
        )
        "${entry.name}: activation must reconcile the machine to 8192 MiB and 4 CPUs after podmanMachines"
      )
      (check resourcesGuarded "${entry.name}: a dry run must not run the machine reconciliation helper")
      (check (lib.hasInfix "TMPDIR=$(/usr/bin/getconf DARWIN_USER_TEMP_DIR)" (lib.last resourcesBranches)) "${entry.name}: the reconciliation helper must run with the user's temporary directory")
      (check
        (
          (watchdog.AbandonProcessGroup or null) == true
          && (watchdog.ProcessType or null) == "Interactive"
          && (watchdog.RunAtLoad or null) == true
        )
        "${entry.name}: the machine watchdog must abandon its process group, run at interactive priority, and start at load"
      )
      (check
        (
          lib.hasSuffix "podman/podman-machine-default-api.sock" (sessionVariables.DOCKER_HOST or "")
          && sessionVariables ? REGISTRY_AUTH_FILE
          && (sessionVariables.TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE or null) == "/var/run/docker.sock"
          && ryukVariables == [ ]
        )
        "${entry.name}: the session must name the machine's socket, auth.json and the VM's Docker socket, and no Ryuk privilege variable"
      )
      (check (
        lib.hasInfix "launchctl setenv DOCKER_HOST" guiEnvironment
        && lib.hasInfix "podman/podman-machine-default-api.sock" guiEnvironment
        && lib.hasInfix "launchctl setenv TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE" guiEnvironment
        && ((agentConfig "container-environment").RunAtLoad or null) == true
      ) "${entry.name}: a login agent must export the machine's socket to GUI apps")
      (check (lib.elem "docker-podman-compat" pnames) "${entry.name}: docker must be the Podman link")
      (check (
        activation ? containersAuth
      ) "${entry.name}: auth.json with the credential helpers must be written")
      (check (dropIns == [ ]) "${entry.name}: the store-linked registries.conf.d drop-in reached macOS")
      (check
        (
          if production then
            lib.hasInfix "minikube-darwin-start" minikubeArgs
            # The node gets half of the machine: 4096 MiB and 2 CPUs, last.
            && lib.hasSuffix " 4096 2" minikubeArgs
            && (minikubeAgent.RunAtLoad or null) == true
            && (minikubeAgent.KeepAlive.SuccessfulExit or null) == false
            && (minikubeAgent.AbandonProcessGroup or null) == true
            && lib.hasInfix "-podman-" minikubePath
            && lib.hasInfix "-minikube-" minikubePath
          else
            !agents ? minikube
        )
        "${entry.name}: the minikube login agent must run in production, retried on failure, and never in bootstrap"
      )
      (check (
        lib.elem "nr-darwin" pnames && !lib.elem "nr" pnames && !lib.elem "nr-linux" pnames
      ) "${entry.name}: nr must be nr-darwin")
      (check (
        lib.hasInfix "pinentry-card-darwin" (plain (pinentry.drvAttrs.installPhase or ""))
        && lib.hasInfix "pinentry-mac" (plain (pinentry.drvAttrs.installPhase or ""))
      ) "${entry.name}: the YubiKey pinentry must be the darwin filter in front of pinentry_mac")
      (check ((user.targets.darwin.defaults."org.gpgtools.pinentry-mac".UseKeychain or null) == false)
        "${entry.name}: pinentry_mac's UseKeychain default must be false, or Save in Keychain starts ticked"
      )
      (check (lib.hasInfix "Library/Application Support/VSCodium/User/settings.json" vscodiumData) "${entry.name}: the VSCodium settings merge must target Library/Application Support/VSCodium/User")
      (check (
        user.programs.ghostty.package == null
      ) "${entry.name}: Ghostty must come from the cask, not nixpkgs")
      (check (
        user.programs.ghostty.settings.font-family or [ ] == [
          "JetBrainsMono Nerd Font"
          "D2CodingLigature Nerd Font"
          "D2KodingLigature Nerd Font"
          "Twitter Color Emoji"
        ]
      ) "${entry.name}: Ghostty's font-family differs from the NixOS terminal's")
      (check (
        !config.nix.settings.auto-optimise-store
      ) "${entry.name}: auto-optimise-store must be off on macOS")
      (check (
        namesOf config.fonts.packages == namesOf (import ../modules/shared/font-packages.nix pkgs)
      ) "${entry.name}: the macOS font list differs from modules/shared/font-packages.nix")
      (check (
        lib.hasInfix "host=${entry.fixture}\n" marker
        && lib.hasInfix "variant=${if entry.bootstrap then "bootstrap" else "production"}\n" marker
      ) "${entry.name}: /etc/nix-config-host must record the host and variant")
      (check (lib.hasInfix homeManagerCall postActivation && masLines != [ ])
        "${entry.name}: postActivation must run the Xcode step, with mas, before Home Manager's activation"
      )
      (check (lib.all (lib.hasInfix masAsUser) masLines) "${entry.name}: every mas call must run through launchctl asuser with SUDO_UID and SUDO_GID of the primary user")
      (check (
        lib.elem "xcodeUid=$(/usr/bin/id -u ${xcodeUser} 2>/dev/null) || xcodeUid=" xcodeLines
        && lib.elem "xcodeGid=$(/usr/bin/id -g ${xcodeUser} 2>/dev/null) || xcodeGid=" xcodeLines
      ) "${entry.name}: the Xcode step must resolve the uid and gid of ${xcodeUser} at activation time")
      (check
        (
          lib.all (line: lib.hasSuffix " \"$@\"" line) masLines && masCalls != [ ] && lib.all guarded masCalls
        )
        "${entry.name}: every mas call must be guarded by if !, so a failed App Store call cannot abort activation"
      )
      (check (lib.elem "if ! xcodeMas install 497799835 && ! xcodeMas get 497799835; then" xcodeLines) "${entry.name}: Xcode (497799835) must be installed with mas install, falling back to mas get")
      (check (lib.elem "elif ! xcodeMas upgrade 497799835; then" xcodeLines) "${entry.name}: an installed Xcode must be upgraded with mas upgrade 497799835")
      (check (lib.any (lib.hasInfix "sign in to the App Store") xcodeLines) "${entry.name}: a failed App Store install must print a message naming the App Store sign-in")
      (check
        (
          lib.length xcodebuildActions == 3
          && lib.all (
            line:
            guarded line
            && (lib.hasInfix "/usr/bin/xcodebuild " line || lib.hasInfix "/usr/bin/xcode-select " line)
          ) xcodebuildActions
          && lib.elem "if ! /usr/bin/xcodebuild -license check >/dev/null 2>&1; then" xcodeLines
          && lib.elem "if ! /usr/bin/xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then" xcodeLines
        )
        "${entry.name}: xcode-select, the license, and first launch must run by absolute path, only when pending, guarded by if !"
      )
      (check (config.homebrew.masApps == { } && !(config.programs.mas.enable or false))
        "${entry.name}: homebrew.masApps must stay empty and programs.mas off; both can abort or end activation"
      )
      (check (androidSdkFile != null && androidDataFiles == [ ])
        "${entry.name}: the Android SDK must be linked at ~/Library/Android/sdk, and no android-sdk data file declared"
      )
      (check
        (
          (sessionVariables.ANDROID_HOME or null) == androidSdkRoot
          && (sessionVariables.ANDROID_SDK_ROOT or null) == androidSdkRoot
          && lib.any (
            line:
            lib.hasInfix ":${androidSdkRoot}/emulator:" line
            || lib.hasInfix ":${androidSdkRoot}/emulator\"" line
          ) pathLines
        )
        "${entry.name}: ANDROID_HOME and ANDROID_SDK_ROOT must be ${androidSdkRoot}, and PATH must gain its emulator directory"
      )
      (check
        (
          lib.length androidImages == lib.length androidPin.platforms
          && lib.all (
            name: lib.hasInfix "-google_apis-arm64-v8a" name && !lib.hasInfix "x86_64" name
          ) androidImages
        )
        "${entry.name}: the Android SDK must build one arm64-v8a Google APIs image per pinned platform and no x86_64 image, got ${builtins.toJSON androidImages}"
      )
      (check (
        devicesStep != { } && lib.elem "linkGeneration" (devicesStep.after or [ ])
      ) "${entry.name}: activation must run the mobileDevices step after linkGeneration")
      (check devicesGuarded "${entry.name}: a dry run must not run the mobile-devices helper")
      (check devicesContained "${entry.name}: the mobile-devices helper call must be an elif ! condition whose branch only echoes, so a non-zero exit cannot abort activation")
      (check (platformCount "ios" == 1 && platformCount "android" == 1)
        "${entry.name}: my.mobileDevices must default to one ios and one android device, got ${builtins.toJSON devices}"
      )
      (check
        (
          lib.hasInfix "--xcrun /usr/bin/xcrun " devicesCall
          && lib.hasInfix "--sdk-root ${lib.escapeShellArg androidSdkRoot} " devicesCall
          && lib.all (device: lib.hasInfix (androidPin.deviceArg device) devicesCall) devices
        )
        "${entry.name}: the mobile-devices helper must get /usr/bin/xcrun, ${androidSdkRoot}, and every declared device"
      )
      (check (lib.hasInfix "--java-home ${lib.escapeShellArg (plain user.programs.java.package.home)} " devicesCall) "${entry.name}: the mobile-devices helper must get --java-home ${user.programs.java.package.home}, the JDK programs.java installs, because activation does not set JAVA_HOME")
      (check (lib.hasInfix "--android-api ${lib.escapeShellArg androidPin.newestArm64Api} " devicesCall) "${entry.name}: the mobile-devices helper must get --android-api ${androidPin.newestArm64Api}, the newest pinned API with an arm64-v8a image")
    ];

  # An empty model or version would render `--device ios:`, which the helper
  # rejects as a usage error before it reaches any device, so the option
  # types must refuse it at evaluation. The module is evaluated alone, with
  # option checking off so its other definitions stay unforced; the valid
  # list is the control that keeps the two rejections from passing vacuously.
  mobileDevicesWith =
    devices:
    let
      evaluated = lib.evalModules {
        modules = [
          ../home/h82/dev/mobile-devices.nix
          {
            _module.check = false;
            my.mobileDevices = devices;
          }
        ];
        specialArgs = { inherit pkgs; };
      };
    in
    (builtins.tryEval (builtins.deepSeq evaluated.config.my.mobileDevices true)).success;
  assertMobileDeviceTypes = lib.concatStrings [
    (check (mobileDevicesWith [
      {
        platform = "ios";
        model = "iPhone 18 Pro";
        version = "27.0";
      }
    ]) "my.mobileDevices rejects a valid device, so the empty-value checks below prove nothing")
    (check (
      !mobileDevicesWith [
        {
          platform = "ios";
          model = "";
        }
      ]
    ) "my.mobileDevices accepts an empty model, which renders --device ios: and fails the helper")
    (check (
      !mobileDevicesWith [
        {
          platform = "android";
          model = "pixel_9";
          version = "";
        }
      ]
    ) "my.mobileDevices accepts an empty version")
  ];

  # Device creation is macOS-only; the module must not reach other hosts.
  assertNoDevicesElsewhere = lib.concatStrings [
    (check (
      linuxFixtures != [ ]
    ) "no non-NixOS Linux fixture, so the mobileDevices absence check would pass vacuously")
    (lib.concatMapStrings (
      e:
      check (
        !e.host.home.config.home.activation ? mobileDevices
      ) "${e.name}: a non-NixOS Linux host runs the mobileDevices activation step"
    ) linuxFixtures)
  ];
in
pkgs.runCommand "darwin-config" { } ''
  fail=0
  ${lib.optionalString (darwinFixtures == [ ]) (
    fail "tests/fixtures/hosts holds no macOS fixture host"
  )}
  ${assertDiscovery}
  ${assertMapping}
  ${lib.concatMapStrings assertEntry darwinFixtures}
  ${assertNoDevicesElsewhere}
  ${assertMobileDeviceTypes}
  [ "$fail" = 0 ] || exit 1
  touch "$out"
''
