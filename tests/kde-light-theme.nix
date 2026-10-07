/*
  Check interface:

    import ./tests/kde-light-theme.nix { inherit pkgs self; }

  Asserts that Plasma defaults to Breeze Light, both as the system-wide KDE
  default and for h82's own kdeglobals.

  Verifies, on every configuration `tests/lib/configurations.nix` yields,
  production and bootstrap alike, by reading the materialised
  /etc/xdg/kdeglobals rather than the option that renders it:
  - [KDE] LookAndFeelPackage is org.kde.breeze.desktop.
  - [General] ColorScheme is BreezeLight.
  - [Icons] Theme is breeze.
  - every [Colors:*], [ColorEffects:*], and [WM] entry of the packaged
    BreezeLight.colors, nested groups included, carries its packaged value.
    KColorScheme falls back to built-in colors when the groups are absent, so
    the scheme name alone is not enough. The light Window background is also
    checked to differ from BreezeDark.colors, so a dark scheme cannot pass.
  - the existing TerminalApplication and Locale entries survive.

  Verifies, on every configuration as well (home/h82/desktop/kde/theme.nix is
  not gated on my.bootstrap), by running the kdeTheme Home Manager activation
  against two fixture HOMEs, with the built /etc/xdg in XDG_CONFIG_DIRS: one
  whose kdeglobals holds the Breeze Dark color, color effect, and window
  manager groups, scheme name, look-and-feel package, and icon theme, and one
  that holds a value no light entry has in every copied entry and identity
  key, because the two schemes share many entries. Seeding values other than
  the light ones keeps the light system defaults from masking a missing
  write. On each fixture:
  - the effective (user, else system) values are ColorScheme BreezeLight, the
    Breeze Light look-and-feel package, and the breeze icon theme.
  - the effective value of every copied BreezeLight.colors entry is the light
    one. The user file's own groups override /etc/xdg, and
    plasma-apply-colorscheme reads the cascaded ColorScheme=BreezeLight as
    already applied and writes nothing, so only a direct write turns h82
    light. Comparing every entry, not a sample, fails when one group such as
    [WM] is no longer written.
  - an unrelated user key survives.

  It cannot see whether a running session repaints; docs/verification.md
  carries the hardware check for that. Every failure is collected in one build.
*/
{ pkgs, self }:
let
  inherit (pkgs.lib) attrNames concatMapStringsSep escapeShellArg;

  configurations = import ./lib/configurations.nix { inherit pkgs self; };

  esc = value: escapeShellArg (toString value);

  colorSchemes = "${pkgs.kdePackages.breeze}/share/color-schemes";

  # The groups home/h82/desktop/kde/theme.nix and
  # modules/nixos/desktop/desktop.nix copy out of a packaged scheme.
  copiedGroups = ''/^\[/ { keep = ($0 ~ /^\[(Colors|ColorEffects):/ || $0 == "[WM]") }'';

  fail = message: ''
    echo ${esc message} >&2
    failed=1
  '';

  etcAssertions =
    entry:
    let
      kdeglobals = "${entry.config.system.build.etc}/etc/xdg/kdeglobals";
      expectKey = group: key: value: ''
        if [ "$(ini_get ${esc kdeglobals} ${esc group} ${esc key})" != ${esc value} ]; then
          ${fail "${entry.name}: /etc/xdg/kdeglobals [${group}] ${key} is not ${value}"}
        fi
      '';
    in
    ''
      if [ ! -f ${esc kdeglobals} ]; then
        ${fail "${entry.name}: /etc/xdg/kdeglobals is missing"}
      else
        ${expectKey "KDE" "LookAndFeelPackage" "org.kde.breeze.desktop"}
        ${expectKey "General" "ColorScheme" "BreezeLight"}
        ${expectKey "Icons" "Theme" "breeze"}
        ${expectKey "General" "TerminalApplication" "ghostty"}
        ${expectKey "Locale" "Language" "ko:en_US"}
        expect_scheme ${esc "${entry.name}: /etc/xdg/kdeglobals"} ini_get ${esc kdeglobals}
      fi
    '';

  # User kdeglobals fixtures the activation must convert. `dark` is what the
  # previous Breeze Dark default left behind. Breeze Dark and Breeze Light
  # share many entries (every [ColorEffects:*] one among them), so `stale`
  # also seeds every copied entry and identity key with a value no light entry
  # has, and a skipped write cannot pass by already holding the light value.
  fixtures = {
    dark = ''
      printf '[General]\nBrowserApplication=fixture.desktop\nColorScheme=BreezeDark\n\n'
      printf '[Icons]\nTheme=breeze-dark\n\n[KDE]\nLookAndFeelPackage=org.kde.breezedark.desktop\n\n'
      awk ${esc "${copiedGroups} keep { print }"} ${esc "${colorSchemes}/BreezeDark.colors"}
    '';
    stale = ''
      printf '[General]\nBrowserApplication=fixture.desktop\nColorScheme=stale\n\n'
      printf '[Icons]\nTheme=stale\n\n[KDE]\nLookAndFeelPackage=stale\n'
      awk -F '\t' '$1 != group { group = $1; printf "\n[%s]\n", group } { printf "%s=stale\n", $2 }' "$light_entries"
    '';
  };

  activationAssertions =
    entry: fixture:
    let
      data = entry.user.home.activation.kdeTheme.data or "";
      script = pkgs.writeText "${entry.name}-kde-theme.sh" data;
      label = "${entry.name}: after kdeTheme activation on the ${fixture} fixture,";
      home = "$TMPDIR/${entry.name}-${fixture}-home";
      userGlobals = "${home}/.config/kdeglobals";
      systemGlobals = "${entry.config.system.build.etc}/etc/xdg/kdeglobals";
      expectUser = group: key: expected: message: ''
        if [ "$(ini_effective "${userGlobals}" ${esc systemGlobals} ${esc group} ${esc key})" != ${expected} ]; then
          ${fail "${label} ${message}"}
        fi
      '';
    in
    ''
      if [ ! -s ${esc script} ]; then
        ${fail "${entry.name}: kdeTheme activation script is missing or empty"}
      else
        mkdir -p "${home}/.config"
        {
          ${fixtures.${fixture}}
        } > "${userGlobals}"
        if ! HOME="${home}" XDG_CONFIG_HOME="${home}/.config" \
          XDG_CONFIG_DIRS=${esc "${entry.config.system.build.etc}/etc/xdg"} \
          bash ${esc script} >/dev/null 2>&1; then
          ${fail "${label} the activation exited non-zero"}
        fi
        ${expectUser "General" "ColorScheme" "BreezeLight" "the user ColorScheme is not BreezeLight"}
        ${expectUser "KDE" "LookAndFeelPackage" "org.kde.breeze.desktop"
          "the user LookAndFeelPackage is not Breeze Light"
        }
        ${expectUser "Icons" "Theme" "breeze" "the user icon theme is not breeze"}
        expect_scheme ${esc "${label} the effective"} \
          ini_effective "${userGlobals}" ${esc systemGlobals}
        ${expectUser "General" "BrowserApplication" "fixture.desktop" "an unrelated user key was lost"}
      fi
    '';
in
pkgs.runCommand "kde-light-theme-tests"
  {
    nativeBuildInputs = [
      pkgs.gawk
      pkgs.gnugrep
    ];
  }
  ''
    ${configurations.guard}
    failed=0

    # Prints the first value of key in [group] of an INI file.
    ini_get() {
      awk -v group="[$2]" -v key="$3" '
        /^\[/ { in_group = ($0 == group); next }
        in_group && index($0, key "=") == 1 { print substr($0, length(key) + 2); exit }
      ' "$1"
    }

    # Succeeds when key is present in [group] of an INI file, even with an
    # empty value.
    ini_has() {
      awk -v group="[$2]" -v key="$3" '
        /^\[/ { in_group = ($0 == group); next }
        in_group && index($0, key "=") == 1 { found = 1; exit }
        END { exit !found }
      ' "$1"
    }

    # Prints what KConfig resolves: the user file's value, else the system one.
    # KConfig drops a user entry that equals the cascaded default, so a key
    # absent from the user file is not a missing write. An empty user value
    # still overrides the system one, so presence decides, not emptiness.
    ini_effective() {
      if ini_has "$1" "$3" "$4"; then
        ini_get "$1" "$3" "$4"
      else
        ini_get "$2" "$3" "$4"
      fi
    }

    # One "group<TAB>key<TAB>value" line per copied BreezeLight.colors entry;
    # a nested group keeps its inner brackets, as in "Colors:Header][Inactive".
    light_entries="$TMPDIR/light-entries"
    awk ${esc copiedGroups}'
      /^\[/ { group = substr($0, 2, length($0) - 2); next }
      keep && index($0, "=") > 1 {
        eq = index($0, "=")
        printf "%s\t%s\t%s\n", group, substr($0, 1, eq - 1), substr($0, eq + 1)
      }
    ' ${esc "${colorSchemes}/BreezeLight.colors"} > "$light_entries"
    if ! grep -q $'^WM\t' "$light_entries" || ! grep -q $'^Colors:Header\\]\\[Inactive\t' "$light_entries"; then
      ${fail "BreezeLight.colors yielded no [WM] or nested [Colors:Header][Inactive] entries"}
    fi

    # Fails once per light entry whose value, resolved by the given lookup
    # command and its file arguments, differs from the packaged one.
    expect_scheme() {
      label="$1"
      shift
      while IFS=$'\t' read -r group key value; do
        if [ "$("$@" "$group" "$key")" != "$value" ]; then
          echo "$label [$group] $key is not the Breeze Light value" >&2
          failed=1
        fi
      done < "$light_entries"
    }

    dark_window="$(ini_get ${esc "${colorSchemes}/BreezeDark.colors"} Colors:Window BackgroundNormal)"
    light_window="$(ini_get ${esc "${colorSchemes}/BreezeLight.colors"} Colors:Window BackgroundNormal)"
    if [ -z "$light_window" ] || [ "$dark_window" = "$light_window" ]; then
      ${fail "BreezeLight.colors does not carry a Window background distinct from BreezeDark.colors"}
    fi

    ${concatMapStringsSep "\n" etcAssertions configurations.entries}
    ${concatMapStringsSep "\n" (
      entry: concatMapStringsSep "\n" (activationAssertions entry) (attrNames fixtures)
    ) configurations.entries}

    if [ "$failed" -ne 0 ]; then
      exit 1
    fi
    touch $out
  ''
