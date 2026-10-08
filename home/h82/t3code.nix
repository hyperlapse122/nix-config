/*
  T3 Code nightly, one artifact per trait: my.t3.cli.enable installs the
  headless `t3` CLI and my.t3.desktop.enable the desktop app. Its Codex and
  Claude sessions run the flake's own codex and claude with their user-level
  settings, so nothing here adds a copy of either.

  The desktop app runs on NixOS and macOS. A non-NixOS Linux host that enables
  it fails the assertion below rather than a build.
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
  darwin = config.my.kind == "darwin";
  desktopSupported = nixos || darwin;

  merger = "${
    (import ../../packages/agent-tools.nix { inherit pkgs; }).agentSettings
  }/bin/agent-settings";

  # T3 Code leaves its built-in Antigravity provider off until
  # providers.antigravity.enabled is set, so it never shows up on its own. The
  # app and the CLI rewrite the settings file at runtime, so the key is merged
  # in rather than owned by a store symlink.
  declared = pkgs.writeText "t3code-declared-settings.json" (
    builtins.toJSON {
      setPaths = [
        {
          path = [
            "providers"
            "antigravity"
            "enabled"
          ];
          value = true;
        }
      ];
    }
  );
in
{
  assertions = [
    {
      assertion = cfg.desktop.enable -> desktopSupported;
      message = "${config.my.hostName}: my.t3.desktop.enable: the T3 Code desktop app runs on NixOS and macOS only; enable my.t3.cli.enable on a non-NixOS Linux host.";
    }
  ];

  home.packages =
    lib.optionals cfg.cli.enable [ (import ../../packages/t3code-cli.nix { inherit pkgs; }) ]
    ++ lib.optionals (cfg.desktop.enable && desktopSupported) [
      (import ../../packages/t3code.nix { inherit pkgs; })
    ];

  # Home Manager copies the macOS app bundle into ~/Applications writable, so
  # the app's own updater could move it off the nightly pin. The Linux wrapper
  # turns the updater off with this variable; on macOS a login agent sets it
  # for every app launched from Finder or the Dock.
  launchd.agents.t3code-disable-auto-update = lib.mkIf (cfg.desktop.enable && darwin) {
    enable = true;
    config = {
      ProgramArguments = [
        "/bin/launchctl"
        "setenv"
        "T3CODE_DISABLE_AUTO_UPDATE"
        "1"
      ];
      RunAtLoad = true;
    };
  };

  # The desktop app and the CLI share ~/.t3/userdata. Ordered after
  # installPackages, as the Claude Code merge in agents/claude.nix is, so a
  # refusal cannot strand linkGeneration. `run` leaves the file alone on a
  # dry run.
  home.activation.t3codeSettings = lib.mkIf (cfg.cli.enable || cfg.desktop.enable) (
    lib.hm.dag.entryAfter [ "installPackages" ] ''
      run ${merger} \
        --label 'T3 Code' \
        --settings ${config.home.homeDirectory}/.t3/userdata/settings.json \
        --declared ${declared}
    ''
  );
}
