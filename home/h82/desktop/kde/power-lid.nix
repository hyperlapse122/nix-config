{
  pkgs,
  lib,
  osConfig,
  ...
}:

let
  kwrite = "${pkgs.kdePackages.kconfig}/bin/kwriteconfig6";
in
lib.mkIf (osConfig.networking.hostName == "ThinkPad-X1-Carbon-Gen-11") {
  # Powerdevil -- not systemd-logind -- decides lid-switch behavior while a
  # Plasma session is running: it takes an unconditional block-mode
  # systemd-logind inhibitor over handle-lid-switch the moment its D-Bus
  # service registers, so logind's own HandleLidSwitch settings
  # (hosts/ThinkPad-X1-Carbon-Gen-11/default.nix) are consulted only when no
  # Plasma session is active.
  home.activation.kdePowerLid = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -x "${kwrite}" ]; then
      # Battery / low-battery profiles: suspend-then-hibernate on lid close
      ${kwrite} --file powerdevilrc --group Battery --group SuspendAndShutdown --key LidAction -- 1
      ${kwrite} --file powerdevilrc --group Battery --group SuspendAndShutdown --key SleepMode -- 3
      ${kwrite} --file powerdevilrc --group LowBattery --group SuspendAndShutdown --key LidAction -- 1
      ${kwrite} --file powerdevilrc --group LowBattery --group SuspendAndShutdown --key SleepMode -- 3

      # AC profile: ignore lid close while plugged in
      ${kwrite} --file powerdevilrc --group AC --group SuspendAndShutdown --key LidAction -- 0

      # All profiles: ignore lid close while docked (an external monitor is
      # connected) -- pinned explicitly rather than relying on upstream's own
      # default of true
      ${kwrite} --file powerdevilrc --group AC --group SuspendAndShutdown --key InhibitLidActionWhenExternalMonitorPresent --type bool true
      ${kwrite} --file powerdevilrc --group Battery --group SuspendAndShutdown --key InhibitLidActionWhenExternalMonitorPresent --type bool true
      ${kwrite} --file powerdevilrc --group LowBattery --group SuspendAndShutdown --key InhibitLidActionWhenExternalMonitorPresent --type bool true
    fi
  '';
}
