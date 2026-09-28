{ pkgs, ... }:
{
  home.packages = with pkgs; [
    sourcekit-lsp
    swift
    swift-format
    swiftpm
  ];
}
