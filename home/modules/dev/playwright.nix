{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.my.dev.playwright;

  # Use the packages exposed by pietdevries94/playwright-web-flake.
  # We pick this flake over nixpkgs' playwright-driver because:
  #   - It updates more frequently than nixpkgs' release cadence, making it easier to keep in sync with npm `@playwright/test`.
  #   - A flake tag (e.g. github:pietdevries94/playwright-web-flake/1.x.y) lets us pin an exact version.
  # Packages exposed:
  #   - playwright-test    : the `playwright` CLI binary
  #   - playwright-driver  : the driver (browse pre-built browsers via the `.browsers` attribute)
  pwPkgs = inputs.playwright.packages.${pkgs.stdenv.hostPlatform.system};

  # Playwright runtime environment variables — based on the NixOS Wiki (https://wiki.nixos.org/wiki/Playwright).
  # PLAYWRIGHT_BROWSERS_PATH                   — Browser path (used instead of npm's ~/.cache/ms-playwright).
  #                                              Setting this skips the `playwright install` step entirely.
  # PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS — Disables playwright's distro-dependency checks.
  #                                              The nixpkgs wrap already binds every required lib by store path,
  #                                              so validating system paths is meaningless.
  # PLAYWRIGHT_HOST_PLATFORM_OVERRIDE          — Pins the host-platform identifier explicitly.
  #                                              The Wiki notes "Seems like it is not needed?", but on some
  #                                              versions / CI paths distro auto-detection fails — pinning it
  #                                              short-circuits the validation branch entirely.
  # PLAYWRIGHT_NODEJS_PATH                     — Path to the node binary playwright should use.
  #                                              Pins the npm-installed playwright's spawned children to the
  #                                              same node as nixpkgs.
  sessionVars = {
    PLAYWRIGHT_BROWSERS_PATH = "${pwPkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
    PLAYWRIGHT_HOST_PLATFORM_OVERRIDE = "ubuntu-24.04";
    PLAYWRIGHT_NODEJS_PATH = "${pkgs.nodejs}/bin/node";
  };
in
{
  options.my.dev.playwright = {
    enable = lib.mkEnableOption "Playwright driver + browsers + runtime env vars (pietdevries94/playwright-web-flake)";
  };

  config = lib.mkIf cfg.enable {
    # playwright-test           — `playwright` CLI binary (flake#playwright-test).
    # playwright-driver         — patchelf-processed playwright driver (flake#playwright-driver).
    #                             The .so files that would otherwise trigger missing-system-lib warnings are already wrapped to store paths.
    # playwright-driver.browsers — pre-built chromium / firefox / webkit binaries (same wrap applied as the driver).
    #
    # Version-sync caveat: the project's package.json `@playwright/test` must match the flake's playwright version.
    # On mismatch, downgrade npm or pin the flake input to that tag:
    #   inputs.playwright.url = "github:pietdevries94/playwright-web-flake/1.x.y";
    # Available tags: https://github.com/pietdevries94/playwright-web-flake/tags
    home.packages = [
      pwPkgs.playwright-test
      pwPkgs.playwright-driver
      pwPkgs.playwright-driver.browsers
    ];

    # Login shell (~/.profile, ~/.zshenv) — picked up by children spawned from the terminal / SSH / TTY.
    home.sessionVariables = sessionVars;

    # Inject into every unit managed by systemd --user — covers VS Code's integrated terminal, GUI apps
    # KDE Plasma launches (e.g. Electron-based IDEs started from the desktop), etc.
    # See env.nix for the same pattern.
    systemd.user.sessionVariables = sessionVars;
  };
}
