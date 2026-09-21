/*
  Check interface:

    import ./tests/yubikey-fido.nix { inherit pkgs self; }

  Asserts that the YubiKey inventory tooling reaches both ThinkPad
  configurations as materialised output rather than as a declared option.
  Reading programs.yubikey-manager.enable would stay green while a mkIf
  elsewhere, or a sibling enable flag, kept the package out of the built
  system, so every assertion below resolves what the configuration actually
  produces.

  Verifies, on ThinkPad-X1-Carbon-Gen-11 and ThinkPad-X1-Carbon-Gen-11-bootstrap:
  - environment.systemPackages carries yubikey-manager, shipping bin/ykman.
  - services.udev.packages carries yubikey-personalization, shipping
    lib/udev/rules.d/69-yubikey.rules.
  - home.packages for h82 carries yubioath-flutter, shipping bin/yubioath-flutter
    and the Yubico Authenticator desktop entry.
  - services.pcscd.enable is true. That one is a standing precondition rather
    than a guard on anything declared here: modules/nixos/base.nix sets it
    unconditionally, so no mutation of the yubikey module can turn it red.
*/
{ pkgs, self }:
let
  inherit (pkgs.lib)
    lists
    optionalString
    concatMapStrings
    concatStringsSep
    mapAttrsToList
    ;

  hosts = {
    ThinkPad-X1-Carbon-Gen-11 = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11;
    ThinkPad-X1-Carbon-Gen-11-bootstrap = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap;
  };

  # Resolve a package out of a materialised list by pname and assert the files
  # it must ship. Every store-path interpolation stays inside an optionalString
  # guard so that dropping the package fails inside the builder with the message
  # below, rather than aborting evaluation with a null coercion error.
  assertPackage =
    {
      hostName,
      listLabel,
      packages,
      pname,
      files,
    }:
    let
      found = lists.findFirst (p: (p.pname or "") == pname) null packages;
      absent = optionalString (found == null) ''
        echo '${hostName}: ${listLabel} carries no ${pname}' >&2
        exit 1
      '';
      present = optionalString (found != null) (
        concatMapStrings (file: ''
          if [ ! ${file.flag} ${found}/${file.path} ]; then
            echo '${hostName}: ${pname} ships no ${file.path}' >&2
            exit 1
          fi
        '') files
      );
    in
    absent + present;

  assertBool =
    {
      hostName,
      label,
      value,
    }:
    ''
      if [ "${builtins.toJSON value}" != "true" ]; then
        echo '${hostName}: ${label} is not true' >&2
        exit 1
      fi
    '';

  hostAssertions =
    hostName: host:
    concatStringsSep "\n" [
      (assertPackage {
        inherit hostName;
        listLabel = "environment.systemPackages";
        packages = host.config.environment.systemPackages;
        pname = "yubikey-manager";
        files = [
          {
            flag = "-x";
            path = "bin/ykman";
          }
        ];
      })
      (assertPackage {
        inherit hostName;
        listLabel = "services.udev.packages";
        packages = host.config.services.udev.packages;
        pname = "yubikey-personalization";
        files = [
          {
            flag = "-f";
            path = "lib/udev/rules.d/69-yubikey.rules";
          }
        ];
      })
      (assertPackage {
        inherit hostName;
        # No apostrophe in any label: these are interpolated into single-quoted
        # echo arguments, where one would close the quote and swallow every
        # assertion after it into that echo.
        listLabel = "home.packages for h82";
        packages = host.config.home-manager.users.h82.home.packages;
        pname = "yubioath-flutter";
        files = [
          {
            flag = "-x";
            path = "bin/yubioath-flutter";
          }
          {
            flag = "-f";
            path = "share/applications/com.yubico.yubioath.desktop";
          }
        ];
      })
      (assertBool {
        inherit hostName;
        label = "services.pcscd.enable";
        value = host.config.services.pcscd.enable;
      })
    ];
in
pkgs.runCommand "yubikey-fido-tests" { } ''
  set -x

  ${concatStringsSep "\n" (mapAttrsToList hostAssertions hosts)}

  touch $out
''
