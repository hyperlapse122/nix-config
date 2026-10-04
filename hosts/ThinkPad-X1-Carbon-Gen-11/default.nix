{ ... }:
{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];
  my.keyd.enable = true;
  my.fingerprint.enable = true;
  my.thunderbolt.enable = true;
  my.laptop.enable = true;
  my.t3.cli.enable = true;
  my.t3.desktop.enable = true;
}
