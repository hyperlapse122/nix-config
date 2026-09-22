{
  lib,
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
in
{
  home.sessionVariables = {
    REGISTRY_AUTH_FILE = "/home/h82/.config/containers/auth.json";
    DOCKER_HOST = "unix://\${XDG_RUNTIME_DIR}/podman/podman.sock";
  };

  systemd.user.sessionVariables = {
    REGISTRY_AUTH_FILE = "/home/h82/.config/containers/auth.json";
    DOCKER_HOST = "unix://\${XDG_RUNTIME_DIR}/podman/podman.sock";
  };

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
}
