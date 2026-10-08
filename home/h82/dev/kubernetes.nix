{
  config,
  lib,
  pkgs,
  ...
}:
let
  podman = config.services.podman.package;
  start = import ../../../packages/minikube-darwin-start.nix { inherit pkgs; };
  logFile = "${config.home.homeDirectory}/Library/Logs/minikube.log";
in
lib.mkMerge [
  {
    # The minikube package links its own bin/kubectl to minikube, which
    # downloads a kubectl on first use; the real kubectl takes priority. Each
    # package installs its zsh completion into share/zsh/site-functions.
    home.packages = [
      (lib.hiPrio pkgs.kubectl)
      pkgs.kubernetes-helm
      pkgs.minikube
    ];
  }

  # A macOS host starts the cluster at login inside the Podman machine, as a
  # NixOS host's user unit does on rootless Podman. The first start pulls
  # images, so a bootstrap generation starts none.
  (lib.mkIf (config.my.kind == "darwin" && !config.my.bootstrap) {
    # A hand-run `minikube start` then picks the same cluster as the agent.
    # MINIKUBE_ROOTLESS is left out: minikube ignores it on macOS.
    home.sessionVariables = {
      MINIKUBE_PROFILE = "minikube";
      MINIKUBE_DRIVER = "podman";
      MINIKUBE_CONTAINER_RUNTIME = "containerd";
    };

    launchd.agents.minikube = {
      enable = true;
      config = {
        ProgramArguments = [
          (lib.getExe start)
          (lib.getExe podman)
          (lib.getExe pkgs.minikube)
          "300"
          "5"
        ];
        # minikube runs podman by name.
        EnvironmentVariables.PATH = "${
          lib.makeBinPath [
            podman
            pkgs.minikube
          ]
        }:/usr/bin:/bin";
        RunAtLoad = true;
        KeepAlive.SuccessfulExit = false;
        ThrottleInterval = 60;
        # launchd would otherwise kill whatever minikube leaves running in the
        # job's process group when the job exits.
        AbandonProcessGroup = true;
        StandardOutPath = logFile;
        StandardErrorPath = logFile;
      };
    };
  })
]
