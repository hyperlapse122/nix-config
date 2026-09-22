{
  config,
  lib,
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
  # rules, so without this list a fingerprint would satisfy passwd's auth phase
  # and set a new account password without the old one -- promoting the weaker
  # credential into the stronger one.
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

    security.pam.services =
      lib.genAttrs withheld (_: {
        fprintAuth = false;
      })
      // {
        # The enrollment helper authenticates against this service. It carries
        # neither the fingerprint nor the smartcard factor, so a fingerprint can
        # never mint a second fingerprint.
        enroll-fingerprint = {
          fprintAuth = false;
          p11Auth = false;
        };
      };

    # nixos/modules/security/polkit.nix declares a single `polkit-1` PAM service
    # for every polkit action, and that service deliberately carries the
    # fingerprint factor for authorisation prompts. polkit cannot scope which
    # factor satisfies which action, and upstream fprintd ships the enroll action
    # as auth_self_keep, so a swipe would otherwise authorize enrollment and the
    # grant would then be cached. Closing the action to interactive sessions is
    # the only place that can be stopped; the helper reaches fprintd with the
    # privilege this denial now requires.
    #
    # One action covers both operations: upstream's policy file declares
    # `verify`, `enroll` and `setusername` only, and describes `enroll` as
    # "Enroll or Delete fingerprints". There is no separate delete action to
    # name, so matching one id here is matching both operations.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "net.reactivated.fprint.device.enroll") {
          if (subject.user == "root") {
            return polkit.Result.YES;
          }
          return polkit.Result.NO;
        }
      });
    '';
  };
}
