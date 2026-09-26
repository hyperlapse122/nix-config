/*
  Check interface:

    import ./tests/android-sdk.nix { inherit pkgs self; }

  Asserts that every host configuration gives h82 the Android SDK the pin file
  packages/android-sdk-repo.json names, reading the files the Home Manager
  generation materializes rather than the options they come from. The expected
  versions are read from the pin file here, independently of the module, so a
  module that stops deriving its versions from the pin fails.

  Verifies, on ThinkPad-X1-Carbon-Gen-11, ThinkPad-X1-Carbon-Gen-11-bootstrap,
  MS-7D91, and MS-7D91-bootstrap:
  - ~/.local/share/android-sdk is a link into a store SDK that carries every
    pinned package's and system image's package.xml at its repository path,
    and the accepted android-sdk-license.
  - the SDK's adb runs in the sandbox and reports the pinned platform-tools
    version, and aapt2 from each pinned build-tools runs. Both prove
    androidenv patched them for NixOS rather than leaving them to nix-ld.
  - the pinned cmdline-tools directory ships an executable sdkmanager.
  - emulator/emulator runs and reports the pinned emulator version. Orca
    accepts an SDK root only when platform-tools/adb and emulator/emulator
    both exist under it, so this and the adb check together are its test.
  - hm-session-vars.sh exports ANDROID_HOME and ANDROID_SDK_ROOT as the link,
    appends the cmdline-tools bin and platform-tools directories to PATH on
    the only line that names platform-tools (its sqlite3 and mke2fs must not
    shadow the system's), and exports a JAVA_HOME that holds a java
    executable.
  - environment.d/10-home-manager.conf carries both SDK variables, so apps the
    systemd user manager starts see them too.
  - ~/.androidrc holds exactly the --sdk flag for the link.
*/
{ pkgs, self }:
let
  inherit (pkgs.lib)
    attrNames
    attrValues
    concatMap
    concatMapStrings
    escapeShellArg
    ;

  repo = builtins.fromJSON (builtins.readFile ../packages/android-sdk-repo.json);
  # images nest api -> tag -> abi -> entry, one level deeper than packages.
  pinned =
    concatMap attrValues (attrValues repo.packages)
    ++ concatMap attrValues (concatMap attrValues (attrValues repo.images));
  platformTools = repo.latest.platform-tools;
  emulator = repo.latest.emulator;
  cmdlineTools = repo.latest.cmdline-tools;

  sdkRoot = "/home/h82/.local/share/android-sdk";

  shellLines = [
    ''export ANDROID_HOME="${sdkRoot}"''
    ''export ANDROID_SDK_ROOT="${sdkRoot}"''
    ''export PATH="''${PATH:+$PATH:}${sdkRoot}/cmdline-tools/${cmdlineTools}/bin:${sdkRoot}/platform-tools"''
  ];

  environmentLines = [
    "ANDROID_HOME=${sdkRoot}"
    "ANDROID_SDK_ROOT=${sdkRoot}"
  ];

  assertHost =
    hostName: host:
    let
      hm = host.config.home-manager.users.h82;
      files = "${hm.home-files}";
      shellFile = "${hm.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
      host' = escapeShellArg hostName;
    in
    ''
      check_file ${host'} ${escapeShellArg shellFile}
      check_file ${host'} ${files}/.config/environment.d/10-home-manager.conf
      check_file ${host'} ${files}/.androidrc

      sdk=${files}/.local/share/android-sdk
      if [ ! -L "$sdk" ] || [ ! -d "$sdk" ]; then
        fail ${host'}": .local/share/android-sdk is not a link to a directory"
      else
        sdk=$(readlink -f "$sdk")
        case "$sdk" in
          /nix/store/*) ;;
          *) fail ${host'}": .local/share/android-sdk resolves outside the store: $sdk" ;;
        esac
        check_file ${host'} "$sdk/licenses/android-sdk-license"
    ''
    + concatMapStrings (package: ''
      check_line_in ${host'} "$sdk/${package.path}/package.xml" ${escapeShellArg ''path="${builtins.replaceStrings [ "/" ] [ ";" ] package.path}"''}
    '') pinned
    + ''
      adb_version=$("$sdk/platform-tools/adb" version 2>&1 | sed -n 's/^Version \([^-]*\)-.*/\1/p' || true)
      if [ "$adb_version" != ${escapeShellArg platformTools} ]; then
        fail ${host'}": adb reports platform-tools '$adb_version', expected the pinned ${platformTools}"
      fi

      # The emulator reports major.minor.micro.build; the pin names the first three.
      emulator_version=$("$sdk/emulator/emulator" -version 2>&1 | sed -n 's/^Android emulator version \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p' || true)
      if [ "$emulator_version" != ${escapeShellArg emulator} ]; then
        fail ${host'}": emulator reports '$emulator_version', expected the pinned ${emulator}"
      fi
    ''
    + concatMapStrings (version: ''
      if ! "$sdk/build-tools/${version}/aapt2" version >/dev/null 2>&1; then
        fail ${host'}": aapt2 from build-tools ${version} does not run"
      fi
    '') (attrNames repo.packages.build-tools)
    + ''
        if [ ! -x "$sdk/cmdline-tools/${cmdlineTools}/bin/sdkmanager" ]; then
          fail ${host'}": cmdline-tools/${cmdlineTools} ships no executable sdkmanager"
        fi
      fi
    ''
    + concatMapStrings (line: ''
      check_line ${host'} ${escapeShellArg shellFile} ${escapeShellArg line}
    '') shellLines
    + concatMapStrings (line: ''
      check_line ${host'} ${files}/.config/environment.d/10-home-manager.conf ${escapeShellArg line}
    '') environmentLines
    + ''
      if [ -f ${files}/.androidrc ] && [ "$(cat ${files}/.androidrc)" != ${escapeShellArg "--sdk=${sdkRoot}"} ]; then
        fail ${host'}": .androidrc does not hold exactly --sdk=${sdkRoot}"
      fi

      if [ "$(grep -c platform-tools ${escapeShellArg shellFile})" != 1 ]; then
        fail ${host'}": hm-session-vars.sh names platform-tools on more than the appending PATH line"
      fi

      java_home=$(sed -n 's/^export JAVA_HOME="\(.*\)"$/\1/p' ${escapeShellArg shellFile})
      if [ -z "$java_home" ] || [ ! -x "$java_home/bin/java" ]; then
        fail ${host'}": hm-session-vars.sh exports no JAVA_HOME with bin/java"
      fi
    '';
in
pkgs.runCommand "android-sdk-tests" { } ''
  # adb aborts when it cannot create ~/.android, and the sandbox HOME does
  # not exist.
  export HOME=$TMPDIR/home
  mkdir -p "$HOME"

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
  # package.xml is one generated document, so its path attribute is matched
  # as a fixed string rather than as a whole line.
  check_line_in() {
    if [ ! -f "$2" ]; then
      fail "$1: missing $2"
    elif ! grep -Fq -- "$3" "$2"; then
      fail "$1: $2 does not declare $3"
    fi
  }

  ${assertHost "ThinkPad-X1-Carbon-Gen-11" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11}
  ${assertHost "ThinkPad-X1-Carbon-Gen-11-bootstrap" self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap}
  ${assertHost "MS-7D91" self.nixosConfigurations.MS-7D91}
  ${assertHost "MS-7D91-bootstrap" self.nixosConfigurations.MS-7D91-bootstrap}

  if [ "$failed" != 0 ]; then
    exit 1
  fi
  touch $out
''
