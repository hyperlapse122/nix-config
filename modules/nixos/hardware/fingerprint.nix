{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.fingerprint;

  # security.pam.services.<name>.fprintAuth defaults to services.fprintd.enable
  # per service, with no global lever, so enabling the daemon hands the factor to
  # every service that uses the default rules. The two lists below take it back
  # by naming the services it must not reach.
  #
  # SDDM's own auth stack is `substack login`, so the greeter inherits through
  # `login`; naming `sddm` alone would leave the greeter covered by nothing.
  greeterReachable = [
    "login"
    "sddm"
    "sddm-greeter"
    "sddm-autologin"
  ];

  # nixos/modules/programs/shadow.nix declares `passwd = { }` with the default
  # rules, so without this list an unprivileged user running `passwd` could
  # authenticate with a fingerprint and change their account password without
  # entering the old password. Note: this does not block `sudo passwd <user>`,
  # because the fingerprint reaches sudo (root) on this host, which bypasses the
  # old password check entirely. This list closes the unprivileged path.
  credentialMutating = [
    "passwd"
    "chpasswd"
    "chsh"
    "chfn"
    "su"
  ];

  # DUPLICATION IS DELIBERATE. tests/pam-fingerprint.nix states the set of PAM
  # files allowed to carry pam_fprintd.so as its own independent literal. Do not
  # make the check import these lists, and do not make this module read the
  # check's allowlist: a single edit must never be able to change both sides and
  # leave the guard green.
  withheld = greeterReachable ++ credentialMutating;
in
{
  options.my.fingerprint = {
    enable = lib.mkEnableOption "fingerprint authentication for the lock screen, polkit and sudo";
  };

  config = lib.mkIf cfg.enable {
    # `kde` and `kde-fingerprint` are left to the Plasma module: it already
    # withholds the factor from `kde` and routes the lock screen through
    # `kde-fingerprint` when fprintd is enabled.
    services.fprintd.enable = true;

    # Gated with the factor: a host without it would carry a helper whose only
    # purpose is a reader it does not use.
    environment.systemPackages = [
      (import ../../../packages/enroll-fingerprint.nix { inherit pkgs; })
    ];

    security.pam.services =
      lib.genAttrs withheld (_: {
        fprintAuth = false;
      })
      // {
        # The enrollment helper authenticates against this service. It carries
        # neither the fingerprint nor the smartcard factor, so a fingerprint can
        # never mint a second fingerprint through the helper. Note: this closes
        # the unprivileged enrollment path, not the root path (`sudo fprintd-enroll`).
        enroll-fingerprint = {
          fprintAuth = false;
          p11Auth = false;
        };
      };

    # nixos/modules/security/polkit.nix declares a single `polkit-1` PAM service
    # for every polkit action. To allow enrollment and management via KDE
    # System Settings and interactive tools without granting access to unprivileged
    # non-administrative users, we authorize root and the wheel group.
    #
    # One action covers both operations: upstream's policy file declares
    # `verify`, `enroll` and `setusername` only, and describes `enroll` as
    # "Enroll or Delete fingerprints". There is no separate delete action to
    # name, so matching one id here is matching both operations.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "net.reactivated.fprint.device.enroll") {
          if (subject.user == "root" || subject.isInGroup("wheel")) {
            return polkit.Result.YES;
          }
          return polkit.Result.NO;
        }
      });
    '';
  };
}
