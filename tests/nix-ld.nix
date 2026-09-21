/*
  Check interface:

    import ./tests/nix-ld.nix { inherit pkgs self; }

  Asserts that nix-ld is enabled and configured with the required baseline
  libraries on both the production and bootstrap ThinkPad configurations.

  Verifies:
  - programs.nix-ld.enable is true on ThinkPad-X1-Carbon-Gen-11.
  - programs.nix-ld.enable is true on ThinkPad-X1-Carbon-Gen-11-bootstrap.
  - environment.ldso points to the nix-ld binary.
  - environment.sessionVariables carries NIX_LD and NIX_LD_LIBRARY_PATH.
  - programs.nix-ld.libraries contains stdenv.cc.cc.lib, zlib, and openssl.
*/
{ pkgs, self }:
let
  host = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11;
  bootstrapHost = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap;

  hostEnabled = host.config.programs.nix-ld.enable;
  bootstrapEnabled = bootstrapHost.config.programs.nix-ld.enable;
  ldsoPath = host.config.environment.ldso;
  nixLdVar = host.config.environment.sessionVariables.NIX_LD or "";
  nixLdLibPathVar = host.config.environment.sessionVariables.NIX_LD_LIBRARY_PATH or "";

  libNames = builtins.map (p: p.name) host.config.programs.nix-ld.libraries;
  hasGcc = pkgs.lib.lists.any (name: pkgs.lib.strings.hasPrefix "gcc" name) libNames;
  hasZlib = pkgs.lib.lists.any (name: pkgs.lib.strings.hasPrefix "zlib" name) libNames;
  hasOpenssl = pkgs.lib.lists.any (name: pkgs.lib.strings.hasPrefix "openssl" name) libNames;
in
pkgs.runCommand "nix-ld-tests"
  {
    nativeBuildInputs = [
      pkgs.gnugrep
    ];
  }
  ''
    set -x

    # 1. Verify nix-ld is enabled on production host
    if [ "${builtins.toJSON hostEnabled}" != "true" ]; then
      echo "programs.nix-ld.enable is not true on ThinkPad-X1-Carbon-Gen-11" >&2
      exit 1
    fi

    # 2. Verify nix-ld is enabled on bootstrap host
    if [ "${builtins.toJSON bootstrapEnabled}" != "true" ]; then
      echo "programs.nix-ld.enable is not true on ThinkPad-X1-Carbon-Gen-11-bootstrap" >&2
      exit 1
    fi

    # 3. Verify ldso points to nix-ld binary
    if ! echo '${ldsoPath}' | grep -q "/libexec/nix-ld$"; then
      echo "environment.ldso does not point to /libexec/nix-ld: '${ldsoPath}'" >&2
      exit 1
    fi

    # 4. Verify NIX_LD and NIX_LD_LIBRARY_PATH session variables
    if [ '${nixLdVar}' != "/run/current-system/sw/share/nix-ld/lib/ld.so" ]; then
      echo "NIX_LD session variable is incorrect: '${nixLdVar}'" >&2
      exit 1
    fi

    if [ '${nixLdLibPathVar}' != "/run/current-system/sw/share/nix-ld/lib" ]; then
      echo "NIX_LD_LIBRARY_PATH session variable is incorrect: '${nixLdLibPathVar}'" >&2
      exit 1
    fi

    # 5. Verify required libraries are present in programs.nix-ld.libraries
    if [ "${builtins.toJSON hasGcc}" != "true" ]; then
      echo "stdenv.cc.cc.lib (gcc) missing from programs.nix-ld.libraries" >&2
      exit 1
    fi

    if [ "${builtins.toJSON hasZlib}" != "true" ]; then
      echo "zlib missing from programs.nix-ld.libraries" >&2
      exit 1
    fi

    if [ "${builtins.toJSON hasOpenssl}" != "true" ]; then
      echo "openssl missing from programs.nix-ld.libraries" >&2
      exit 1
    fi

    touch $out
  ''
