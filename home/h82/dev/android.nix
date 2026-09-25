{ config, pkgs, ... }:
let
  androidSdk = import ../../../packages/android-sdk.nix { inherit pkgs; };
  # A stable path in front of the store SDK, so ANDROID_HOME, ~/.androidrc,
  # and the sdk.dir an IDE writes into local.properties survive a pin bump.
  sdkRoot = "${config.xdg.dataHome}/android-sdk";
  # androidenv installs cmdline-tools at its repository path, the pinned
  # version, rather than at the cmdline-tools/latest an sdkmanager install uses.
  cmdlineTools = "${sdkRoot}/cmdline-tools/${androidSdk.repo.latest.cmdline-tools}";
  androidSessionVariables = {
    ANDROID_HOME = sdkRoot;
    ANDROID_SDK_ROOT = sdkRoot;
  };
in
{
  xdg.dataFile."android-sdk".source = androidSdk.sdkRoot;

  home.sessionVariables = androidSessionVariables;

  systemd.user.sessionVariables = androidSessionVariables;

  # Appended rather than prepended through home.sessionPath: platform-tools
  # also ships sqlite3 and mke2fs, which must not shadow the system's.
  home.sessionVariablesExtra = ''
    export PATH="''${PATH:+$PATH:}${cmdlineTools}/bin:${sdkRoot}/platform-tools"
  '';

  # The Android CLI reads its default flags from this file.
  home.file.".androidrc".text = ''
    --sdk=${sdkRoot}
  '';

  # Gradle and the Android Gradle Plugin need a JDK; this also sets JAVA_HOME.
  programs.java.enable = true;
}
