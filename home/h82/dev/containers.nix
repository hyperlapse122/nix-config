{
  config,
  lib,
  pkgs,
  ...
}:
let
  initialAuth = builtins.toJSON {
    credHelpers = {
      "docker.io" = "sops";
      "ghcr.io" = "sops";
      "registry.gitlab.com" = "sops";
      "registry.jpi.app" = "sops";
    };
  };
  containerSessionVariables = {
    REGISTRY_AUTH_FILE = "${config.home.homeDirectory}/.config/containers/auth.json";
    DOCKER_HOST = "unix://\${XDG_RUNTIME_DIR}/podman/podman.sock";
    # Ryuk needs a privileged container to manage the rootless Podman socket.
    TESTCONTAINERS_RYUK_CONTAINER_PRIVILEGED = "true";
    TESTCONTAINERS_RYUK_PRIVILEGED = "true";
  };

  # The docker CLI keys Docker Hub by its legacy index address.
  dockerCredHelpers = builtins.toJSON {
    "https://index.docker.io/v1/" = "sops";
    "ghcr.io" = "sops";
    "registry.gitlab.com" = "sops";
    "registry.jpi.app" = "sops";
  };
in
lib.mkMerge [
  # Rootless Podman is the container runtime on NixOS and Linux hosts. A macOS
  # host runs OrbStack instead, which owns ~/.docker, so none of the Podman
  # socket, Ryuk, or containers/ files apply there.
  (lib.mkIf (config.my.kind != "darwin") {
    home.sessionVariables = containerSessionVariables;

    systemd.user.sessionVariables = containerSessionVariables;

    xdg.configFile."containers/registries.conf.d/10-unqualified-search.conf".text = ''
      unqualified-search-registries = ["docker.io"]
    '';

    home.activation.containersAuth = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          AUTH_DIR="$HOME/.config/containers"
          AUTH_FILE="$AUTH_DIR/auth.json"
          if [ ! -e "$AUTH_FILE" ] && [ ! -L "$AUTH_FILE" ]; then
            run mkdir -p "$AUTH_DIR"
            run chmod 0700 "$AUTH_DIR"
            if [[ -v DRY_RUN ]]; then
              echo "Creating $AUTH_FILE with initial credHelpers"
            else
              cat <<'EOF' > "$AUTH_FILE"
      ${initialAuth}
      EOF
              chmod 0600 "$AUTH_FILE"
            fi
          fi
    '';
  })

  # OrbStack writes its own context into ~/.docker/config.json, so the file is
  # never linked from the store: the credential helpers are merged into it, and
  # every other key stays as OrbStack wrote it. Bootstrap has no tokens yet.
  (lib.mkIf (config.my.kind == "darwin" && !config.my.bootstrap) {
    home.activation.dockerCredHelpers = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      DOCKER_DIR="$HOME/.docker"
      DOCKER_CONFIG_FILE="$DOCKER_DIR/config.json"
      if [[ -v DRY_RUN ]]; then
        echo "Merging credHelpers into $DOCKER_CONFIG_FILE"
      else
        mkdir -p "$DOCKER_DIR"
        [ -e "$DOCKER_CONFIG_FILE" ] || echo '{}' > "$DOCKER_CONFIG_FILE"
        merged=$(${lib.getExe pkgs.jq} --argjson helpers ${lib.escapeShellArg dockerCredHelpers} \
          '.credHelpers = ((.credHelpers // {}) + $helpers)' "$DOCKER_CONFIG_FILE")
        if [ "$merged" != "$(cat "$DOCKER_CONFIG_FILE")" ]; then
          printf '%s\n' "$merged" > "$DOCKER_CONFIG_FILE"
        fi
        chmod 0600 "$DOCKER_CONFIG_FILE"
      fi
    '';
  })
]
