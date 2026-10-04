/*
  T3 Code nightly, one artifact per trait: my.t3.cli.enable installs the
  headless `t3` CLI and my.t3.desktop.enable the desktop app. Its Codex and
  Claude sessions run the flake's own codex and claude with their user-level
  settings, so nothing here adds a copy of either.

  The desktop app is NixOS-only. Its package is added only on a NixOS host, so
  a non-NixOS host that enables it fails the assertion below rather than a
  build.
*/
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.t3;
  nixos = config.my.kind == "nixos";
in
{
  assertions = [
    {
      assertion = cfg.desktop.enable -> nixos;
      message = "${config.my.hostName}: my.t3.desktop.enable: the T3 Code desktop app is NixOS-only; enable my.t3.cli.enable on a non-NixOS host.";
    }
  ];

  home.packages =
    lib.optionals cfg.cli.enable [ (import ../../packages/t3code-cli.nix { inherit pkgs; }) ]
    ++ lib.optionals (cfg.desktop.enable && nixos) [
      (import ../../packages/t3code.nix { inherit pkgs; })
    ];
}
