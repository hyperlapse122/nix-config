{ config, lib, pkgs, pkgs-unstable, ... }:
let
  cfg = config.my.system.programs._1password;
in {
  options.my.system.programs._1password = {
    enable = lib.mkEnableOption "1Password (CLI + GUI, 브라우저 통합 포함)";
  };

  config = lib.mkIf cfg.enable {
    # 1Password (GUI + CLI)
    # 브라우저 통합용 setuid wrapper 가 필요해서 NixOS 레벨에서 활성화해야 한다.
    # 단순히 환경 패키지로 깔면 브라우저 확장과의 코드 서명 검증이 동작하지 않음.
    # 패키지는 nixos-unstable 에서 가져옴 — 1Password 는 잦은 보안/기능 업데이트가 필요.
    programs._1password = {
      enable = true;
      package = pkgs-unstable._1password-cli;
    };
    programs._1password-gui = {
      enable = true;
      package = pkgs-unstable._1password-gui;
      # 단일 사용자 (h82) 가정 — git.nix 의 git identity 와 동일한 hard-code 정책.
      # 두 번째 사용자가 추가될 때 parameterize.
      polkitPolicyOwners = [ "h82" ];
    };
  };
}
