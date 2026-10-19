{ pkgs, ... }:
let
  # The same derivation Home Manager installs, so the profile attaches to the
  # binary the user actually runs.
  grokBot = import ../../packages/grok-bot.nix { inherit pkgs; };

  # The .deb's /etc/apparmor.d/grok-bot, renamed so it cannot collide with
  # that profile and attached to the store path instead of "/opt/Grok Bot".
  # Where the kernel restricts unprivileged user namespaces (the Ubuntu 24.04
  # default), Electron's sandbox cannot start without `userns`.
  profile = pkgs.writeText "nix-grok-bot" ''
    abi <abi/4.0>,
    include <tunables/global>

    profile "nix-grok-bot" "${grokBot}/lib/grok-bot/grok-bot" flags=(unconfined) {
      userns,

      # Site-specific additions and overrides. See local/README for details.
      include if exists <local/nix-grok-bot>
    }
  '';
in
{
  # grok-bot is unfree, as it is in the user environment's nixpkgs.
  nixpkgs.config.allowUnfree = true;

  environment.etc."apparmor.d/nix-grok-bot".source = profile;

  # The distribution's apparmor.service loads the profile on later boots; this
  # loads it now and again whenever it changes. The distribution's parser is
  # used because it matches the kernel and the abi files under /etc. A host
  # without a parser, or one too old for abi 4.0, keeps Grok Bot confined
  # rather than failing the activation.
  systemd.services.nix-grok-bot-apparmor = {
    description = "Load the Grok Bot AppArmor profile";
    wantedBy = [ "multi-user.target" ];
    after = [ "apparmor.service" ];
    restartTriggers = [ profile ];
    unitConfig.ConditionSecurity = "apparmor";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      profile=/etc/apparmor.d/nix-grok-bot
      parser=
      for candidate in /sbin/apparmor_parser /usr/sbin/apparmor_parser; do
        if [ -x "$candidate" ]; then
          parser=$candidate
          break
        fi
      done
      if [ -z "$parser" ]; then
        echo "no apparmor_parser in /sbin or /usr/sbin; not loading $profile"
        exit 0
      fi
      # The .deb's own probe: an AppArmor without abi 4.0 rejects the profile.
      if ! "$parser" --skip-kernel-load --debug "$profile" >/dev/null 2>&1; then
        echo "$parser rejects $profile; not loading it"
        exit 0
      fi
      exec "$parser" --replace --write-cache --skip-read-cache "$profile"
    '';
  };
}
