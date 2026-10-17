{
  config,
  lib,
  pkgs,
  ...
}:
let
  user = config.system.primaryUser;
  kakaoTalkId = "869223134";
in
{
  # KakaoTalk comes from the Mac App Store through mas, for the reasons
  # xcode.nix gives for not using homebrew.masApps or programs.mas, and with
  # the same shape: every mas call runs in the user's session with SUDO_UID
  # set, and every command that can fail sits in an `if !` guard, so a
  # signed-out App Store never stops the `set -e` activate script.
  #
  # Order 750 runs this after the Xcode step (mkBefore, 500) and before Home
  # Manager's activation call (default, 1000), while still root.
  system.activationScripts.postActivation.text = lib.mkOrder 750 ''
    echo "setting up KakaoTalk..." >&2
    appStoreUid=$(/usr/bin/id -u ${user} 2>/dev/null) || appStoreUid=
    appStoreGid=$(/usr/bin/id -g ${user} 2>/dev/null) || appStoreGid=
    appStoreMas() {
      /bin/launchctl asuser "$appStoreUid" /usr/bin/env SUDO_UID="$appStoreUid" SUDO_GID="$appStoreGid" ${lib.getExe pkgs.mas} "$@"
    }
    if [[ -z $appStoreUid || -z $appStoreGid ]]; then
      echo "kakaotalk: cannot resolve the ids of ${user}; system.primaryUser must name an existing account" >&2
    elif [[ ! -d /Applications/KakaoTalk.app ]]; then
      # install covers only apps the account already obtained.
      if ! appStoreMas install ${kakaoTalkId} && ! appStoreMas get ${kakaoTalkId}; then
        echo "kakaotalk: App Store install failed; sign in to the App Store as ${user} and apply again" >&2
      fi
    elif ! appStoreMas upgrade ${kakaoTalkId}; then
      echo "kakaotalk: App Store upgrade failed; check that ${user} is signed in to the App Store" >&2
    fi
  '';
}
