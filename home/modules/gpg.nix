{ config, lib, pkgs, ... }:
let
  cfg = config.my.gpg;

  # 1Password 에 보관된 GPG private key 를 로컬 keyring 으로 가져오는 일회성 스크립트.
  # 새 호스트 부트스트랩 시 한 번만 수동으로 실행하면 됨 — declarative 가 아니라 obtain-once 성격.
  # 1Password 데스크톱 앱이 떠 있어야 하고 (biometric/password unlock GUI 필요),
  # gpg --batch --import 은 비대화형이므로 stdin 의 키 데이터만 받아 곧장 keyring 에 넣는다.
  importGpgKeys = pkgs.writeShellApplication {
    name = "import-gpg-keys";
    runtimeInputs = [ pkgs._1password-cli pkgs.gnupg ];
    text = ''
      op read "op://tjlmijoc5qxj6vypdnvxf6s2sq/gmwqu34rldszc6qtas2i3ejiaq/gpg_private.asc" | gpg --batch --import
    '';
  };
in {
  options.my.gpg = {
    enable = lib.mkEnableOption "GnuPG + gpg-agent (pinentry-qt)";
  };

  config = lib.mkIf cfg.enable {
    programs.gpg = {
      enable = true;
    };

    # gpg-agent: 사용자 systemd unit 으로 실행되며 pinentry 로 패스프레이즈를 받는다.
    # NOTE: pinentry-qt 는 Qt6 기반이라 KDE Plasma / Wayland 환경에 맞다.
    #       다른 데스크톱 환경을 쓰는 호스트가 생기면 그 때 옵션을 늘릴 것.
    services.gpg-agent = {
      enable = true;
      pinentry.package = pkgs.pinentry-qt;
    };

    home.packages = [ importGpgKeys ];
  };
}
