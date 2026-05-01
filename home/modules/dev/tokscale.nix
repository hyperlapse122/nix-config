{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.dev.tokscale;

  # tokscale CLI: bunx wrapper (pulls the latest tokscale from npm every invocation).
  # Same pattern as the opencode module — bun itself is added separately to home.packages to ensure the dependency is present.
  tokscaleWrapper = pkgs.writeShellApplication {
    name = "tokscale";
    text = ''
      exec ${pkgs.bun}/bin/bunx tokscale@latest "$@"
    '';
  };
in
{
  options.my.dev.tokscale = {
    enable = lib.mkEnableOption "tokscale CLI (bunx wrapper)";
  };

  config = lib.mkIf cfg.enable {
    # bunx wrapper + bun itself
    home.packages = [
      tokscaleWrapper
      pkgs.bun
    ];
  };
}
