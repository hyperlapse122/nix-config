{ pkgs, ... }:
{
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;

  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "h82" ];
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-hangul
        fcitx5-gtk
        kdePackages.fcitx5-qt
      ];
      settings = {
        inputMethod = {
          "Groups/0" = {
            Name = "기본값";
            "Default Layout" = "us";
            DefaultIM = "hangul";
          };
          "Groups/0/Items/0" = {
            Name = "keyboard-us";
            Layout = "";
          };
          "Groups/0/Items/1" = {
            Name = "hangul";
            Layout = "";
          };
          GroupOrder = {
            "0" = "기본값";
          };
        };
        globalOptions = {
          "Hotkey/TriggerKeys" = {
            "0" = "Hangul";
          };
          "Hotkey/EnumerateGroupForwardKeys" = {
            "0" = "Super+space";
          };
        };
        addons = {
          hangul = {
            globalSection = {
              Keyboard = "Dubeolsik";
            };
            sections = {
              HanjaModeToggleKey = {
                "0" = "Hangul_Hanja";
                "1" = "F9";
              };
            };
          };
        };
      };
    };
  };

  environment.etc."xdg/kwinrc".text = ''
    [Wayland]
    InputMethod=/run/current-system/sw/share/applications/fcitx5-wayland-launcher.desktop
  '';

  environment.etc."xdg/plasma-localerc".text = ''
    [Translations]
    LANGUAGE=ko:en_US
  '';

  environment.etc."xdg/kdeglobals".text = ''
    [Locale]
    Language=ko:en_US
  '';
}
