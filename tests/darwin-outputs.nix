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
  - the session and a login agent at load set CROSS_MODEL_PEERS to the
    peers the installed packages call for (tests/lib/cross-model-peers.nix)
    and CROSS_MODEL_MAX_PEERS to 2;
  - gpg-agent.conf names the darwin pinentry filter, whose proxy delegates to
    pinentry_mac, with both cache TTLs at 0, and scdaemon.conf is the shared
    one; activation imports pinentry_mac's defaults with UseKeychain false;
  - Ghostty's config lists the NixOS font families in order;
  - `nr` on PATH is nr-darwin;
  - the opencode wrapper on PATH reads its key from the state directory
    host-secrets publishes to, and activation merges the declared OpenCode
    config into ~/.config/opencode/opencode.json after writeBoundary;
  - agy_acp_server.par on PATH is a wrapper that execs the Antigravity runtime
    packages/antigravity-acp-release.json pins, sets no SSL_CERT_FILE, and
    defines and invokes seed_acp_token so the sign-in seeding is present;
    localharness_external beside it resolves into the same runtime;
  - serve-html on PATH is the packaged helper the shared instructions name;
  - the VSCodium settings merge targets Application Support;
  - ~/Library/Android/sdk holds what T3 Code's device hub needs:
    cmdline-tools/latest/bin/avdmanager, platform-tools/adb, an arm64-v8a
    Google APIs system.img for every platform the pin file names, and an
    emulator/emulator wrapper that defaults ANDROID_HOME and ANDROID_SDK_ROOT
    to ~/Library/Android/sdk before it execs the store emulator; the session
    sets ANDROID_HOME and ANDROID_SDK_ROOT to that path, and its PATH
    assignment gains the emulator directory;
  - the activation script runs the mobileDevices step after linkGeneration,
    and it calls the built mobile-devices helper with /usr/bin/xcrun, the SDK
    root, a --java-home whose bin/java runs, every declared device, and the
    newest pinned API with an arm64-v8a image;
  - with my.t3.desktop.enable, the T3 Code nightly bundle is in the profile,
    its main executable is byte-identical to the release zip's, and a launch
    agent sets T3CODE_DISABLE_AUTO_UPDATE=1;
  - the system's nix.conf keeps store auto-optimisation off,
    /etc/nix-config-host records the host and variant, the Brewfile lists the
    expected casks, the shared fonts are installed, and activation turns on
    automatic appearance without pinning AppleInterfaceStyle;
  - the system activate script runs the Xcode step, mas through launchctl
    asuser for App Store id 497799835, after brew bundle and before the Home
    Manager activation call, then the KakaoTalk step for App Store id
    869223134, through its own launchctl asuser wrapper, before that call;
  - the retired-cask step runs after the KakaoTalk step and before the Home
    Manager activation call, with every brew call going through /usr/bin/sudo
    as the primary user with the absolute brew path;
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

  androidPin = import ./lib/android-pin.nix { inherit lib; };
  expectedPeers = import ./lib/cross-model-peers.nix { inherit lib; };

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
      deviceArgs = map androidPin.deviceArg (user.my.mobileDevices or [ ]);
      androidSdkRoot = "${config.my.user.home}/Library/Android/sdk";
      masExe = lib.getExe entry.host.pkgs.mas;
      brewExe = "${config.homebrew.prefix}/bin/brew";
      peers = lib.concatStringsSep "," (expectedPeers user.home.packages);
      serveHtmlPackage =
        (import ../packages/agent-tools.nix { inherit (entry.host) pkgs; }).serveHtml or null;
      serveHtml = lib.optionalString (serveHtmlPackage != null) (lib.getExe serveHtmlPackage);
      antigravityRuntime = "${
        import ../packages/antigravity-acp.nix {
          inherit (entry.host) pkgs;
          pins = (builtins.fromJSON (builtins.readFile ../packages/antigravity-acp-release.json)).platforms;
        }
      }/libexec/antigravity-acp";
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
      grep -Fxq 'export CROSS_MODEL_PEERS="${peers}"' "$vars" \
        || bad "the session does not set CROSS_MODEL_PEERS to ${peers}"
      grep -Fxq 'export CROSS_MODEL_MAX_PEERS="2"' "$vars" || bad "the session does not set CROSS_MODEL_MAX_PEERS to 2"
      peeragent=$(agent cross-model-peers)
      case $peeragent in
        *'launchctlsetenvCROSS_MODEL_PEERS${peers}/bin/launchctlsetenvCROSS_MODEL_MAX_PEERS2'*'<key>RunAtLoad</key><true/>'*) ;;
        *) bad "no login agent sets CROSS_MODEL_PEERS to ${peers} and CROSS_MODEL_MAX_PEERS to 2 for GUI apps" ;;
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

      # host-secrets publishes the OpenCode key into the state directory.
      opencode=$(readlink -f "$gen/home-path/bin/opencode" || true)
      if [ -z "$opencode" ] || [ ! -f "$opencode" ]; then
        bad "no opencode on PATH"
      elif ! grep -Fxq -- ${lib.escapeShellArg "TOKEN_FILE='${user.my.secrets.stateDir}/synthetic_api_key'"} "$opencode"; then
        bad "the opencode wrapper does not read ${user.my.secrets.stateDir}/synthetic_api_key"
      fi

      # Pi's Synthetic provider runs the packaged key helper, which reads the
      # key host-secrets publishes into the state directory.
      pi=$(readlink -f "$gen/home-path/bin/pi" || true)
      piKey=$(readlink -f "$gen/home-path/bin/pi-synthetic-key" || true)
      if [ -z "$pi" ] || [ ! -f "$pi" ]; then
        bad "no pi on PATH"
      elif [ -z "$piKey" ] || [ ! -f "$piKey" ]; then
        bad "no pi-synthetic-key beside pi"
      elif ! grep -Fxq -- ${lib.escapeShellArg "KEY_FILE='${user.my.secrets.stateDir}/synthetic_api_key'"} "$piKey"; then
        bad "Pi's key helper does not read ${user.my.secrets.stateDir}/synthetic_api_key"
      fi

      # Compound Engineering's Antigravity route takes the helper from the
      # directory agy_acp_server.par is found in. The macOS .par finds its CA
      # bundle itself, so the wrapper sets no SSL_CERT_FILE. It seeds
      # acp_token.json from the ~/.gemini sign-in, then execs the pinned runtime.
      agyPar=$(readlink -f "$gen/home-path/bin/agy_acp_server.par" || true)
      if [ -z "$agyPar" ] || [ ! -x "$agyPar" ]; then
        bad "no agy_acp_server.par on PATH"
      else
        grep -qxF ${lib.escapeShellArg "exec ${antigravityRuntime}/agy_acp_server.par \"$@\""} "$agyPar" \
          || bad "agy_acp_server.par does not exec the pinned runtime's .par"
        grep -qE '^ *token_target=\$acp_dir/acp_token\.json$' "$agyPar" \
          && grep -qxF 'seed_acp_token' "$agyPar" \
          || bad "agy_acp_server.par does not seed acp_token.json"
        if grep -qF SSL_CERT_FILE "$agyPar"; then
          bad "the macOS agy_acp_server.par wrapper sets SSL_CERT_FILE"
        fi
      fi
      [ "$(readlink -f "$gen/home-path/bin/localharness_external" || true)" = ${lib.escapeShellArg "${antigravityRuntime}/localharness_external"} ] \
        || bad "localharness_external on PATH is not the pinned runtime's"

      if [ -z ${lib.escapeShellArg serveHtml} ]; then
        bad "packages/agent-tools.nix exports no serveHtml"
      elif [ "$(readlink -f "$gen/home-path/bin/serve-html" || true)" != ${lib.escapeShellArg serveHtml} ]; then
        bad "serve-html on PATH is not the packaged helper"
      fi

      opencodeSettings=$(step opencodeSettings); opencodeSettings=''${opencodeSettings:-0}
      if [ "$opencodeSettings" = 0 ] || [ "$opencodeSettings" -le "$boundary" ]; then
        bad "the activation script has no opencodeSettings step after writeBoundary"
      elif ! grep -qF -- ${lib.escapeShellArg "--settings ${config.my.user.home}/.config/opencode/opencode.json"} "$gen/activate"; then
        bad "the OpenCode config merge does not target ${config.my.user.home}/.config/opencode/opencode.json"
      fi

      grep -q 'Library/Application Support/VSCodium/User/settings.json' "$gen/activate" \
        || bad "the VSCodium settings merge does not target Application Support"

      # The paths T3 Code's device hub requires under the SDK root.
      sdk=$gen/home-files/Library/Android/sdk
      [ -x "$sdk/cmdline-tools/latest/bin/avdmanager" ] \
        || bad "the Android SDK has no cmdline-tools/latest/bin/avdmanager"
      [ -x "$sdk/platform-tools/adb" ] || bad "the Android SDK has no platform-tools/adb"
      for api in ${lib.escapeShellArgs androidPin.platforms}; do
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
      sdkroot=${lib.escapeShellArg androidSdkRoot}
      for v in ANDROID_HOME ANDROID_SDK_ROOT; do
        grep -qxF "export $v=\"$sdkroot\"" "$vars" || bad "the session does not set $v to $sdkroot"
      done
      # Only a PATH assignment counts, so another line naming the directory
      # cannot stand in for it.
      pathlines=$(grep '^export PATH=' "$vars" || true)
      case $pathlines in
        *":$sdkroot/emulator\""* | *":$sdkroot/emulator:"*) ;;
        *) bad "no PATH assignment gains the SDK's emulator directory" ;;
      esac

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
          ${lib.escapeShellArg "--sdk-root ${lib.escapeShellArg androidSdkRoot} "} \
          ${lib.escapeShellArg "--android-api ${lib.escapeShellArg androidPin.newestArm64Api} "} \
          ${lib.escapeShellArgs deviceArgs}; do
          case $helper in
            *"$arg"*) ;;
            *) bad "the mobile-devices helper call lacks $arg" ;;
          esac
        done
        javahome=$(sed -n "s|.*--java-home '\{0,1\}\(/nix/store/[^ ']*\).*|\1|p" <<<"$helper")
        if [ -z "$javahome" ] || ! "$javahome/bin/java" -version >/dev/null 2>&1; then
          bad "the mobile-devices helper call lacks a --java-home whose bin/java runs: ''${javahome:-none}"
        fi
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
      # The Xcode step runs after brew bundle and before Home Manager, the last
      # point that still runs as root; mas runs in the primary user's session.
      lineof() { grep -nF -m1 -- "$1" "$sys/activate" | cut -d: -f1 || true; }
      bundleline=$(lineof "brew bundle --file="); bundleline=''${bundleline:-0}
      masline=$(lineof ${lib.escapeShellArg ''/bin/launchctl asuser "$xcodeUid" /usr/bin/env SUDO_UID="$xcodeUid" SUDO_GID="$xcodeGid" ${masExe} "$@"''}); masline=''${masline:-0}
      installline=$(lineof 'if ! xcodeMas install 497799835 && ! xcodeMas get 497799835; then'); installline=''${installline:-0}
      kakaomasline=$(lineof ${lib.escapeShellArg ''/bin/launchctl asuser "$appStoreUid" /usr/bin/env SUDO_UID="$appStoreUid" SUDO_GID="$appStoreGid" ${masExe} "$@"''}); kakaomasline=''${kakaomasline:-0}
      kakaoline=$(lineof 'if ! appStoreMas install 869223134 && ! appStoreMas get 869223134; then'); kakaoline=''${kakaoline:-0}
      retiredbrewline=$(lineof ${lib.escapeShellArg ''PATH="${config.homebrew.prefix}/bin:$PATH" /usr/bin/sudo --preserve-env=PATH --user=${config.system.primaryUser} --set-home /usr/bin/env NONINTERACTIVE=1 ${brewExe} "$@"''}); retiredbrewline=''${retiredbrewline:-0}
      retiredlistline=$(lineof ${lib.escapeShellArg ''if [ -z "$retiredList" ] || [ "$retiredList" = "Error: Cask 'grok-bot' is not installed." ]; then''}); retiredlistline=''${retiredlistline:-0}
      retiredline=$(lineof 'elif ! retiredBrew uninstall --cask --force grok-bot; then'); retiredline=''${retiredline:-0}
      hmline=$(lineof "echo Activating home-manager configuration for "); hmline=''${hmline:-0}
      if [ "$bundleline" = 0 ] || [ "$hmline" = 0 ]; then
        bad "the system activation has no brew bundle or Home Manager activation call"
      elif [ "$masline" = 0 ] || [ "$installline" = 0 ]; then
        bad "the system activation has no Xcode step running mas through launchctl asuser for 497799835"
      elif ! [ "$bundleline" -lt "$masline" ] || ! [ "$masline" -lt "$installline" ] || ! [ "$installline" -lt "$hmline" ]; then
        bad "the Xcode step does not run after brew bundle and before Home Manager"
      fi
      if [ "$kakaomasline" = 0 ] || [ "$kakaoline" = 0 ]; then
        bad "the system activation has no KakaoTalk step running mas through launchctl asuser for 869223134"
      elif ! [ "$installline" -lt "$kakaomasline" ] || ! [ "$kakaomasline" -lt "$kakaoline" ] || ! [ "$kakaoline" -lt "$hmline" ]; then
        bad "the KakaoTalk step does not run after the Xcode step and before Home Manager"
      fi
      if [ "$retiredbrewline" = 0 ] || [ "$retiredlistline" = 0 ] || [ "$retiredline" = 0 ]; then
        bad "the system activation has no retired-cask step running brew through sudo for grok-bot, telling not-installed from other brew list failures, and uninstalling with --force"
      elif ! [ "$bundleline" -lt "$retiredbrewline" ] || ! [ "$kakaoline" -lt "$retiredbrewline" ] || ! [ "$retiredbrewline" -lt "$retiredlistline" ] || ! [ "$retiredlistline" -lt "$retiredline" ] || ! [ "$retiredline" -lt "$hmline" ]; then
        bad "the retired-cask step does not run after brew bundle and the KakaoTalk step and before Home Manager"
      fi

      [ -n "$(ls -A "$sys/Library/Fonts/Nix Fonts" 2>/dev/null)" ] \
        || bad "no fonts under Library/Fonts/Nix Fonts"
      # The value is a multi-line plist, so read up to its closing tag.
      autoAppearance=$(awk '
        /defaults write -g .?AppleInterfaceStyleSwitchesAutomatically/ { on = 1 }
        on { print }
        on && /<\/plist>/ { exit }
      ' "$sys/activate")
      case "$autoAppearance" in
        *"<true/>"*) ;;
        *) bad "the system activation does not turn on automatic appearance" ;;
      esac
      if grep -Eq "defaults write -g '?AppleInterfaceStyle'? " "$sys/activate"; then
        bad "the system activation pins AppleInterfaceStyle"
      fi
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
