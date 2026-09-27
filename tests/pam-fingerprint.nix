/*
  Check interface:

    import ./tests/pam-fingerprint.nix { inherit pkgs self; }

  Asserts which PAM services the fingerprint factor reaches, on every
  configuration `tests/lib/configurations.nix` yields. Whether a configuration
  should carry the factor is computed from its `my.fingerprint.enable` trait and
  its `my.bootstrap` flag -- the trait on a production configuration -- never
  from `services.fprintd.enable` or `security.pam`, the options the module
  under test sets. At least one production configuration must enable the trait,
  or the helper fails the check, so the positive branch never covers zero
  configurations.

  It reads `config.environment.etc."pam.d/<name>".source` -- the file the etc
  module materialises into /etc -- rather than
  `security.pam.services.<name>.text`. The latter is a module option value that
  also evaluates for services that never reach the built system, which is the
  weaker assertion this repository's learnings warn against. Entries are
  resolved by their `target`, not by their attribute name, because `target`
  merely defaults to the attribute name and is what decides the destination;
  each entry's `enable` is respected for the same reason.

  Verifies, on every production configuration that enables the trait:
  - `sudo`, `polkit-1` and `kde-fingerprint` carry pam_fprintd.so. Without this
    positive control every negative below would fold to a constant the moment
    fprintd stopped being enabled at all.
  - `kde` does not carry it. Upstream withholds it there because a fingerprint
    in the `kde` stack can block password login; the lock screen reaches the
    factor through `kde-fingerprint` instead.
  - nothing in the transitive auth include closure of `login`, `sddm`,
    `sddm-greeter` or `sddm-autologin` carries it. The closure is what makes
    this real: `sddm` carries no rules of its own, its auth stack is
    `substack login`, so asserting on `sddm` alone would assert on nothing.
  - nothing in the closure of `enroll-fingerprint` carries it, so a fingerprint
    can never authorize enrolling another fingerprint.
  - the materialized polkit rules allow `net.reactivated.fprint.device.enroll`
    to root and members of the wheel group while denying unprivileged users.
  - `passwd`, `chpasswd`, `chsh`, `chfn` and `su` do not carry it, so the weaker
    credential cannot be used to set the stronger one.
  - the exact set of files carrying it equals the allowlist stated below. This
    is the point of the design: a service a future nixpkgs or Plasma release
    introduces arrives with fprintAuth on, is neither greeter-reachable nor on
    any deny list, and turns this check red rather than inheriting the factor
    unnoticed.

  Verifies, on every other configuration -- every bootstrap output, and every
  production configuration that leaves the trait off:
  - the same negatives, no polkit enroll rule, and an empty allowlist. A
    bootstrap output has no enrolled finger, and a configuration without the
    trait has no reader, so none of them may materialise a PAM file carrying
    the factor.

  The collected set is asserted non-empty per configuration, so the negatives
  can never pass over nothing.

  Negative assertions are written as explicit `if ... then ... fi` branches.
  POSIX exempts a command whose status is inverted by `!` from `set -e`, so a
  bare `! grep` in a Nix builder is a comment wearing an assertion's clothes.
  Every assertion slices the `auth` stack first, because an account or session
  line naming the module would not be an authentication factor. Failures
  accumulate into `failed` and the builder exits once at the end, so one red
  build names every broken assertion across every configuration -- a mutation
  round that stops at the first failure leaves every later assertion unproven.
*/
{ pkgs, self }:
let
  inherit (pkgs.lib)
    attrValues
    concatMapStrings
    concatMapStringsSep
    concatStringsSep
    escapeShellArg
    filter
    hasPrefix
    removePrefix
    ;

  # Everything below is text spliced into a shell script; escape it rather than
  # trusting the values to be quote-free.
  esc = value: escapeShellArg (toString value);

  fail = message: ''
    echo ${esc message} >&2
    failed=1
  '';

  /*
    DUPLICATION IS DELIBERATE. This allowlist is an independent literal. It is
    not derived from, and must not be derived from, the `fprintAuth = false`
    lists in modules/nixos/hardware/fingerprint.nix, and that module must not
    read this. If one edit could change both sides, a change that hands the
    factor to the greeter would arrive with a matching allowlist and this check
    would stay green -- which is the entire failure mode it exists to prevent.

    It was read off the built system rather than guessed: every service that
    carries pam_fprintd.so once fprintd is enabled either appears here as a
    deliberate entry or is denied in the module. Adding an entry here later is a
    deliberate act, which is the property this closed-world comparison buys.
  */
  # Applies to a configuration whose trait and bootstrap flag say the factor
  # belongs there; every other configuration is checked against nothing being
  # allowed.
  factorAllowlist = [
    # The three surfaces this feature exists for.
    "sudo"
    "polkit-1"
    "kde-fingerprint"
    # Inherited from the upstream default rules. None is greeter-reachable and
    # none mutates a credential; narrowing them further is follow-up work, and
    # this list is what keeps the set from growing in the meantime.
    "groupadd"
    "groupdel"
    "groupmems"
    "groupmod"
    "runuser"
    "runuser-l"
    "systemd-run0"
    "systemd-user"
    "useradd"
    "userdel"
    "usermod"
    "vlock"
  ];

  # Asserted to carry the factor. A subset of the allowlist, stated separately
  # so the check still names the surfaces the feature promises when the
  # allowlist comparison is the thing that changed.
  factorSurfaces = [
    "sudo"
    "polkit-1"
    "kde-fingerprint"
  ];

  # The greeter inherits through `login`, so the roots are followed transitively
  # rather than asserted one file at a time.
  greeterRoots = [
    "login"
    "sddm"
    "sddm-greeter"
    "sddm-autologin"
  ];

  # A configuration without the factor has no enrollment path at all: the
  # module that declares this service is off there, so the service legitimately
  # materialises no file.
  factorEnrollRoots = [ "enroll-fingerprint" ];

  configurations = import ./lib/configurations.nix { inherit pkgs self; };
  fingerprint = configurations.withTrait "my.fingerprint.enable" (
    config: config.my.fingerprint.enable
  );

  # The expectation: the trait, withheld from bootstrap outputs. Derived from
  # the trait and `bootstrap`, never from what the module under test sets.
  expectsFactor = entry: entry.config.my.fingerprint.enable && !entry.bootstrap;
  whenFactor = entry: list: if expectsFactor entry then list else [ ];

  # Asserted directly: these have no relevant includes and the point is the file
  # itself. `kde` is here for the upstream reason quoted in the header.
  mustNotCarry = [
    "kde"
    "passwd"
    "chpasswd"
    "chsh"
    "chfn"
    "su"
  ];

  # Resolve the materialised PAM files by target. `pam.d/` entries only, honouring
  # each entry's `enable`, and skipping any nested target so the flat directory
  # built below cannot silently lose a file.
  pamEntries =
    config:
    filter (
      entry:
      (entry.enable or false)
      && hasPrefix "pam.d/" (entry.target or "")
      && (builtins.match ".*/.*" (removePrefix "pam.d/" (entry.target or "")) == null)
    ) (attrValues config.environment.etc);

  hostAssertions =
    entry:
    let
      hostName = entry.name;
      dir = "pam-${hostName}";
      entries = pamEntries entry.config;

      # The store path stays inside a guard: an entry whose source went away must
      # fail inside the builder, not abort evaluation on a null coercion.
      copyLine =
        pamEntry:
        let
          name = removePrefix "pam.d/" pamEntry.target;
          source = pamEntry.source or null;
        in
        if source == null then
          fail "${hostName}: the /etc entry targeting ${pamEntry.target} materialises no source"
        else
          "cp -- ${esc (toString source)} ${esc "${dir}/${name}"}\n";

      expectedLines = concatMapStrings (
        name: "printf '%s\\n' ${esc name} >> ${esc "${dir}.expected"}\n"
      ) (whenFactor entry factorAllowlist);

      presentLines = concatMapStrings (name: ''
        if [ ! -f ${esc "${dir}/${name}"} ]; then
          ${fail "${hostName}: no PAM file is materialised for ${name}"}
        elif ! authStack ${esc "${dir}/${name}"} | grep -q pam_fprintd.so; then
          ${fail "${hostName}: ${name} no longer carries the fingerprint factor"}
        fi
      '') (whenFactor entry factorSurfaces);

      absentLines = concatMapStrings (name: ''
        if [ ! -f ${esc "${dir}/${name}"} ]; then
          ${fail "${hostName}: no PAM file is materialised for ${name}"}
        elif authStack ${esc "${dir}/${name}"} | grep -q pam_fprintd.so; then
          ${fail "${hostName}: ${name} carries the fingerprint factor and must not"}
        fi
      '') mustNotCarry;

      closureLines = label: roots: ''
        closure ${esc hostName} ${esc dir} ${concatStringsSep " " (map esc roots)}
        for service in $CLOSURE; do
          if authStack "${dir}/$service" | grep -q pam_fprintd.so; then
            echo "${hostName}: $service is reachable from ${label} and carries the fingerprint factor" >&2
            failed=1
          fi
        done
      '';

      polkitEntry = entry.config.environment.etc."polkit-1/rules.d/10-nixos.rules" or null;
      polkitSource = if polkitEntry != null then polkitEntry.source or null else null;

      polkitLines =
        if expectsFactor entry then
          ''
            polkitFile=${esc (toString polkitSource)}
            if [ -z "$polkitFile" ] || [ ! -f "$polkitFile" ]; then
              ${fail "${hostName}: polkit rules file is missing"}
            elif ! grep -q 'action.id == "net.reactivated.fprint.device.enroll"' "$polkitFile"; then
              ${fail "${hostName}: polkit rules do not name the fprint enroll action"}
            elif ! grep -F -A 6 'action.id == "net.reactivated.fprint.device.enroll"' "$polkitFile" | grep -q 'return polkit.Result.NO;'; then
              ${fail "${hostName}: polkit rule does not deny fprint enroll to non-wheel users"}
            elif ! grep -F -A 6 'action.id == "net.reactivated.fprint.device.enroll"' "$polkitFile" | grep -q 'subject.user == "root"'; then
              ${fail "${hostName}: polkit rule does not allow fprint enroll to root"}
            elif ! grep -F -A 6 'action.id == "net.reactivated.fprint.device.enroll"' "$polkitFile" | grep -q 'subject.isInGroup("wheel")'; then
              ${fail "${hostName}: polkit rule does not allow fprint enroll to wheel group"}
            fi
          ''
        else
          ''
            polkitFile=${esc (toString polkitSource)}
            if [ -n "$polkitFile" ] && [ -f "$polkitFile" ] && grep -q 'net.reactivated.fprint.device.enroll' "$polkitFile"; then
              ${fail "${hostName}: polkit rules carry fprint enroll rule unexpectedly"}
            fi
          '';
    in
    ''
      mkdir -p ${esc dir}
      ${concatMapStrings copyLine entries}
      collected=$(find ${esc dir} -type f | wc -l)
      if [ "$collected" -eq 0 ]; then
        ${fail "${hostName}: no pam.d entry was collected, so every assertion below would pass over nothing"}
      fi

      ${presentLines}
      ${absentLines}
      ${closureLines "the login greeter" greeterRoots}
      ${closureLines "fingerprint enrollment" (whenFactor entry factorEnrollRoots)}
      ${polkitLines}

      : > ${esc "${dir}.expected"}
      ${expectedLines}
      sort -o ${esc "${dir}.expected"} ${esc "${dir}.expected"}

      : > ${esc "${dir}.actual"}
      for file in ${esc dir}/*; do
        [ -f "$file" ] || continue
        if authStack "$file" | grep -q pam_fprintd.so; then
          printf '%s\n' "''${file##*/}" >> ${esc "${dir}.actual"}
        fi
      done
      sort -o ${esc "${dir}.actual"} ${esc "${dir}.actual"}

      if ! diff -u ${esc "${dir}.expected"} ${esc "${dir}.actual"} > ${esc "${dir}.diff"}; then
        ${fail "${hostName}: the set of PAM files carrying pam_fprintd.so is not the allowlist"}
        cat ${esc "${dir}.diff"} >&2
      fi
    '';

  # Every configuration the flake builds, not a named pair. A host added later
  # is checked against an empty allowlist unless its trait says otherwise, so
  # the closed-world property applies to the host set as well as to the service
  # set.
  hostBodies = concatMapStringsSep "\n" hostAssertions configurations.entries;
in
pkgs.runCommand "pam-fingerprint-tests"
  {
    nativeBuildInputs = [
      pkgs.gawk
      pkgs.gnugrep
      pkgs.diffutils
    ];
  }
  ''
    # The greps below are quiet by design, so trace every assertion: the failing
    # one is then the last traced line in `nix log`.
    set -x
    ${configurations.guard}
    ${fingerprint.guard}
    failed=0

    # A module line only authenticates if it is in the auth stack. Slice first so
    # an account or session mention cannot be mistaken for a factor.
    authStack() {
      awk '$1 == "auth"' "$1"
    }

    # Follow auth-phase include and substack references transitively. `sddm`
    # carries no rules of its own, so without this the greeter assertions would
    # inspect a file that says only `auth substack login`.
    closure() {
      closureHost=$1
      closureDir=$2
      shift 2
      pending="$*"
      seen=""
      while [ -n "$pending" ]; do
        next=""
        for service in $pending; do
          case " $seen " in
            *" $service "*) continue ;;
          esac
          if [ ! -f "$closureDir/$service" ]; then
            echo "$closureHost: PAM service $service materialises no file" >&2
            failed=1
            continue
          fi
          seen="$seen $service"
          next="$next $(awk '$1 == "auth" && ($2 == "include" || $2 == "substack") { print $3 }' \
            "$closureDir/$service")"
        done
        pending="$next"
      done
      CLOSURE=$seen
    }

    ${hostBodies}

    if [ "$failed" != 0 ]; then
      exit 1
    fi
    touch $out
  ''
