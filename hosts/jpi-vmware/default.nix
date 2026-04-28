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
  networking.hostName = "jpi-vmware";
  networking.networkmanager.enable = true;

  # 시간/지역
  time.timeZone = "Asia/Seoul";
  i18n.defaultLocale = "ko_KR.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "ko_KR.UTF-8";
    LC_MONETARY = "ko_KR.UTF-8";
  };

  # 한국어 입력 (fcitx5) 은 home-manager 모듈에서 관리: home/modules/i18n/fcitx5.nix

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

  # 1Password (GUI + CLI)
  # 브라우저 통합용 setuid wrapper 가 필요해서 NixOS 레벨에서 활성화해야 한다.
  # 단순히 환경 패키지로 깔면 브라우저 확장과의 코드 서명 검증이 동작하지 않음.
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "h82" ];
  };

  # Flakes 정식 활성화
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Unfree 패키지 허용
  nixpkgs.config.allowUnfree = true;

  # nix-vscode-extensions overlay (호스트 pkgs에 적용해야 allowUnfree가 전파됨)
  nixpkgs.overlays = [ inputs.nix-vscode-extensions.overlays.default ];

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
