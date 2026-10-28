{
  config,
  lib,
  pkgs,
  ...
}:
let
  active = config.my.networkRecovery.enable && !config.my.bootstrap;
  tool = lib.getExe (import ../../packages/network-recovery.nix { inherit pkgs; });
  log = "/var/log/network-recovery.log";
  tailscale = "/Applications/Tailscale.app/Contents/MacOS/Tailscale";
in
{
  config = lib.mkIf active {
    # Root, because flushing DNS and turning a network service off and on need
    # it. launchd never starts a run while the previous one is still going, so
    # a run that takes its whole 25-second budget only delays the next.
    launchd.daemons.network-recovery.serviceConfig = {
      ProgramArguments = [
        tool
        "--state-dir"
        "/var/db/network-recovery"
        "--tailscale"
        tailscale
      ];
      StartInterval = 5;
      RunAtLoad = true;
      # The macOS tools the script calls by name.
      EnvironmentVariables.PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
      StandardOutPath = log;
      StandardErrorPath = log;
    };

    # Rotate at 1 MiB and keep five compressed generations.
    environment.etc."newsyslog.d/network-recovery.conf".text = ''
      # logfilename          [owner:group]    mode count size when  flags
      ${log}   root:wheel   644  5     1024 *     J
    '';
  };
}
