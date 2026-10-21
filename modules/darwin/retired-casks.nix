{ config, lib, ... }:
let
  user = config.system.primaryUser;
  brew = "${config.homebrew.prefix}/bin/brew";
  retired = [ "grok-bot" ];
in
{
  # A cask the configuration no longer lists stays installed, because
  # homebrew.onActivation.cleanup is "none"; this step removes the retired
  # ones. It never passes --zap, so the app's user data stays in place.
  #
  # Homebrew refuses to run as root and `launchctl asuser` leaves the process
  # root, so brew runs through sudo as the primary user, the way nix-darwin's
  # own Homebrew activation calls it. Every command that can fail sits in an
  # `if !` guard and prints one line, so a failed brew never stops the `set -e`
  # activate script.
  #
  # Order 800 runs this after Homebrew's own step, the KakaoTalk step (750),
  # and before Home Manager's activation call (default, 1000).
  system.activationScripts.postActivation.text = lib.mkOrder 800 ''
    retiredBrew() {
      /usr/bin/sudo --user=${user} --set-home /usr/bin/env NONINTERACTIVE=1 ${brew} "$@"
    }
    ${lib.concatMapStrings (cask: ''
      if ! retiredBrew list --cask ${cask} >/dev/null 2>&1; then
        echo "retired casks: no ${cask} cask to remove" >&2
      elif ! retiredBrew uninstall --cask ${cask}; then
        echo "retired casks: uninstalling ${cask} failed; run brew uninstall --cask ${cask} as ${user}" >&2
      else
        echo "retired casks: removed the ${cask} cask" >&2
      fi
    '') retired}
  '';
}
