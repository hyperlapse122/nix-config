{ pkgs, ... }:
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = true;
  nixpkgs.config.allowUnfree = true;
  networking.hostName = "ThinkPad-X1-Carbon-Gen-11";
  networking.networkmanager.enable = true;
  time.timeZone = "Asia/Seoul";
  i18n.defaultLocale = "ko_KR.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ko_KR.UTF-8";
    LC_IDENTIFICATION = "ko_KR.UTF-8";
    LC_MEASUREMENT = "ko_KR.UTF-8";
    LC_MONETARY = "ko_KR.UTF-8";
    LC_NAME = "ko_KR.UTF-8";
    LC_NUMERIC = "ko_KR.UTF-8";
    LC_PAPER = "ko_KR.UTF-8";
    LC_TELEPHONE = "ko_KR.UTF-8";
    LC_TIME = "ko_KR.UTF-8";
  };
  users.users.h82 = {
    isNormalUser = true;
    description = "Joosung Park";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true;
  services.pcscd.enable = true;
  environment.systemPackages =
    with pkgs;
    [
      git
      age
      sops
      gnupg
      dmidecode
      sbctl
      cryptsetup
    ]
    ++ [ (import ../../packages/gpg-tools.nix { inherit pkgs; }).restoreAgeIdentity ];
  system.stateVersion = "26.05";
}
