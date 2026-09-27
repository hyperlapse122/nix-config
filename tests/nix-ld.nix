/*
  Check interface:

    import ./tests/nix-ld.nix { inherit pkgs self; }

  Asserts that nix-ld is enabled and configured with the required baseline
  libraries on every configuration `tests/lib/configurations.nix` yields,
  production and bootstrap alike.

  Verifies, per configuration:
  - programs.nix-ld.enable is true.
  - environment.ldso points to the nix-ld binary.
  - environment.sessionVariables carries NIX_LD and NIX_LD_LIBRARY_PATH.
  - programs.nix-ld.libraries contains stdenv.cc.cc.lib, zlib, and openssl.

  The builder collects every failure before it exits, so one red build names
  every affected configuration.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self; };

  esc = value: lib.escapeShellArg (toString value);

  fail = message: ''
    echo ${esc message} >&2
    failed=1
  '';

  checkHost =
    entry:
    let
      inherit (entry) config name;
      enabled = config.programs.nix-ld.enable or false;
      ldsoPath = config.environment.ldso or "";
      nixLdVar = config.environment.sessionVariables.NIX_LD or "";
      nixLdLibPathVar = config.environment.sessionVariables.NIX_LD_LIBRARY_PATH or "";

      libNames = map (p: p.name) (config.programs.nix-ld.libraries or [ ]);
      hasLib = prefix: lib.lists.any (lib.strings.hasPrefix prefix) libNames;
    in
    ''
      # 1. nix-ld is enabled
      if [ "${builtins.toJSON enabled}" != "true" ]; then
        ${fail "programs.nix-ld.enable is not true on ${name}"}
      fi

      # 2. ldso points to the nix-ld binary
      if ! echo ${esc ldsoPath} | grep -q "/libexec/nix-ld$"; then
        ${fail "environment.ldso does not point to /libexec/nix-ld on ${name}: '${ldsoPath}'"}
      fi

      # 3. NIX_LD and NIX_LD_LIBRARY_PATH session variables
      if [ ${esc nixLdVar} != "/run/current-system/sw/share/nix-ld/lib/ld.so" ]; then
        ${fail "NIX_LD session variable is incorrect on ${name}: '${nixLdVar}'"}
      fi
      if [ ${esc nixLdLibPathVar} != "/run/current-system/sw/share/nix-ld/lib" ]; then
        ${fail "NIX_LD_LIBRARY_PATH session variable is incorrect on ${name}: '${nixLdLibPathVar}'"}
      fi

      # 4. required libraries are present in programs.nix-ld.libraries
      if [ "${builtins.toJSON (hasLib "gcc")}" != "true" ]; then
        ${fail "stdenv.cc.cc.lib (gcc) missing from programs.nix-ld.libraries on ${name}"}
      fi
      if [ "${builtins.toJSON (hasLib "zlib")}" != "true" ]; then
        ${fail "zlib missing from programs.nix-ld.libraries on ${name}"}
      fi
      if [ "${builtins.toJSON (hasLib "openssl")}" != "true" ]; then
        ${fail "openssl missing from programs.nix-ld.libraries on ${name}"}
      fi
    '';
in
pkgs.runCommand "nix-ld-tests"
  {
    nativeBuildInputs = [
      pkgs.gnugrep
    ];
  }
  ''
    set -x
    ${configurations.guard}
    failed=0

    ${lib.concatMapStringsSep "\n" checkHost configurations.entries}

    if [ "$failed" != 0 ]; then
      exit 1
    fi
    touch $out
  ''
