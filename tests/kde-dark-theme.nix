/*
  Check interface:

    import ./tests/kde-dark-theme.nix { inherit pkgs self; }

  Asserts that Plasma defaults to Breeze Dark, both as the system-wide KDE
  default and for h82's own kdeglobals.

  Verifies, on every configuration `tests/lib/configurations.nix` yields,
  production and bootstrap alike, by reading the materialised
  /etc/xdg/kdeglobals rather than the option that renders it:
  - [KDE] LookAndFeelPackage is org.kde.breezedark.desktop.
  - [General] ColorScheme is BreezeDark.
  - [Icons] Theme is breeze-dark.
  - [Colors:Window] BackgroundNormal equals the value in the packaged
    BreezeDark.colors. KColorScheme falls back to built-in light colors when
    the groups are absent, so the scheme name alone would leave Qt apps light.
    The expected value is also checked to differ from BreezeLight.colors, so a
    light scheme cannot pass.
  - the existing TerminalApplication and Locale entries survive.

  Verifies, on every configuration as well (home/h82/desktop/kde/theme.nix is
  not gated on my.bootstrap, so the bootstrap desktop is dark too), by running
  the kdeTheme Home Manager activation against a fixture HOME whose kdeglobals
  holds the Breeze Light color groups, scheme name, look-and-feel package, and
  icon theme (the shape of a long-lived user file), with the built /etc/xdg in
  XDG_CONFIG_DIRS. Seeding light values keeps the system defaults from
  masking a missing write:
  - the effective (user, else system) values are ColorScheme BreezeDark, the Breeze Dark
    look-and-feel package, and the breeze-dark icon theme.
  - the effective [Colors:Window] and nested [Colors:Header][Inactive] backgrounds equal
    the Breeze Dark values. The user file's own groups override /etc/xdg, and
    plasma-apply-colorscheme reads the cascaded ColorScheme=BreezeDark as
    already applied and writes nothing, so only a direct write turns h82 dark.
  - an unrelated user key survives.

  It cannot see whether a running session repaints; docs/verification.md
  carries the hardware check for that. Every failure is collected in one build.
*/
{ pkgs, self }:
let
  inherit (pkgs.lib) concatMapStringsSep escapeShellArg;

  configurations = import ./lib/configurations.nix { inherit pkgs self; };

  esc = value: escapeShellArg (toString value);

  colorSchemes = "${pkgs.kdePackages.breeze}/share/color-schemes";

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
        ${expectKey "KDE" "LookAndFeelPackage" "org.kde.breezedark.desktop"}
        ${expectKey "General" "ColorScheme" "BreezeDark"}
        ${expectKey "Icons" "Theme" "breeze-dark"}
        ${expectKey "General" "TerminalApplication" "ghostty"}
        ${expectKey "Locale" "Language" "ko:en_US"}
        if [ "$(ini_get ${esc kdeglobals} Colors:Window BackgroundNormal)" != "$dark_window" ]; then
          ${fail "${entry.name}: /etc/xdg/kdeglobals [Colors:Window] BackgroundNormal is not the Breeze Dark value"}
        fi
      fi
    '';

  activationAssertions =
    entry:
    let
      data = entry.user.home.activation.kdeTheme.data or "";
      script = pkgs.writeText "${entry.name}-kde-theme.sh" data;
      home = "$TMPDIR/${entry.name}-home";
      userGlobals = "${home}/.config/kdeglobals";
      systemGlobals = "${entry.config.system.build.etc}/etc/xdg/kdeglobals";
      expectUser = group: key: expected: message: ''
        if [ "$(ini_effective "${userGlobals}" ${esc systemGlobals} ${esc group} ${esc key})" != ${expected} ]; then
          ${fail "${entry.name}: after kdeTheme activation, ${message}"}
        fi
      '';
    in
    ''
      if [ ! -s ${esc script} ]; then
        ${fail "${entry.name}: kdeTheme activation script is missing or empty"}
      else
        mkdir -p "${home}/.config"
        {
          printf '[General]\nBrowserApplication=fixture.desktop\nColorScheme=BreezeLight\n\n'
          printf '[Icons]\nTheme=breeze\n\n[KDE]\nLookAndFeelPackage=org.kde.breeze.desktop\n\n'
          awk '/^\[/ { keep = ($0 ~ /^\[Colors:/) } keep { print }' ${esc "${colorSchemes}/BreezeLight.colors"}
        } > "${userGlobals}"
        if ! HOME="${home}" XDG_CONFIG_HOME="${home}/.config" \
          XDG_CONFIG_DIRS=${esc "${entry.config.system.build.etc}/etc/xdg"} \
          bash ${esc script} >/dev/null 2>&1; then
          ${fail "${entry.name}: kdeTheme activation exited non-zero"}
        fi
        ${expectUser "General" "ColorScheme" "BreezeDark" "the user ColorScheme is not BreezeDark"}
        ${expectUser "KDE" "LookAndFeelPackage" "org.kde.breezedark.desktop"
          "the user LookAndFeelPackage is not Breeze Dark"
        }
        ${expectUser "Icons" "Theme" "breeze-dark" "the user icon theme is not breeze-dark"}
        ${expectUser "Colors:Window" "BackgroundNormal" "\"$dark_window\""
          "the user [Colors:Window] background is not the Breeze Dark value"
        }
        ${expectUser "Colors:Header][Inactive" "BackgroundNormal" "\"$dark_header_inactive\""
          "the user [Colors:Header][Inactive] background is not the Breeze Dark value"
        }
        ${expectUser "General" "BrowserApplication" "fixture.desktop" "an unrelated user key was lost"}
      fi
    '';
in
pkgs.runCommand "kde-dark-theme-tests"
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

    # Prints what KConfig resolves: the user file's value, else the system one.
    # KConfig drops a user entry that equals the cascaded default, so a key
    # absent from the user file is not a missing write.
    ini_effective() {
      if grep -qxF "[$3]" "$1" && [ -n "$(ini_get "$1" "$3" "$4")" ]; then
        ini_get "$1" "$3" "$4"
      else
        ini_get "$2" "$3" "$4"
      fi
    }

    dark_header_inactive="$(ini_get ${esc "${colorSchemes}/BreezeDark.colors"} "Colors:Header][Inactive" BackgroundNormal)"
    dark_window="$(ini_get ${esc "${colorSchemes}/BreezeDark.colors"} Colors:Window BackgroundNormal)"
    light_window="$(ini_get ${esc "${colorSchemes}/BreezeLight.colors"} Colors:Window BackgroundNormal)"
    if [ -z "$dark_window" ] || [ "$dark_window" = "$light_window" ]; then
      ${fail "BreezeDark.colors does not carry a Window background distinct from BreezeLight.colors"}
    fi

    ${concatMapStringsSep "\n" etcAssertions configurations.entries}
    ${concatMapStringsSep "\n" activationAssertions configurations.entries}

    if [ "$failed" -ne 0 ]; then
      exit 1
    fi
    touch $out
  ''
