{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.plasma;
in {
  options.my.desktop.plasma = {
    enable = lib.mkEnableOption "KDE Plasma desktop configuration (plasma-manager)";

    # Idle screen auto-lock (idle-timer based).
    # Default true preserves Plasma's stock behavior (lock on idle).
    # To disable per host, set in that host's default.nix:
    #   home-manager.users.h82.my.desktop.plasma.autoLock.enable = false;
    # NOTE: This toggle only disables idle lock (kscreenlockerrc [Daemon] Autolock).
    #       Lock-on-resume from suspend (LockOnResume) is a separate setting and is
    #       intentionally left at its secure default (true).
    autoLock.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether KDE Screen Locker auto-locks the screen after the idle timeout.
        Default true preserves Plasma's stock behavior. Disable per host via
        `home-manager.users.h82.my.desktop.plasma.autoLock.enable = false;` in
        the host's `default.nix`. Lock-on-resume from suspend is governed by a
        separate setting and is intentionally left at Plasma's default (locked).
      '';
    };

    # Display auto-off (DPMS — PowerDevil's turnOffDisplay).
    # Default true preserves Plasma's stock DPMS behavior.
    # To disable per host, set in that host's default.nix:
    #   home-manager.users.h82.my.desktop.plasma.screenOff.enable = false;
    # NOTE: When false, sets turnOffDisplay.idleTimeout to "never" for AC, battery,
    #       and lowBattery profiles (mapped internally to -1 in powerdevilrc).
    #       Display dimming is a separate setting and is not affected — disable
    #       it separately if needed.
    screenOff.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether the display turns off when idle (DPMS via PowerDevil's
        `turnOffDisplay`). Default true preserves Plasma's stock behavior.
        Disable per host via
        `home-manager.users.h82.my.desktop.plasma.screenOff.enable = false;` in
        the host's `default.nix`. When disabled, sets the idle timeout to
        `"never"` for AC, battery, and lowBattery profiles. Display dimming is
        a separate setting and is not touched.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.plasma = {
      enable = true;

      # Idle screen lock — only emit `false` on hosts that disabled the autoLock toggle.
      # plasma-manager's autoLock option is `nullOr bool`, so when null (= option not defined)
      # no key is written to kscreenlockerrc and Plasma's default (lock on idle) applies.
      # Hence, on hosts where the toggle is on, lib.mkIf leaves the option undefined and
      # the default behavior is preserved.
      kscreenlocker.autoLock = lib.mkIf (!cfg.autoLock.enable) false;

      # Display auto-off (DPMS) — set every profile to "never" on hosts where screenOff is disabled.
      # plasma-manager's `turnOffDisplay.idleTimeout` is `enum ["never"] | ints.between 30 600000`,
      # and "never" maps to -1 in powerdevilrc (see modules/powerdevil.nix `apply`).
      # NOTE: Desktops/VMs (e.g. VMware guests) have no battery / lowBattery state, but plasma-manager
      #       always writes all three profiles to powerdevilrc, so we set all three — PowerDevil simply
      #       never enters those states, so it's harmless. On laptops, "never" across the board is also
      #       the consistent natural choice.
      # NOTE: Do NOT set idleTimeoutWhenLocked alongside this — plasma-manager's createAssertions
      #       (modules/powerdevil.nix) fails when "never" is combined with it. Leave it as null.
      powerdevil.AC.turnOffDisplay.idleTimeout = lib.mkIf (!cfg.screenOff.enable) "never";
      powerdevil.battery.turnOffDisplay.idleTimeout = lib.mkIf (!cfg.screenOff.enable) "never";
      powerdevil.lowBattery.turnOffDisplay.idleTimeout = lib.mkIf (!cfg.screenOff.enable) "never";

      # Default fonts (UI / fixed-width).
      # NOTE: The family string must match the fontconfig-registered name exactly.
      #       In particular, "JetBrainsMono Nerd Font" has NO space inside "JetBrainsMono".
      fonts = {
        general = {
          family = "Pretendard";
          pointSize = 10;
        };
        fixedWidth = {
          family = "JetBrainsMono Nerd Font";
          pointSize = 10;
        };
        small = {
          family = "Pretendard";
          pointSize = 8;
        };
        toolbar = {
          family = "Pretendard";
          pointSize = 10;
        };
        menu = {
          family = "Pretendard";
          pointSize = 10;
        };
        windowTitle = {
          family = "Pretendard";
          pointSize = 10;
        };
      };

      # Bottom panel (taskbar): Plasma 6 standard widget set + commonly-used app pins.
      # NOTE: Declaring `programs.plasma.panels` REPLACES Plasma's default panel layout
      #       wholesale. There is no way to keep the default panel and just add launchers,
      #       so all standard widgets (kickoff / pager / icontasks / systemtray /
      #       digitalclock / showdesktop) must be enumerated for a normal taskbar.
      #       (See: nix-community/plasma-manager modules/panels.nix)
      # NOTE: The `iconTasks` helper produces `org.kde.plasma.icontasks` by default
      #       (Plasma 6 default — icons-only task manager). For the classic task manager
      #       with text labels (`org.kde.plasma.taskmanager`), set `iconsOnly = false`.
      # NOTE: Launcher URI format is `applications:<id>.desktop` — KDE's standard .desktop
      #       reference. The id must match the actually-installed .desktop filename
      #       exactly. Pin order: file manager → terminal → browser → editor (grouped by
      #       usage frequency / category).
      #         - Dolphin: org.kde.dolphin.desktop   (bundled with the Plasma 6 desktop manager)
      #         - Konsole: org.kde.konsole.desktop   (bundled with the Plasma 6 desktop manager)
      #         - Chrome:  google-chrome.desktop     (provided by pkgs.google-chrome)
      #         - VS Code: code.desktop              (provided by pkgs.vscode)
      #         - Zed:     dev.zed.Zed.desktop       (provided by pkgs.zed-editor)
      panels = [
        {
          location = "bottom";
          # Floating panel — the Plasma 6 default style (a panel that floats slightly away
          # from the screen edge with a margin around it).
          # NOTE: plasma-manager's `floating` is a bool option (modules/panels.nix). The value
          #       `location = "floating"` exists in the enum too, but that's a separate option
          #       making the position itself freely placeable — don't confuse the two; the
          #       "bottom but floating" behavior we want is enabled solely by this flag.
          # NOTE: Related options like lengthMode / alignment all use plasma-manager's defaults —
          #       i.e. Plasma 6's standard floating-panel behavior (fit-length / center-aligned).
          floating = true;
          widgets = [
            "org.kde.plasma.kickoff"
            "org.kde.plasma.pager"
            {
              iconTasks = {
                launchers = [
                  "applications:google-chrome.desktop"
                  "applications:org.kde.dolphin.desktop"
                  "applications:org.kde.konsole.desktop"
                  "applications:code.desktop"
                  "applications:dev.zed.Zed.desktop"
                ];
              };
            }
            "org.kde.plasma.marginsseparator"
            "org.kde.plasma.systemtray"
            "org.kde.plasma.digitalclock"
            "org.kde.plasma.showdesktop"
          ];
        }
      ];

      # Force the panel layout to be re-applied at every Plasma session start.
      # NOTE: plasma-manager generates a desktop script run once at KWin startup based on
      #       the `panels` declaration. With the default (`runAlways = false`) it runs only
      #       once, so if the user moves widgets in the GUI or removes pins, those changes
      #       persist until next boot. `runAlways = true` re-executes that desktop script
      #       at every session start, restoring the `panels = [ ... ]` declaration as the
      #       authoritative state — i.e. the Konsole / VS Code / Zed pins above are always
      #       restored.
      #       (See: nix-community/plasma-manager modules/startup.nix runAlways option)
      # NOTE: This toggle affects ONLY the panel. To overwrite Plasma's other settings
      #       (themes, shortcuts, KWin rules) on every home-manager activation, you'd need
      #       to add `programs.plasma.overrideConfig = true;` separately — but use that
      #       cautiously, as it deletes a wide range of GUI-modified config files.
      startup.desktopScript."panels".runAlways = true;

      configFile = {
        # Enable KWin Wayland virtual keyboard and select fcitx5
        # NOTE: Since fcitx5 was moved to a home-manager module, point at the
        #       fcitx5-with-addons package's store path directly instead of the
        #       system profile path (/run/current-system/sw/...). HM's
        #       i18n.inputMethod.fcitx5 default package is
        #       pkgs.qt6Packages.fcitx5-with-addons, which matches.
        "kwinrc"."Wayland" = {
          InputMethod = {
            value = "${pkgs.qt6Packages.fcitx5-with-addons}/share/applications/fcitx5-wayland-launcher.desktop";
            immutable = true;
          };
          VirtualKeyboardEnabled = true;
        };

        # Touchpad natural scroll — default for every touchpad
        # NOTE: On Plasma 6 Wayland, KWin's libinput backend treats kcminputrc's
        #       [Libinput][Defaults][Touchpad] group as the per-device fallback
        #       (= default). This single line therefore applies natural scroll to
        #       every touchpad attached to the host — no need to write per-vendor /
        #       per-product / per-device-name keys.
        #       (See: KDE/kwin src/backends/libinput/device.{h,cpp} m_defaultConfig)
        # NOTE: The legacy ~/.config/touchpadrc ([libinput] naturalScroll=true) is a
        #       Plasma 5 → 6 migration-only file (KDE/plasma-desktop
        #       kcms/touchpad/kded/kded.cpp); KWin on Plasma 6 Wayland no longer
        #       reads it. That's why the dotfile's touchpadrc isn't ported as-is and
        #       we write to kcminputrc's Defaults group instead.
        # NOTE: KConfig's nested groups [A][B][C] are expressed in plasma-manager
        #       configFile as a single attribute key "A/B/C" — write_config.py splits
        #       on `/` and serializes as [A][B][C]. The configFile schema is fixed at
        #       attrsOf × 3 (file → group → key), so deeply nested attrsets (e.g.
        #       Libinput.Defaults.Touchpad.NaturalScroll) are rejected by the type
        #       checker.
        "kcminputrc"."Libinput/Defaults/Touchpad" = {
          NaturalScroll = true;
        };

        # Global theme: Automatic (switches Breeze ↔ Breeze Dark by day/night)
        # NOTE: plasma-manager's `workspace.lookAndFeel` only accepts concrete package
        #       IDs (org.kde.breeze.desktop / org.kde.breezedark.desktop), so it cannot
        #       directly express "Automatic". On Plasma 6, "Automatic" is not a
        #       lookAndFeel package but a boolean in kdeglobals' [KDE] section
        #       (`AutomaticLookAndFeel=true`); the day/night themes are stored
        #       separately as `DefaultLightLookAndFeel` / `DefaultDarkLookAndFeel`.
        #       (See: KDE/plasma-workspace kcms/lookandfeel/lookandfeelsettings.kcfg)
        "kdeglobals"."KDE" = {
          AutomaticLookAndFeel = true;
          DefaultLightLookAndFeel = "org.kde.breeze.desktop";
          DefaultDarkLookAndFeel = "org.kde.breezedark.desktop";
        };

        # Disable session restore: start with an empty session at login
        # NOTE: ksmserverrc's [General] loginMode determines session-start policy.
        #       - "default"             : restore previous session (Plasma default)
        #       - "restoreSavedSession" : restore manually-saved session
        #       - "emptySession"        : always start with an empty session  (← what we want)
        #       (See: KDE/plasma-workspace ksmserver/server.cpp, kcms/session)
        "ksmserverrc"."General" = {
          loginMode = "emptySession";
        };
      };
    };
  };
}
