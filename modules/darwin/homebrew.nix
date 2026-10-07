{ config, lib, ... }:
let
  mapping = import ../../home/h82/darwin-apps.nix;
  casks =
    lib.mapAttrsToList (_: app: app.cask) (lib.filterAttrs (_: app: app ? cask) mapping.apps)
    ++ mapping.darwinOnly;

  # A cask from a third-party tap is named <owner>/<tap>/<cask>.
  tapOf =
    cask:
    let
      parts = lib.splitString "/" cask;
    in
    if lib.length parts == 3 then "${lib.elemAt parts 0}/${lib.elemAt parts 1}" else null;
  thirdParty = lib.filter (cask: tapOf cask != null) casks;
in
{
  # nix-homebrew installs Homebrew itself on the first apply, so a new Mac
  # needs only Nix installed by hand. Taps stay mutable: an immutable tap set
  # turns off Homebrew's auto-update, which also stops its API cache from
  # refreshing, and then `upgrade` below would never see a newer cask.
  nix-homebrew = {
    enable = true;
    user = config.system.primaryUser;
    # Homebrew loads a cask from a non-official tap only once it is trusted.
    trust.casks = thirdParty;
  };

  homebrew = {
    enable = true;
    taps = lib.unique (map tapOf thirdParty);
    inherit casks;
    onActivation = {
      # Apps installed outside the list stay installed.
      cleanup = "none";
      # An apply installs missing casks and upgrades outdated ones; apps that
      # update themselves are left to their own updater.
      upgrade = true;
      autoUpdate = false;
    };
  };
}
