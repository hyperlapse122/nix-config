{
  config,
  lib,
  ...
}:
let
  cfg = config.my.system.cross-compile;
in
{
  options.my.system.cross-compile = {
    aarch64 = {
      enable = lib.mkEnableOption "aarch64 (arm64) cross-compilation + foreign-arch binary execution support (binfmt_misc + QEMU user-mode)";
    };
  };

  config = lib.mkIf cfg.aarch64.enable {
    # binfmt_misc kernel feature + QEMU user-mode emulation lets aarch64-linux binaries run
    # directly on an x86_64 host.
    #
    # This single line opens up two workflows simultaneously:
    #   1) Run cross-compiled artifacts directly
    #      `nix build nixpkgs#pkgsCross.aarch64-multiplatform.hello`
    #      → ./result/bin/hello executes via the binfmt-registered qemu-aarch64.
    #   2) Run native aarch64 builds on top of QEMU
    #      `import <nixpkgs> { localSystem = "aarch64-linux"; }`, or the flake-style
    #      pkgsCrossNative pattern — this path can pull cache.nixos.org's aarch64-linux
    #      artifacts (Hydra caches native aarch64), shrinking build times dramatically.
    #      In contrast, (1)'s cross-compiled artifacts are not cached and must be built locally.
    #
    # The NixOS module `boot.binfmt.emulatedSystems` automatically adds the same system to
    # `nix.settings.extra-platforms`, so nix recognizes that system's derivations as buildable
    # — no extra config needed.
    #
    # Reference: https://wiki.nixos.org/wiki/Cross_Compiling
    boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  };
}
