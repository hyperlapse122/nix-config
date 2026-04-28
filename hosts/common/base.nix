{ config, lib, pkgs, ... }:
{
  # Flakes 정식 활성화 — 이 repo 자체가 flake 기반이므로 모든 호스트에서 필수
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Unfree 패키지 허용 (h82 의 정책: 모든 호스트에서 unfree 허용)
  nixpkgs.config.allowUnfree = true;

  # D-Bus — desktop / polkit / fcitx5 등이 의존하므로 명시적으로 활성화
  services.dbus.enable = true;

  # 시스템 패키지 (최소한만)
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    htop
  ];
}
