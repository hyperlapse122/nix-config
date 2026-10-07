/*
  Check interface:

    import ./tests/darwin-outputs.nix { inherit pkgs darwinFixtures; }

  `pkgs` is nixpkgs for aarch64-darwin and `darwinFixtures` is
  tests/lib/darwin-fixtures.nix. Builds on a macOS builder only, and reads
  what the macOS fixture hosts materialize, both variants, where
  tests/darwin-config.nix reads their options on Linux:

  - the Home Manager activation script stages host secrets before
    writeBoundary and publishes them, then merges the docker credHelpers,
    after linkGeneration, in production only;
  - the session variables carry no Podman socket or Ryuk variable, and the
    generation holds no containers/ or systemd user file;
  - gpg-agent.conf names the darwin pinentry filter, whose proxy delegates to
    pinentry_mac, with both cache TTLs at 0, and scdaemon.conf is the shared
    one; activation imports pinentry_mac's defaults with UseKeychain false;
  - Ghostty's config lists the NixOS font families in order;
  - `nr` on PATH is nr-darwin;
  - the VSCodium settings merge targets Application Support;
  - with my.t3.desktop.enable, the T3 Code nightly bundle is in the profile,
    its main executable is byte-identical to the release zip's, and a launch
    agent sets T3CODE_DISABLE_AUTO_UPDATE=1;
  - the system's nix.conf keeps store auto-optimisation off,
    /etc/nix-config-host records the host and variant, the Brewfile lists the
    expected casks, and the shared fonts are installed.

  Every comparison is rendered into the builder, so a failure names the
  fixture and the reason.
*/
{ pkgs, darwinFixtures }:
let
  inherit (pkgs) lib;

  mapping = import ../modules/shared/darwin-apps.nix;
  expectedCasks = lib.sort lib.lessThan mapping.casks;

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
      docker=$(step dockerCredHelpers); docker=''${docker:-0}
      boundary=$(step writeBoundary); boundary=''${boundary:-0}
      link=$(step linkGeneration); link=''${link:-0}
      if [ "$boundary" = 0 ] || [ "$link" = 0 ]; then
        bad "the activation script has no writeBoundary or linkGeneration step"
      elif [ "$production" = 1 ]; then
        [ "$stage" != 0 ] && [ "$stage" -lt "$boundary" ] \
          || bad "host-secrets stage must run before writeBoundary"
        [ "$publish" -gt "$link" ] || bad "host-secrets publish must run after linkGeneration"
        [ "$docker" -gt "$link" ] || bad "the docker credHelpers merge must run after linkGeneration"
      else
        [ "$stage" = 0 ] && [ "$publish" = 0 ] && [ "$docker" = 0 ] \
          || bad "bootstrap must run no host-secrets step and no credHelpers merge"
      fi

      vars=$gen/home-path/etc/profile.d/hm-session-vars.sh
      [ -f "$vars" ] || bad "no hm-session-vars.sh in the profile"
      for v in DOCKER_HOST REGISTRY_AUTH_FILE TESTCONTAINERS_RYUK_PRIVILEGED TESTCONTAINERS_RYUK_CONTAINER_PRIVILEGED; do
        if grep -q "$v=" "$vars"; then bad "the Podman variable $v reached the session"; fi
      done
      [ ! -e "$gen/home-files/.config/containers" ] || bad "Podman containers/ files reached macOS"
      [ ! -e "$gen/home-files/.config/systemd" ] || bad "systemd user files reached macOS"

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
