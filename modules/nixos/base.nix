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
  i18n.defaultLocale = "en_US.UTF-8";
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
