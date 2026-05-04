{ pkgs, ... }:
{
  nix.settings = {
    # Enable Flakes officially — this repo is flake-based, so it's required on every host
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  # Remove old generations weekly to keep the Nix store from growing indefinitely.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

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
