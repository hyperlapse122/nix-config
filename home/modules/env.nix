{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.env;

  # User session-wide environment variables.
  # Consolidates values that used to be scattered across ~/.config/environment.d/*.conf.
  # No host-specific branching, so kept as a single toggle in home/modules/.
  sessionVars = {
    # ── mise / rustup ────────────────────────────────────────────────
    # Let rustup-init proceed without warning when other cargo binaries are visible on PATH.
    # Since mise authoritatively manages toolchains, rustup's PATH-conflict check is unnecessary.
    RUSTUP_INIT_SKIP_PATH_CHECK = "yes";

    # ── pinentry / gpg-agent ─────────────────────────────────────────
    # Make pinentry-qt cache passphrases in KDE Wallet.
    # gpg-agent is a user systemd unit, so the variable must be delivered via
    # systemd.user.sessionVariables (set on both options below).
    PINENTRY_KDE_USE_WALLET = "1";

    # ── PowerShell ───────────────────────────────────────────────────
    # Disable telemetry / auto-update checks.
    POWERSHELL_TELEMETRY_OPTOUT = "1";
    POWERSHELL_CLI_TELEMETRY_OPTOUT = "1";
    POWERSHELL_UPDATECHECK = "Off";
    POWERSHELL_UPDATECHECK_OPTOUT = "1";

    # ── .NET ─────────────────────────────────────────────────────────
    # Disable CLI / SDK telemetry + CoreCLR diagnostics.
    # COMPlus_EnableDiagnostics was renamed to DOTNET_EnableDiagnostics in .NET 5+,
    # but the legacy name is still recognized — preserved as in the original dotfile.
    DOTNET_CLI_TELEMETRY_OPTOUT = "1";
    DOTNET_TELEMETRY_OPTOUT = "1";
    COMPlus_EnableDiagnostics = "0";

    # ── Firefox ──────────────────────────────────────────────────────
    # FIREFOX_PATH is not a standard Firefox variable — it's a custom value that user scripts read.
    # MOZ_USE_XINPUT2 is X11-only and ignored under Wayland, but kept as a safety net.
    FIREFOX_PATH = "firefox";
    MOZ_USE_XINPUT2 = "1";

    # ── Electron ─────────────────────────────────────────────────────
    # Auto-pick the Ozone Wayland backend on Wayland-capable Electron apps; otherwise fall back to X11.
    # On a Plasma 6 Wayland session, this makes VS Code / Slack and other Electron apps run as native Wayland.
    ELECTRON_OZONE_PLATFORM_HINT = "auto";

    # NOTE: Input-method variables (XMODIFIERS / GTK_IM_MODULE / QT_IM_MODULE / SDL_IM_MODULE) are
    #       intentionally left unset. This system runs fcitx5 with waylandFrontend = true, where
    #       home-manager's i18n.inputMethod handles them automatically — see the NOTE in
    #       home/modules/i18n/fcitx5.nix for details. The legacy dotfile's kime XMODIFIERS was
    #       intentionally dropped during migration.
  };
in
{
  options.my.env = {
    enable = lib.mkEnableOption "User session environment variables (replaces legacy ~/.config/environment.d)";
  };

  config = lib.mkIf cfg.enable {
    # Exported into the login shell (~/.profile, ~/.zshenv).
    # TTY logins / SSH / shells that directly spawn children pick up the variables here.
    home.sessionVariables = sessionVars;

    # Injected into every unit managed by systemd --user.
    # Concretely, ~/.config/environment.d/10hm-session-vars.conf is generated, and gpg-agent
    # (PINENTRY_KDE_USE_WALLET) plus all GUI apps (Electron / Firefox / etc.) launched by the
    # KDE Plasma Wayland session pick up the variables through this path.
    # home.sessionVariables alone does NOT propagate to systemd user units, so we set the same
    # attrset explicitly on both options to cover both shell and session sides.
    systemd.user.sessionVariables = sessionVars;
  };
}
