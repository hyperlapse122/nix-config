{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.dev.codex;

  # Codex CLI: mise wrapper (pulls the latest @openai/codex from npm every invocation).
  # Same pattern as the tokscale module: mise itself is added separately to home.packages to ensure the dependency is present.
  codexWrapper = pkgs.writeShellApplication {
    name = "codex";
    text = ''
      exec ${pkgs.mise}/bin/mise exec -q npm:@openai/codex@latest -- codex "$@"
    '';
  };
in
{
  options.my.dev.codex = {
    enable = lib.mkEnableOption "Codex CLI (mise wrapper)";
  };

  config = lib.mkIf cfg.enable {
    # mise wrapper + mise itself
    home.packages = [
      codexWrapper
      pkgs.mise
    ];
  };
}
