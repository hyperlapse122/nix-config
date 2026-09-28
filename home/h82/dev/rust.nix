{ config, pkgs, ... }:
{
  # rustup honours each project's rust-toolchain.toml; the toolchains it
  # downloads are dynamically linked and run through nix-ld. The first
  # toolchain is a one-time `rustup default stable`.
  home.packages = [ pkgs.rustup ];

  # `cargo install` puts binaries here; the Nix rustup does not add it itself.
  home.sessionPath = [ "${config.home.homeDirectory}/.cargo/bin" ];
}
