/*
  Check interface:

    import ./tests/android-sdk.nix { inherit pkgs self; }

  Asserts that every host configuration gives h82 a usable Android SDK, reading
  the files the Home Manager generation materializes rather than the options
  they come from.

  Verifies, on ThinkPad-X1-Carbon-Gen-11, ThinkPad-X1-Carbon-Gen-11-bootstrap,
  MS-7D91, and MS-7D91-bootstrap:
  - hm-session-vars.sh exports ANDROID_HOME and ANDROID_SDK_ROOT as the mutable
    SDK root, appends cmdline-tools/latest/bin and platform-tools to PATH on
    the only line that names platform-tools (its prebuilt sqlite3 and mke2fs
    must not shadow the system's), and
    exports a JAVA_HOME that holds a java executable.
  - environment.d/10-home-manager.conf carries both SDK variables, so apps the
    systemd user manager starts see them too.
  - ~/.androidrc holds exactly the --sdk flag for that root.
  - android-sdk-provision.service is linked into default.target.wants, runs
    the provisioning script against that root, and hands it the nix-ld loader.

  Then runs the provisioning script against a fake Android CLI:
  - an empty SDK root gets one install call naming every declared package.
  - a complete SDK root gets no call at all.
  - a partial SDK root gets a call naming only the missing packages; a run
    that installed everything again would pass the empty-root case alone.
  - a CLI that exits 0 without installing fails the script, so the unit
    retries instead of recording success.
*/
{ pkgs, self }:
let
  inherit (pkgs.lib) escapeShellArg concatMapStrings;

  sdkRoot = "/home/h82/.local/share/android-sdk";

  shellLines = [
    ''export ANDROID_HOME="${sdkRoot}"''
    ''export ANDROID_SDK_ROOT="${sdkRoot}"''
    ''export PATH="''${PATH:+$PATH:}${sdkRoot}/cmdline-tools/latest/bin:${sdkRoot}/platform-tools"''
  ];

  environmentLines = [
    "ANDROID_HOME=${sdkRoot}"
    "ANDROID_SDK_ROOT=${sdkRoot}"
  ];

  unitLines = [
    "Type=oneshot"
    "Restart=on-failure"
    "WantedBy=default.target"
    "Environment=NIX_LD=/run/current-system/sw/share/nix-ld/lib/ld.so"
    "Environment=NIX_LD_LIBRARY_PATH=/run/current-system/sw/share/nix-ld/lib"
  ];

  assertHost =
    hostName: host:
    let
      hm = host.config.home-manager.users.h82;
      files = "${hm.home-files}";
      shellFile = "${hm.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
      unit = "${files}/.config/systemd/user/android-sdk-provision.service";
      wanted = "${files}/.config/systemd/user/default.target.wants/android-sdk-provision.service";
      host' = escapeShellArg hostName;
    in
    ''
      check_file ${host'} ${escapeShellArg shellFile}
      check_file ${host'} ${files}/.config/environment.d/10-home-manager.conf
      check_file ${host'} ${files}/.androidrc
      check_file ${host'} ${unit}
    ''
    + concatMapStrings (line: ''
      check_line ${host'} ${escapeShellArg shellFile} ${escapeShellArg line}
    '') shellLines
    + concatMapStrings (line: ''
      check_line ${host'} ${files}/.config/environment.d/10-home-manager.conf ${escapeShellArg line}
    '') environmentLines
    + concatMapStrings (line: ''
      check_line ${host'} ${unit} ${escapeShellArg line}
    '') unitLines
    + ''
      if [ -f ${files}/.androidrc ] && [ "$(cat ${files}/.androidrc)" != ${escapeShellArg "--sdk=${sdkRoot}"} ]; then
        fail ${host'}": .androidrc does not hold exactly --sdk=${sdkRoot}"
      fi

      if [ ! -e ${wanted} ]; then
        fail ${host'}": android-sdk-provision.service is not in default.target.wants"
      fi

      exec_start=$(grep '^ExecStart=' ${unit} || true)
      provision=''${exec_start#ExecStart=}
      provision=''${provision%% *}
      if [ "$exec_start" != "ExecStart=$provision ${sdkRoot}" ]; then
        fail ${host'}": ExecStart does not run one command against ${sdkRoot}: $exec_start"
      elif [ ! -x "$provision" ] || ! grep -q 'sdk install' "$provision"; then
        fail ${host'}": ExecStart does not name the provisioning script: $provision"
      fi

      if [ "$(grep -c platform-tools ${escapeShellArg shellFile})" != 1 ]; then
        fail ${host'}": hm-session-vars.sh names platform-tools on more than the appending PATH line"
      fi

      java_home=$(sed -n 's/^export JAVA_HOME="\(.*\)"$/\1/p' ${escapeShellArg shellFile})
      if [ -z "$java_home" ] || [ ! -x "$java_home/bin/java" ]; then
        fail ${host'}": hm-session-vars.sh exports no JAVA_HOME with bin/java"
      fi
    '';

  # Records each call, then unpacks the requested packages unless told not to.
  fakeCli = pkgs.writeShellScript "fake-android" ''
    printf '%s\n' "$*" >> "$FAKE_LOG"
    if [ "''${FAKE_INSTALL:-1}" = 1 ]; then
      sdk=""
      packages=0
      for arg in "$@"; do
        case "$arg" in
          --sdk=*) sdk=''${arg#--sdk=} ;;
          --*|sdk|install) ;;
          *) mkdir -p "$sdk/$arg" && touch "$sdk/$arg/package.xml" ;;
        esac
      done
    fi
  '';

  androidSdk = import ../packages/android-sdk.nix {
    inherit pkgs;
    androidCli = fakeCli;
  };
  provision = "${androidSdk.provision}/bin/android-sdk-provision";
  allPackages = toString androidSdk.packages;
in
pkgs.runCommand "android-sdk-tests" { } ''
  failed=0
  fail() {
    echo "$1" >&2
    failed=1
  }
  check_file() {
    if [ ! -f "$2" ]; then
      fail "$1: missing $2"
    fi
  }
  check_line() {
    if [ -f "$2" ] && ! grep -Fxq -- "$3" "$2"; then
      fail "$1: $2 is missing the line: $3"
    fi
  }

  ${assertHost "ThinkPad-X1-Carbon-Gen-11" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11}
  ${assertHost "ThinkPad-X1-Carbon-Gen-11-bootstrap" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap}
  ${assertHost "MS-7D91" self.nixosConfigurations.MS-7D91}
  ${assertHost "MS-7D91-bootstrap" self.nixosConfigurations.MS-7D91-bootstrap}

  export FAKE_LOG=$TMPDIR/calls
  sdk=$TMPDIR/sdk

  : > "$FAKE_LOG"
  if ! ${provision} "$sdk"; then
    fail "provisioning an empty SDK root failed"
  fi
  if [ "$(cat "$FAKE_LOG")" != "--no-metrics --sdk=$sdk sdk install ${allPackages}" ]; then
    fail "an empty SDK root did not get one install call for every package: $(cat "$FAKE_LOG")"
  fi

  : > "$FAKE_LOG"
  if ! ${provision} "$sdk"; then
    fail "provisioning a complete SDK root failed"
  fi
  if [ -s "$FAKE_LOG" ]; then
    fail "a complete SDK root still called the CLI: $(cat "$FAKE_LOG")"
  fi

  rm -r "$sdk/platform-tools" "$sdk/build-tools"
  : > "$FAKE_LOG"
  if ! ${provision} "$sdk"; then
    fail "provisioning a partial SDK root failed"
  fi
  if [ "$(cat "$FAKE_LOG")" != "--no-metrics --sdk=$sdk sdk install platform-tools build-tools/36.0.0" ]; then
    fail "a partial SDK root did not get a call for only the missing packages: $(cat "$FAKE_LOG")"
  fi

  rm -r "$sdk"
  : > "$FAKE_LOG"
  if FAKE_INSTALL=0 ${provision} "$sdk"; then
    fail "provisioning succeeded although the CLI installed nothing"
  fi

  if [ "$failed" != 0 ]; then
    exit 1
  fi
  touch $out
''
