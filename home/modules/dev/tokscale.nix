{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.dev.tokscale;

  # tokscale CLI: mise wrapper (pulls the latest tokscale from npm every invocation).
  # Same pattern as the opencode module — mise itself is added separately to home.packages to ensure the dependency is present.
  tokscaleWrapper = pkgs.writeShellApplication {
    name = "tokscale";
    text = ''
      exec ${pkgs.mise}/bin/mise exec -q npm:tokscale@latest -- tokscale "$@"
    '';
  };
in
{
  options.my.dev.tokscale = {
    enable = lib.mkEnableOption "tokscale CLI (mise wrapper)";
  };

  config = lib.mkIf cfg.enable {
    # mise wrapper + mise itself
    home.packages = [
      tokscaleWrapper
      pkgs.mise
    ];
  };
}
