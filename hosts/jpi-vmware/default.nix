{ config, pkgs, lib, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  # 부트로더 (BIOS/Legacy)
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
    useOSProber = false;
  };

  # 호스트명
  networking.hostName = "h82-vmware";
  networking.networkmanager.enable = true;

  # 시간/지역
  time.timeZone = "Asia/Seoul";
  i18n.defaultLocale = "ko_KR.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "ko_KR.UTF-8";
    LC_MONETARY = "ko_KR.UTF-8";
  };

  # 한국어 입력
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-hangul
      qt6Packages.fcitx5-configtool
    ];
  };

  # D-Bus
  services.dbus.enable = true;

  # KDE Plasma 6
  services.xserver.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;
  services.displayManager.defaultSession = "plasma";

  # KDE Wallet
  security.pam.services.login.kwallet.enable = true;
  security.pam.services.kde.kwallet.enable = true;

  # 사운드
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # VMware guest 지원
  virtualisation.vmware.guest.enable = true;

  # 사용자
  users.users.h82 = {
    isNormalUser = true;
    description = "H82";
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;

  # 외부 바이너리 호환 (mise 등을 위해)
  programs.nix-ld.enable = true;

  # Flakes 정식 활성화
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # 시스템 패키지 (최소한만)
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    htop
  ];

  # SSH (VM에 원격 접속 시 편리)
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "no";
  };

  # state version - 절대 임의로 바꾸지 말 것
  system.stateVersion = "25.11";
}
