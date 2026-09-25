{ pkgs }:

let
  inherit (pkgs) lib;

  # The pin file scripts/android-sdk-release writes. It is androidenv's own
  # repo.json format trimmed to the packages below, so every version and
  # archive checksum comes from this repository rather than from nixpkgs.
  repoJson = ./android-sdk-repo.json;
  repo = lib.importJSON repoJson;

  # Accepting here, not through nixpkgs.config, keeps the acceptance next to
  # the one SDK it applies to. androidenv refuses to build without it.
  androidenv = pkgs.androidenv.override { licenseAccepted = true; };

  composition = androidenv.composeAndroidPackages {
    inherit repoJson;
    # The legacy tools package is superseded by cmdline-tools and absent here.
    toolsVersion = null;
    cmdLineToolsVersion = repo.latest.cmdline-tools;
    platformToolsVersion = repo.latest.platform-tools;
    buildToolsVersions = builtins.attrNames repo.packages.build-tools;
    platformVersions = builtins.attrNames repo.packages.platforms;
    includeEmulator = false;
    includeSources = false;
    includeSystemImages = false;
    includeNDK = false;
    cmakeVersions = [ ];
    ndkVersions = [ ];
  };
in
{
  inherit repo;
  inherit (composition) androidsdk;
  sdkRoot = "${composition.androidsdk}/libexec/android-sdk";
}
