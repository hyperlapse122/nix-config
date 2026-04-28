{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.laptop-input;
in {
  options.my.system.laptop-input = {
    enable = lib.mkEnableOption "노트북 입력 설정 (keyd 키 매핑 + libinput palm rejection 조정)";
  };

  config = lib.mkIf cfg.enable {
    # keyd — 시스템 레벨 키 리매핑 데몬.
    # 참고: https://wiki.nixos.org/wiki/Keyd
    #
    # extraConfig 가 아닌 settings 로 작성한 이유: Nix 안에서 평면 attrset 으로 표현 가능하면
    # extraConfig 문자열보다 evaluate 시점에 타이핑/머지 안전성이 더 높다.
    services.keyd = {
      enable = true;
      keyboards.default = {
        # 와일드카드 — 모든 키보드 대상.
        # Wiki 의 "Disabling Copilot key" 섹션은 palm rejection 이슈를 피하려고 ID 를 명시하라고 권하지만,
        # 아래 environment.etc."libinput/local-overrides.quirks" 로 동일한 문제를 해결하므로 와일드카드 사용 가능.
        ids = [ "*" ];
        settings = {
          # 기본 레이어
          main = {
            # CapsLock → Hangeul (한/영 전환). dotfiles/etc/keyd/default.conf 와 동일.
            capslock = "hangeul";
            # Copilot 키 비활성화 — 신형 노트북에 달리는 쓸모없는 Copilot 키를 meta 레이어로 매핑.
            # `sudo keyd monitor` 로 확인된 표준 시퀀스 (leftshift+leftmeta+f23) 를 잡아낸다.
            # 참고: https://wiki.nixos.org/wiki/Keyd#Disabling_Copilot_key
            "leftshift+leftmeta+f23" = "layer(meta)";
          };
          # Ctrl 레이어 — Ctrl 을 누른 상태에서 CapsLock 은 실제 CapsLock 동작.
          # main 의 capslock=hangeul 매핑을 우회해 필요할 때 진짜 CapsLock 을 쓸 수 있게 함.
          control = {
            capslock = "capslock";
          };
        };
      };
    };

    # libinput palm rejection 보정.
    # keyd 가 만든 가상 키보드를 internal 키보드로 인식시켜야 타이핑 중 터치패드 palm rejection 이 동작한다.
    # 미설정 시 키 입력이 들어오는 동안에도 터치패드가 활성 상태로 남아 오타/오클릭 발생.
    # 참고: https://github.com/rvaiya/keyd/issues/723
    environment.etc."libinput/local-overrides.quirks".text = ''
      [Serial Keyboards]
      MatchUdevType=keyboard
      MatchName=keyd virtual keyboard
      AttrKeyboardIntegration=internal
    '';
  };
}
