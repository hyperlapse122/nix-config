/*
  Check interface:

    import ./tests/yubikey-fido.nix { inherit pkgs self; }

  Asserts that the YubiKey inventory tooling reaches both ThinkPad
  configurations as built output. Every assertion below reads something
  activation produces -- the system path, the materialised udev rules
  directory, a rendered systemd unit, h82's Home Manager profile -- rather than
  the option lists those are derived from. An option list sits one level above
  the built system: environment.systemPackages can carry a package that
  pathsToLink or a collision keeps out of system.path, and
  services.udev.packages can carry a derivation whose rules never reach
  /etc/udev/rules.d.

  Verifies, on ThinkPad-X1-Carbon-Gen-11 and ThinkPad-X1-Carbon-Gen-11-bootstrap:
  - the system path carries bin/ykman.
  - h82's Home Manager profile carries bin/yubioath-flutter and the Yubico
    Authenticator desktop entry.
  - the materialised udev rules directory carries 69-yubikey.rules, which the
    yubikey-manager module contributes.
  - that same directory carries 60-fido-id.rules and 70-uaccess.rules. Those
    two, not the vendor rule, hand an inserted key to the seat's logged-in
    user, so they are the mechanism the no-manual-permission-step promise rests
    on. They come from systemd rather than from anything this repository
    declares, which is why asserting them is worth the lines: a conflicting
    rule, or a systemd change that drops either one, would otherwise stay
    invisible until someone met a permission error on real hardware.
  - the pcscd socket unit is rendered into the built system.

  The builder collects every failure instead of exiting at the first, so one red
  build names every broken assertion across both hosts. That matters for the
  mutation rounds this repository requires: exiting early leaves all but the
  first assertion unobserved, and a round that produces no evidence for an
  assertion proves nothing about it.
*/
{ pkgs, self }:
let
  inherit (pkgs.lib)
    lists
    optionalString
    concatStringsSep
    mapAttrsToList
    escapeShellArg
    ;

  # Every message and path below is text spliced into a shell script. Escape it
  # rather than trusting the values to be quote-free: an apostrophe in one label
  # already closed a quote here once and swallowed the assertions after it into
  # a single echo, leaving a check that printed a failure and then passed. The
  # apostrophe in the home.packages label below is kept deliberately, so that
  # losing this escaping breaks the build instead of going quiet.
  esc = value: escapeShellArg (toString value);

  fail = message: ''
    echo ${esc message} >&2
    failed=1
  '';

  # Assert a path inside an already-materialised output. `root` may be null,
  # which is how a disabled service reaches this function: the attribute holding
  # its rendered unit is absent, so the caller resolves it with `or null` and the
  # absent branch reports it. Interpolating a null root instead would abort
  # evaluation before the builder ran, and a mutation round that dies in the
  # evaluator has proven nothing about the assertion it was aimed at.
  assertPath =
    {
      flag,
      root,
      path,
      message,
      absentMessage ? message,
    }:
    if root == null then
      fail absentMessage
    else
      ''
        if [ ! ${flag} ${esc "${root}/${path}"} ]; then
          ${fail message}
        fi
      '';

  # Resolve a package out of a list by pname so a diagnostic can name what is
  # missing. The store path is never interpolated here, and the absent branch
  # stays inside optionalString, so a removed package fails inside the builder
  # with the message below rather than aborting evaluation on a null coercion.
  assertListed =
    {
      hostName,
      listLabel,
      packages,
      pname,
    }:
    let
      found = lists.findFirst (p: (p.pname or "") == pname) null packages;
    in
    optionalString (found == null) (fail "${hostName}: ${listLabel} carries no ${pname}");

  udevRuleNames = [
    "69-yubikey.rules"
    "60-fido-id.rules"
    "70-uaccess.rules"
  ];

  hostAssertions =
    hostName: host:
    let
      userConfig = host.config.home-manager.users.h82;
      userPath = userConfig.home.path;
      udevRules = host.config.environment.etc."udev/rules.d".source;
    in
    concatStringsSep "\n" (
      [
        (assertListed {
          inherit hostName;
          listLabel = "environment.systemPackages";
          packages = host.config.environment.systemPackages;
          pname = "yubikey-manager";
        })
        (assertPath {
          flag = "-x";
          root = host.config.system.path;
          path = "bin/ykman";
          message = "${hostName}: the system path ships no bin/ykman";
        })
        (assertListed {
          inherit hostName;
          listLabel = "h82's home.packages";
          packages = userConfig.home.packages;
          pname = "yubioath-flutter";
        })
        (assertPath {
          flag = "-x";
          root = userPath;
          path = "bin/yubioath-flutter";
          message = "${hostName}: the h82 profile ships no bin/yubioath-flutter";
        })
        (assertPath {
          flag = "-f";
          root = userPath;
          path = "share/applications/com.yubico.yubioath.desktop";
          message = "${hostName}: the h82 profile ships no Yubico Authenticator desktop entry";
        })
        (assertPath {
          flag = "-f";
          root = host.config.systemd.units."pcscd.socket".unit or null;
          path = "pcscd.socket";
          message = "${hostName}: the built system renders no pcscd.socket unit";
          absentMessage = "${hostName}: the built system declares no pcscd.socket unit at all";
        })
      ]
      ++ map (
        rule:
        assertPath {
          flag = "-f";
          root = udevRules;
          path = rule;
          message = "${hostName}: the materialised udev rules carry no ${rule}";
        }
      ) udevRuleNames
    );
in
pkgs.runCommand "yubikey-fido-tests" { } ''
  set -x
  failed=0

  ${concatStringsSep "\n" (
    mapAttrsToList hostAssertions {
      ThinkPad-X1-Carbon-Gen-11 = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11;
      ThinkPad-X1-Carbon-Gen-11-bootstrap = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap;
    }
  )}

  if [ "$failed" != 0 ]; then
    exit 1
  fi
  touch $out
''
