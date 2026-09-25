{
  pkgs,
  # The command that installs SDK packages. Tests pass a fake here, so the
  # provisioning logic runs without the network or the real Android CLI.
  androidCli ? null,
}:

let
  inherit (pkgs.lib) escapeShellArgs;

  # Google's cmdline-tools archive, pinned so the first provisioning run starts
  # from a known launcher. Its `android` binary downloads the Android CLI into
  # ~/.android on first use and installs the rest of the SDK, including a
  # mutable cmdline-tools/latest that updates itself from then on.
  cmdlineTools = pkgs.fetchzip {
    url = "https://dl.google.com/android/repository/commandlinetools-linux-16111833_latest.zip";
    hash = "sha256-qYP3Hc7UJVPGm8IChBYGnC1Y0PqHuIfXpa13Sl0DUes=";
  };

  # SDK-style paths, the form the Android CLI takes and the directory each
  # package unpacks to.
  packages = [
    "cmdline-tools/latest"
    "platform-tools"
    "platforms/android-36"
    "build-tools/36.0.0"
  ];

  cli = if androidCli == null then "${cmdlineTools}/bin/android" else androidCli;

  provision = pkgs.writeShellApplication {
    name = "android-sdk-provision";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      sdk_root=''${1:?usage: android-sdk-provision SDK_ROOT}

      missing=()
      for package in ${escapeShellArgs packages}; do
        if [ ! -f "$sdk_root/$package/package.xml" ]; then
          missing+=("$package")
        fi
      done

      if [ "''${#missing[@]}" -eq 0 ]; then
        echo "Android SDK at $sdk_root already carries every declared package"
        exit 0
      fi

      mkdir -p "$sdk_root"
      echo "Installing into $sdk_root: ''${missing[*]}"
      ${cli} --no-metrics --sdk="$sdk_root" sdk install "''${missing[@]}"

      # The CLI can exit 0 after skipping a package it could not resolve, so
      # the unit fails, and retries, until every package is really on disk.
      for package in "''${missing[@]}"; do
        if [ ! -f "$sdk_root/$package/package.xml" ]; then
          echo "Android SDK package $package is still missing from $sdk_root" >&2
          exit 1
        fi
      done
    '';
  };
in
{
  inherit cmdlineTools packages provision;
}
