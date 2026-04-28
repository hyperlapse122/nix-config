{ config, lib, pkgs, ... }:
let
  cfg = config.my.i18n.fcitx5;
in {
  options.my.i18n.fcitx5 = {
    enable = lib.mkEnableOption "fcitx5 입력기 (한국어 / Wayland frontend)";
  };

  config = lib.mkIf cfg.enable {
    # 한국어 입력
    # NOTE: home-manager의 i18n.inputMethod는 시스템 레벨이 아닌 사용자 레벨에서
    #       fcitx5-daemon 을 systemd user unit 으로 띄운다.
    #       waylandFrontend = true 일 때 HM은 GTK_IM_MODULE / QT_IM_MODULE 를
    #       설정하지 않으므로 호스트에서 별도로 비울 필요가 없다.
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        addons = with pkgs; [
          fcitx5-hangul
          qt6Packages.fcitx5-configtool
        ];
        # Wayland frontend 사용 (KDE Plasma 6 권장)
        waylandFrontend = true;
      };
    };
  };
}
