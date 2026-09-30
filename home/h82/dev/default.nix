{ lib, hostKind, ... }:
{
  imports = [
    ./android.nix
    ./containers.nix
    ./cpp.nix
    ./ghq.nix
    ./git.nix
    ./rust.nix
    ./swift.nix
    ./tool-environment.nix
  ]
  # VSCodium is a desktop application; non-NixOS hosts get no desktop.
  ++ lib.optionals (hostKind == "nixos") [ ./vscodium.nix ];
}
