{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Enable Flakes officially — this repo is flake-based, so it's required on every host
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Allow unfree packages (h82's policy: allow unfree on every host)
  nixpkgs.config.allowUnfree = true;

  # D-Bus — required by desktop / polkit / fcitx5 / etc., so enable explicitly
  services.dbus.enable = true;

  # System packages (minimal only)
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    htop
    openssl
  ];
}
