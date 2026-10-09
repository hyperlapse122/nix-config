/*
  Check interface:

    import ./tests/darwin-outputs.nix { inherit pkgs darwinFixtures; }

  `pkgs` is nixpkgs for aarch64-darwin and `darwinFixtures` is
  tests/lib/darwin-fixtures.nix. Builds on a macOS builder only, and reads
  what the macOS fixture hosts materialize, both variants, where
  tests/darwin-config.nix reads their options on Linux:

  - the Home Manager activation script stages host secrets before
    writeBoundary and publishes them after linkGeneration, in production
    only;
  - the session names the Podman machine's API socket and no Ryuk privilege
    variable, the generation links no containers/ or systemd user file, the
    containers.conf activation installs selects libkrun, `docker` is the
    profile's `podman`, the machine watchdog's agent abandons its process
    group at interactive priority, a login agent exports the socket to GUI
    apps, and the minikube login agent exists in production only;
  - gpg-agent.conf names the darwin pinentry filter, whose proxy delegates to
    pinentry_mac, with both cache TTLs at 0, and scdaemon.conf is the shared
    one; activation imports pinentry_mac's defaults with UseKeychain false;
  - Ghostty's config lists the NixOS font families in order;
  - `nr` on PATH is nr-darwin;
  - the VSCodium settings merge targets Application Support;
  - ~/Library/Android/sdk holds what T3 Code's device hub needs:
    cmdline-tools/latest/bin/avdmanager, platform-tools/adb, an arm64-v8a
    Google APIs system.img for every platform the pin file names, and an
    emulator/emulator wrapper that defaults ANDROID_HOME and ANDROID_SDK_ROOT
    to ~/Library/Android/sdk before it execs the store emulator; PATH gains
    the emulator directory;
  - the activation script runs the mobileDevices step after linkGeneration,
    and it calls the built mobile-devices helper with /usr/bin/xcrun, every
    declared device, and the newest pinned API with an arm64-v8a image;
  - with my.t3.desktop.enable, the T3 Code nightly bundle is in the profile,
    its main executable is byte-identical to the release zip's, and a launch
    agent sets T3CODE_DISABLE_AUTO_UPDATE=1;
  - the system's nix.conf keeps store auto-optimisation off,
    /etc/nix-config-host records the host and variant, the Brewfile lists the
    expected casks, and the shared fonts are installed;
  - the nix-homebrew setup script is built with autoMigrate on, so the first
    apply takes over an existing /opt/homebrew instead of stopping.

  Every comparison is rendered into the builder, so a failure names the
  fixture and the reason.
*/
{ pkgs, darwinFixtures }:
let
  inherit (pkgs) lib;

  mapping = import ../modules/shared/darwin-apps.nix;
  expectedCasks = lib.sort lib.lessThan mapping.casks;

  # Read from the pin, not the module: androidenv silently drops an ABI the
  # pin lacks, so every pinned platform must still carry its arm64 image.
  androidPlatforms = lib.attrNames (lib.importJSON ../packages/android-sdk-repo.json)
    .packages.platforms;

  # Computed from the pin rather than taken from the module, so a wrong API
  # in the module fails. Keys mix "36" and "37.0", hence compareVersions.
  newestArm64Api =
    lib.foldl'
      (newest: api: if newest == null || builtins.compareVersions api newest > 0 then api else newest)
      null
      (
        lib.attrNames (
          lib.filterAttrs (
            _: image: lib.elem "arm64-v8a" (lib.attrNames (image.google_apis or { }))
          ) (lib.importJSON ../packages/android-sdk-repo.json).images
        )
      );

  fontFamilies = [
    "JetBrainsMono Nerd Font"
    "D2CodingLigature Nerd Font"
    "D2KodingLigature Nerd Font"
    "Twitter Color Emoji"
  ];

  assertEntry =
    entry:
    let
      config = entry.host.config;
      user = config.home-manager.users.${config.my.user.name};
      generation = user.home.activationPackage;
      system = entry.host.system;
      t3Desktop = lib.findFirst (p: (p.pname or "") == "t3code-desktop") null user.home.packages;
      production = if entry.bootstrap then "0" else "1";
      deviceArgs = map (
        device:
        "--device ${
          lib.escapeShellArg (
            "${device.platform}:${device.model}"
            + lib.optionalString (device.version != null) ":${device.version}"
          )
        }"
      ) (user.my.mobileDevices or [ ]);
    in
    ''
      name=${lib.escapeShellArg entry.name}
      gen=${generation}
      sys=${system}
      production=${production}
      variant=${if entry.bootstrap then "bootstrap" else "production"}

      # The line an activation step starts on, or 0 when it is absent.
      step() { grep -n "_iNote \"Activating %s\" \"$1\"" "$gen/activate" | head -n1 | cut -d: -f1 || true; }
      stage=$(step nixConfigSecretsStage); stage=''${stage:-0}
      publish=$(step nixConfigSecretsPublish); publish=''${publish:-0}
      boundary=$(step writeBoundary); boundary=''${boundary:-0}
      link=$(step linkGeneration); link=''${link:-0}
      if [ "$boundary" = 0 ] || [ "$link" = 0 ]; then
        bad "the activation script has no writeBoundary or linkGeneration step"
      elif [ "$production" = 1 ]; then
        [ "$stage" != 0 ] && [ "$stage" -lt "$boundary" ] \
          || bad "host-secrets stage must run before writeBoundary"
        [ "$publish" -gt "$link" ] || bad "host-secrets publish must run after linkGeneration"
      else
        [ "$stage" = 0 ] && [ "$publish" = 0 ] \
          || bad "bootstrap must run no host-secrets step"
      fi
      [ "$(step dockerCredHelpers)" = "" ] || bad "the OrbStack credHelpers merge still runs"

      vars=$gen/home-path/etc/profile.d/hm-session-vars.sh
      [ -f "$vars" ] || bad "no hm-session-vars.sh in the profile"
      grep -q 'DOCKER_HOST=.*podman/podman-machine-default-api.sock' "$vars" \
        || bad "DOCKER_HOST does not name the Podman machine's API socket"
      grep -q 'REGISTRY_AUTH_FILE=' "$vars" || bad "REGISTRY_AUTH_FILE is not in the session"
      grep -q 'TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=.*/var/run/docker.sock' "$vars" \
        || bad "TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE does not name the VM's Docker socket"
      for v in TESTCONTAINERS_RYUK_PRIVILEGED TESTCONTAINERS_RYUK_CONTAINER_PRIVILEGED; do
        if grep -q "$v=" "$vars"; then bad "the Linux Ryuk variable $v reached the session"; fi
      done
      # The VM mounts ~/.config/containers, where a store link would dangle.
      [ ! -e "$gen/home-files/.config/containers" ] || bad "store-linked containers/ files reached macOS"
      [ ! -e "$gen/home-files/.config/systemd" ] || bad "systemd user files reached macOS"

      containersconf=$(grep -o -m1 '/nix/store/[a-z0-9]*-containers.conf' "$gen/activate" || true)
      if [ -z "$containersconf" ]; then
        bad "activation installs no containers.conf"
      else
        grep -qx 'provider *= *"libkrun"' "$containersconf" \
          || bad "containers.conf does not select the libkrun machine provider"
      fi
      [ "$(readlink -f "$gen/home-path/bin/docker")" = "$(readlink -f "$gen/home-path/bin/podman")" ] \
        || bad "docker on PATH is not the profile's podman"

      # A plist with its whitespace removed, so a key and its value are adjacent.
      agent() { tr -d ' \t\n' 2>/dev/null < "$gen/LaunchAgents/org.nix-community.home.$1.plist" || true; }
      watchdog=$(agent podman-machine-podman-machine-default)
      case $watchdog in *'<key>AbandonProcessGroup</key><true/>'*) ;; *) bad "the machine watchdog does not abandon its process group" ;; esac
      case $watchdog in *'<key>ProcessType</key><string>Interactive</string>'*) ;; *) bad "the machine watchdog does not run at interactive priority" ;; esac
      guienv=$(agent container-environment)
      case $guienv in
        *'launchctlsetenvDOCKER_HOST'*podman/podman-machine-default-api.sock*) ;;
        *) bad "no login agent exports the machine's socket to GUI apps" ;;
      esac
      case $guienv in
        *'launchctlsetenvTESTCONTAINERS_DOCKER_SOCKET_OVERRIDE/var/run/docker.sock'*) ;;
        *) bad "no login agent exports the VM's Docker socket to GUI apps" ;;
      esac
      minikube=$(agent minikube)
      if [ "$production" = 1 ]; then
        case $minikube in *minikube-darwin-start*'<key>RunAtLoad</key><true/>'*) ;; *) bad "the minikube login agent is missing" ;; esac
        case $minikube in *'<key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>'*) ;; *) bad "the minikube login agent is not retried after a failure" ;; esac
        case $minikube in *'<key>AbandonProcessGroup</key><true/>'*) ;; *) bad "the minikube login agent does not abandon its process group" ;; esac
        case $minikube in *'<key>PATH</key><string>/nix/store/'*-podman-*'/bin:/nix/store/'*-minikube-*'/bin:/usr/bin:/bin</string>'*) ;; *) bad "the minikube login agent's PATH lacks podman or minikube" ;; esac
      else
        [ -z "$minikube" ] || bad "bootstrap has a minikube login agent"
      fi

      agentconf=$gen/home-files/.gnupg/gpg-agent.conf
      if [ ! -f "$agentconf" ]; then
        bad "no gpg-agent.conf"
      else
        pinentry=$(sed -n 's/^pinentry-program //p' "$agentconf")
        case $pinentry in
          */bin/pinentry-card) ;;
          *) bad "gpg-agent.conf names $pinentry, not the darwin pinentry filter" ;;
        esac
        proxy=$(dirname "$(dirname "$pinentry")")/libexec/pinentry-card/pinentry-card-proxy
        grep -q 'KEYRING_BACKEND = "security"' "$proxy" 2>/dev/null \
          || bad "the pinentry filter's proxy is not the macOS Keychain render"
        grep -q 'bin/pinentry-mac' "$proxy" 2>/dev/null \
          || bad "the pinentry filter's proxy does not delegate to pinentry_mac"
        grep -qx 'default-cache-ttl 0' "$agentconf" && grep -qx 'max-cache-ttl 0' "$agentconf" \
          || bad "gpg-agent must cache no PIN"
      fi
      grep -qx 'disable-ccid' "$gen/home-files/.gnupg/scdaemon.conf" \
        && grep -qx 'pcsc-shared' "$gen/home-files/.gnupg/scdaemon.conf" \
        || bad "scdaemon.conf is not the shared one"
      # Home Manager writes `/usr/bin/defaults <flags> import <domain> <plist>`,
      # with an empty flag slot and the domain quoted only when it needs it.
      plist=$(grep -oE "/usr/bin/defaults +import +'?org\.gpgtools\.pinentry-mac'? +/nix/store/[^ ]*" "$gen/activate" \
        | grep -o '/nix/store/[^ ]*' || true)
      if [ -z "$plist" ]; then
        bad "activation does not import pinentry_mac's defaults"
      else
        tr -d ' \t\n' < "$plist" | grep -q '<key>UseKeychain</key><false/>' \
          || bad "pinentry_mac's UseKeychain default is not false"
      fi

      ghostty=$gen/home-files/.config/ghostty/config
      if [ -f "$ghostty" ]; then
        families=$(sed -n 's/^font-family *= *//p' "$ghostty" | tr '\n' '|')
        [ "$families" = ${lib.escapeShellArg "${lib.concatStringsSep "|" fontFamilies}|"} ] \
          || bad "Ghostty's font-family is $families"
      else
        bad "no Ghostty config"
      fi

      case $(readlink -f "$gen/home-path/bin/nr") in
        /nix/store/*-nr-darwin-*) ;;
        *) bad "nr on PATH is not nr-darwin" ;;
      esac

      grep -q 'Library/Application Support/VSCodium/User/settings.json' "$gen/activate" \
        || bad "the VSCodium settings merge does not target Application Support"

      # The paths T3 Code's device hub requires under the SDK root.
      sdk=$gen/home-files/Library/Android/sdk
      [ -x "$sdk/cmdline-tools/latest/bin/avdmanager" ] \
        || bad "the Android SDK has no cmdline-tools/latest/bin/avdmanager"
      [ -x "$sdk/platform-tools/adb" ] || bad "the Android SDK has no platform-tools/adb"
      for api in ${lib.escapeShellArgs androidPlatforms}; do
        [ -f "$sdk/system-images/android-$api/google_apis/arm64-v8a/system.img" ] \
          || bad "the Android SDK has no arm64-v8a Google APIs system.img for API $api"
      done
      # A Dock-launched T3 Code starts the emulator with no SDK variables set.
      emulator=$sdk/emulator/emulator
      if ! grep -qsxF 'export ANDROID_HOME="''${ANDROID_HOME:-$HOME/Library/Android/sdk}"' "$emulator" \
        || ! grep -qsxF 'export ANDROID_SDK_ROOT="''${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"' "$emulator"; then
        bad "emulator/emulator is not the wrapper that defaults ANDROID_HOME and ANDROID_SDK_ROOT to ~/Library/Android/sdk"
      else
        real=$(sed -n 's|^exec \(/nix/store/[^ ]*/emulator/emulator\) "\$@"$|\1|p' "$emulator")
        if [ -z "$real" ] || [ ! -x "$real" ] || [ "$(head -c 2 "$real")" = "#!" ]; then
          bad "the emulator wrapper does not exec the store emulator binary"
        fi
      fi
      grep -q 'Library/Android/sdk/emulator' "$vars" || bad "PATH does not gain the SDK's emulator directory"

      devices=$(step mobileDevices); devices=''${devices:-0}
      [ "$devices" -gt "$link" ] || bad "the mobileDevices step does not run after linkGeneration"
      helper=$(grep -m1 '/nix/store/[^ ]*/bin/mobile-devices --xcrun ' "$gen/activate" || true)
      helperexe=$(grep -o '/nix/store/[^ ]*/bin/mobile-devices' <<<"$helper" || true)
      if [ -z "$helper" ] || [ ! -x "$helperexe" ]; then
        bad "activation does not call the built mobile-devices helper"
      else
        ${lib.optionalString (deviceArgs == [ ]) ''bad "my.mobileDevices declares no device"''}
        for arg in \
          '--xcrun /usr/bin/xcrun ' \
          ${lib.escapeShellArg "--android-api ${lib.escapeShellArg newestArm64Api} "} \
          ${lib.escapeShellArgs deviceArgs}; do
          case $helper in
            *"$arg"*) ;;
            *) bad "the mobile-devices helper call lacks $arg" ;;
          esac
        done
      fi

      ${lib.optionalString (t3Desktop != null) ''
        app=${t3Desktop}/Applications/'T3 Code (Nightly).app'
        if [ ! -d "$app" ]; then
          bad "the T3 Code nightly bundle is missing"
        else
          exe=$(/usr/bin/plutil -extract CFBundleExecutable raw "$app/Contents/Info.plist" 2>/dev/null \
            || sed -n '/CFBundleExecutable/{n;s/.*<string>\(.*\)<\/string>.*/\1/p;}' "$app/Contents/Info.plist")
          unzip -p ${t3Desktop.src} "T3 Code (Nightly).app/Contents/MacOS/$exe" | cmp -s - "$app/Contents/MacOS/$exe" \
            || bad "the T3 Code main executable differs from the release zip's, so its signature is broken"
        fi
        grep -qs T3CODE_DISABLE_AUTO_UPDATE "$gen/LaunchAgents/org.nix-community.home.t3code-disable-auto-update.plist" \
          || bad "no launch agent sets T3CODE_DISABLE_AUTO_UPDATE"
      ''}

      nixconf=$sys/etc/nix/nix.conf
      [ -f "$nixconf" ] || bad "the system has no nix.conf"
      if grep -Eq '^auto-optimise-store *= *true' "$nixconf"; then
        bad "nix.conf turns on store auto-optimisation"
      fi
      grep -qx "host=$name_host" "$sys/etc/nix-config-host" \
        && grep -qx "variant=$variant" "$sys/etc/nix-config-host" \
        || bad "/etc/nix-config-host does not record the host and variant"

      brewfile=$(grep -o -m1 "/nix/store/[a-z0-9]*-Brewfile" "$sys/activate" || true)
      if [ -z "$brewfile" ]; then
        bad "the system activation runs no brew bundle"
      else
        casks=$(sed -n 's/^cask "\([^"]*\)".*/\1/p' "$brewfile" | sort | tr '\n' ' ')
        [ "$casks" = ${lib.escapeShellArg "${lib.concatStringsSep " " expectedCasks} "} ] \
          || bad "the Brewfile lists casks: $casks"
      fi
      # nix-homebrew renders autoMigrate into this guard as "1" or "".
      setup=$(grep -o -m1 "/nix/store/[a-z0-9]*-setup-homebrew" "$sys/activate" || true)
      if [ -z "$setup" ]; then
        bad "the system activation runs no nix-homebrew setup"
      elif ! grep -qF 'if [[ -z "1" ]]' "$setup"; then
        bad "the nix-homebrew setup would stop on an existing Homebrew installation"
      fi
      [ -n "$(ls -A "$sys/Library/Fonts/Nix Fonts" 2>/dev/null)" ] \
        || bad "no fonts under Library/Fonts/Nix Fonts"
    '';
in
pkgs.runCommand "darwin-outputs" { nativeBuildInputs = [ pkgs.unzip ]; } ''
  fail=0
  bad() { echo "$name: $*" >&2; fail=1; }
  ${lib.optionalString (darwinFixtures == [ ]) ''
    echo "tests/fixtures/hosts holds no macOS fixture host" >&2
    fail=1
  ''}
  ${lib.concatMapStrings (entry: ''
    name_host=${lib.escapeShellArg entry.fixture}
    ${assertEntry entry}
  '') darwinFixtures}
  [ "$fail" = 0 ] || exit 1
  touch "$out"
''
