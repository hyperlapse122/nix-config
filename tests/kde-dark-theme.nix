/*
  Check interface:

    import ./tests/kde-dark-theme.nix { inherit pkgs self; }

  Asserts that Plasma defaults to Breeze Dark, both as the system-wide KDE
  default and for h82's own kdeglobals.

  Verifies, on all four configurations, by reading the materialised
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

  Verifies, on ThinkPad-X1-Carbon-Gen-11 and MS-7D91, in the kdeTheme
  Home Manager activation script:
  - kwriteconfig6 writes LookAndFeelPackage and the icon theme.
  - plasma-apply-colorscheme BreezeDark runs on the offscreen Qt platform,
    since it aborts with no display, and its failure does not abort
    activation.
  - kwriteconfig6 does not write ColorScheme: plasma-apply-colorscheme exits
    without writing the color groups when the name already matches.

  It cannot see whether a running session repaints; docs/verification.md
  carries the hardware check for that. Every failure is collected in one build.
*/
{ pkgs, self }:
let
  inherit (pkgs.lib) concatStringsSep escapeShellArg;

  esc = value: escapeShellArg (toString value);

  colorSchemes = "${pkgs.kdePackages.breeze}/share/color-schemes";

  fail = message: ''
    echo ${esc message} >&2
    failed=1
  '';

  etcAssertions =
    hostName: host:
    let
      kdeglobals = "${host.config.system.build.etc}/etc/xdg/kdeglobals";
      expectKey = group: key: value: ''
        if [ "$(ini_get ${esc kdeglobals} ${esc group} ${esc key})" != ${esc value} ]; then
          ${fail "${hostName}: /etc/xdg/kdeglobals [${group}] ${key} is not ${value}"}
        fi
      '';
    in
    ''
      if [ ! -f ${esc kdeglobals} ]; then
        ${fail "${hostName}: /etc/xdg/kdeglobals is missing"}
      else
        ${expectKey "KDE" "LookAndFeelPackage" "org.kde.breezedark.desktop"}
        ${expectKey "General" "ColorScheme" "BreezeDark"}
        ${expectKey "Icons" "Theme" "breeze-dark"}
        ${expectKey "General" "TerminalApplication" "ghostty"}
        ${expectKey "Locale" "Language" "ko:en_US"}
        if [ "$(ini_get ${esc kdeglobals} Colors:Window BackgroundNormal)" != "$dark_window" ]; then
          ${fail "${hostName}: /etc/xdg/kdeglobals [Colors:Window] BackgroundNormal is not the Breeze Dark value"}
        fi
      fi
    '';

  activationAssertions =
    hostName: host:
    let
      data = host.config.home-manager.users.h82.home.activation.kdeTheme.data or "";
      script = pkgs.writeText "${hostName}-kde-theme.sh" data;
      expectLine = pattern: message: ''
        if ! grep -Eq -- ${esc pattern} ${esc script}; then
          ${fail "${hostName}: kdeTheme activation ${message}"}
        fi
      '';
    in
    ''
      if [ ! -s ${esc script} ]; then
        ${fail "${hostName}: kdeTheme activation script is missing or empty"}
      else
        ${expectLine "--file kdeglobals --group KDE --key LookAndFeelPackage org\\.kde\\.breezedark\\.desktop" "does not write LookAndFeelPackage"}
        ${expectLine "--file kdeglobals --group Icons --key Theme breeze-dark" "does not write the breeze-dark icon theme"}
        ${expectLine "QT_QPA_PLATFORM=offscreen [^ ]*/bin/plasma-apply-colorscheme BreezeDark( .*)?\\|\\| true" "does not run plasma-apply-colorscheme BreezeDark offscreen and tolerated"}
        if grep -Eq -- '--key ColorScheme' ${esc script}; then
          ${fail "${hostName}: kdeTheme activation writes ColorScheme with kwriteconfig6, which makes plasma-apply-colorscheme a no-op"}
        fi
      fi
    '';

  allHosts = {
    inherit (self.nixosConfigurations)
      ThinkPad-X1-Carbon-Gen-11
      ThinkPad-X1-Carbon-Gen-11-bootstrap
      MS-7D91
      MS-7D91-bootstrap
      ;
  };

  productionHosts = {
    inherit (self.nixosConfigurations) ThinkPad-X1-Carbon-Gen-11 MS-7D91;
  };
in
pkgs.runCommand "kde-dark-theme-tests"
  {
    nativeBuildInputs = [
      pkgs.gawk
      pkgs.gnugrep
    ];
  }
  ''
    failed=0

    # Prints the first value of key in [group] of an INI file.
    ini_get() {
      awk -v group="[$2]" -v key="$3" '
        /^\[/ { in_group = ($0 == group); next }
        in_group && index($0, key "=") == 1 { print substr($0, length(key) + 2); exit }
      ' "$1"
    }

    dark_window="$(ini_get ${esc "${colorSchemes}/BreezeDark.colors"} Colors:Window BackgroundNormal)"
    light_window="$(ini_get ${esc "${colorSchemes}/BreezeLight.colors"} Colors:Window BackgroundNormal)"
    if [ -z "$dark_window" ] || [ "$dark_window" = "$light_window" ]; then
      ${fail "BreezeDark.colors does not carry a Window background distinct from BreezeLight.colors"}
    fi

    ${concatStringsSep "\n" (pkgs.lib.mapAttrsToList etcAssertions allHosts)}
    ${concatStringsSep "\n" (pkgs.lib.mapAttrsToList activationAssertions productionHosts)}

    if [ "$failed" -ne 0 ]; then
      exit 1
    fi
    touch $out
  ''
