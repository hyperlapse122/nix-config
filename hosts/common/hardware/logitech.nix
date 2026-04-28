{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.hardware.logitech;
in {
  options.my.system.hardware.logitech = {
    enable = lib.mkEnableOption "Logitech Unifying/Bolt 리시버 udev 룰 (USB autosuspend 중 wakeup 비활성)";
  };

  config = lib.mkIf cfg.enable {
    # Logitech Unifying Receiver (idProduct=c52b) / Bolt Receiver (idProduct=c548) 의
    # `power/wakeup` 속성을 disabled 로 박아 USB autosuspend 상태에서 호스트가 마우스/키보드
    # 입력으로 자동 wake 되는 동작을 차단.
    # 가방 안에서 마우스 휠/버튼 충돌로 노트북이 깨어나는 것 같은 의도치 않은 슬립 해제 방지가 목적.
    #
    # 출처: dotfiles/etc/udev/rules.d/logitech-receiver.rules (그대로 포팅).
    # idVendor 046d = Logitech.
    # idProduct: c52b = Unifying Receiver, c548 = Bolt Receiver.
    # `|` 는 systemd udev 매처의 OR 구분자 (systemd 240+).
    #
    # services.udev.extraRules 는 /etc/udev/rules.d/99-local.rules 로 머지되어 들어간다.
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="usb", DRIVERS=="usb", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c52b|c548", ATTR{power/wakeup}="disabled"
    '';
  };
}
