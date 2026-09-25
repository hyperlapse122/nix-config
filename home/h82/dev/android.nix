{
  config,
  osConfig,
  pkgs,
  ...
}:
let
  androidSdk = import ../../../packages/android-sdk.nix { inherit pkgs; };
  # Mutable rather than a store path, so Gradle, Android Studio, and the
  # Android CLI can add the platforms and tools each project asks for.
  sdkRoot = "${config.xdg.dataHome}/android-sdk";
  androidSessionVariables = {
    ANDROID_HOME = sdkRoot;
    ANDROID_SDK_ROOT = sdkRoot;
  };
in
{
  home.sessionVariables = androidSessionVariables;

  systemd.user.sessionVariables = androidSessionVariables;

  # Appended rather than prepended through home.sessionPath: platform-tools
  # also ships prebuilt sqlite3 and mke2fs, which must not shadow the system's.
  home.sessionVariablesExtra = ''
    export PATH="''${PATH:+$PATH:}${sdkRoot}/cmdline-tools/latest/bin:${sdkRoot}/platform-tools"
  '';

  # The Android CLI reads its default flags from this file.
  home.file.".androidrc".text = ''
    --sdk=${sdkRoot}
  '';

  # Gradle and the Android Gradle Plugin need a JDK; this also sets JAVA_HOME.
  programs.java.enable = true;

  # Installing needs the network, which activation cannot count on, so a user
  # unit fills the SDK at login and retries until it succeeds. Once every
  # declared package is on disk it exits without touching the network.
  systemd.user.services.android-sdk-provision = {
    Unit = {
      Description = "Install the declared Android SDK packages";
      StartLimitIntervalSec = 0;
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${androidSdk.provision}/bin/android-sdk-provision ${sdkRoot}";
      # The SDK ships prebuilt glibc binaries (the Android CLI and its bundled
      # JRE, adb, aapt2) that run on NixOS only through nix-ld, whose loader
      # paths NixOS sets for login sessions. The unit names them itself rather
      # than depend on what the user manager inherits.
      Environment = [
        "NIX_LD=${osConfig.environment.sessionVariables.NIX_LD}"
        "NIX_LD_LIBRARY_PATH=${osConfig.environment.sessionVariables.NIX_LD_LIBRARY_PATH}"
      ];
      Restart = "on-failure";
      RestartSec = "5min";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
