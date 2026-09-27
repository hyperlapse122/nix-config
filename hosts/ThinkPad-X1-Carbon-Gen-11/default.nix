{ ... }:
{
  imports = [
    ./hardware.nix
    ./disko.nix
    ../../modules/nixos/profile.nix
  ];
  networking.hostName = "ThinkPad-X1-Carbon-Gen-11";
  my.keyd.enable = true;
  my.fingerprint.enable = true;
  my.thunderbolt.enable = true;
  my.laptop.enable = true;
}
