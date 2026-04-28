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
        # 입력기 전환 키: 한국어 키보드의 Hangul 키 단독 사용
        # ~/.config/fcitx5/config 로 INI 직렬화 됨. TriggerKeys 는 key-list 라
        # [Hotkey/TriggerKeys] 섹션 + 숫자 인덱스 엔트리 형식으로 작성한다.
        # 단일 전용 키만 트리거로 쓰므로 modifier-cycle (EnumerateWithTriggerKeys) 은 끈다.
        settings.globalOptions = {
          Hotkey = {
            EnumerateWithTriggerKeys = false;
          };
          "Hotkey/TriggerKeys" = {
            "0" = "Hangul";
          };
        };
      };
    };
  };
}
