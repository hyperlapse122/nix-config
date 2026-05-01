{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.gpg;

  # One-shot script to import the GPG private key stored in 1Password into the local keyring.
  # Run once manually when bootstrapping a new host — this is obtain-once, not declarative.
  # Requires the 1Password desktop app to be running (it provides the biometric/password unlock GUI),
  # and `gpg --batch --import` is non-interactive, so it just consumes the key data on stdin and writes it to the keyring.
  #
  # ⚠️ Do NOT add _1password-cli to runtimeInputs.
  # writeShellApplication prepends to PATH, which would put the nix-store raw `op` binary
  # ahead of /run/wrappers/bin/op (the setgid wrapper, group=onepassword-cli).
  # The 1Password desktop app's IPC socket is reachable only by the onepassword-cli group, so if the wrapper is hidden
  # the call fails with "cannot connect to 1Password app".
  # Therefore, leave `op` resolution to the caller's PATH — relying on /run/wrappers/bin/op installed by
  # the host's my.system.programs._1password.enable=true.
  importGpgKeys = pkgs.writeShellApplication {
    name = "import-gpg-keys";
    runtimeInputs = [ pkgs.gnupg ];
    text = ''
      op read "op://tjlmijoc5qxj6vypdnvxf6s2sq/gmwqu34rldszc6qtas2i3ejiaq/gpg_private.asc" | gpg --batch --import
    '';
  };
in
{
  options.my.gpg = {
    enable = lib.mkEnableOption "GnuPG + gpg-agent (pinentry-qt)";
  };

  config = lib.mkIf cfg.enable {
    programs.gpg = {
      enable = true;
    };

    # gpg-agent: runs as a user systemd unit and prompts for the passphrase via pinentry.
    # NOTE: pinentry-qt is Qt6-based and fits a KDE Plasma / Wayland environment.
    #       Add an option to widen this when a host on a different desktop environment appears.
    services.gpg-agent = {
      enable = true;
      pinentry.package = pkgs.pinentry-qt;
    };

    home.packages = [ importGpgKeys ];
  };
}
