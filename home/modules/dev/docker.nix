{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.dev.docker;

  # docker-credential-glab — Docker credential helper for GitLab Container Registry.
  # A thin wrapper around `glab auth docker-helper`. Must be exposed on PATH as
  # `docker-credential-glab` so that docker can invoke it via the credHelpers="glab" mapping
  # in ~/.docker/config.json (docker resolves helpers by looking up the binary
  # `docker-credential-<value>` on PATH).
  # First-time use: `glab auth login --hostname <gitlab-host>` to register the token.
  dockerCredentialGlab = pkgs.writeShellApplication {
    name = "docker-credential-glab";
    runtimeInputs = [ pkgs.glab ];
    text = ''
      exec glab auth docker-helper "$@"
    '';
  };

  # docker-credential-gh — Docker credential helper for GitHub Container Registry.
  # `gh` has no built-in helper like `glab auth docker-helper`, so this implements the
  # docker-credential protocol directly (reference:
  # https://gist.github.com/mislav/e154d707db230dc882d7194ec85d79f6).
  # Protocol:
  #   - `get`   : read host from stdin, output {"Username":..,"Secret":..} JSON
  #   - `store` : consume stdin then no-op (auth is managed by `gh auth login`; not stored via docker login)
  #   - `erase` : consume stdin then no-op
  # First-time use: `gh auth login` registers the token (the git credential helper in git.nix
  # already shares the same token, so during GitHub work the user is usually already authenticated).
  dockerCredentialGh = pkgs.writeShellApplication {
    name = "docker-credential-gh";
    runtimeInputs = [ pkgs.gh ];
    text = ''
      cmd="''${1:-}"

      case "$cmd" in
        store | erase)
          # Docker protocol — consume stdin and no-op.
          cat >/dev/null
          exit 0
          ;;
        get) ;;
        *) exit 1 ;;
      esac

      host="$(cat)"
      host="''${host#https://}"
      host="''${host%/}"

      # Whitelist of hosts this helper will respond to. Must match the credHelpers mapping
      # (if docker calls this binary for any other host, that's a misconfiguration — refuse).
      case "$host" in
        ghcr.io | docker.pkg.github.com) ;;
        *) exit 1 ;;
      esac

      token="$(gh auth token --hostname github.com)"
      # Username: prefer the gh API; on failure, fall back to the dummy value ghcr.io accepts alongside a PAT.
      username="$(GH_HOST=github.com gh api user -q '.login' 2>/dev/null || echo oauth2accesstoken)"

      printf '{"Username":"%s","Secret":"%s"}\n' "$username" "$token"
    '';
  };
in
{
  options.my.dev.docker = {
    enable = lib.mkEnableOption "Docker CLI credential helpers (registry.jpi.app → glab, ghcr.io → gh)";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      # For running `glab/gh auth login` directly + as runtime dependencies of the wrappers.
      # Also included by git.nix, but Nix dedupes by store path — listed here too to keep the module self-contained.
      pkgs.glab
      pkgs.gh
      dockerCredentialGlab
      dockerCredentialGh
    ];

    # ~/.docker/config.json — Docker CLI configuration (managed declaratively).
    # credHelpers maps each registry to a `docker-credential-<value>` binary.
    #   - registry.jpi.app    → glab : JPI's internal GitLab Container Registry.
    #     Both the default port (443) and the explicit `:443` form are registered — docker
    #     does string-match URLs without normalization, so `docker login registry.jpi.app:443`
    #     needs its own key.
    #   - ghcr.io             → gh   : GitHub Container Registry.
    #   - docker.pkg.github.com → gh : GitHub Packages (legacy, migrated to ghcr.io).
    #
    # Caveat: this file is a Nix-store symlink and is therefore read-only. Trying to save
    # credentials for any other registry via `docker login` will fail with EROFS — those
    # registries must either go through a helper or be added to this module too.
    home.file.".docker/config.json".text = builtins.toJSON {
      credHelpers = {
        "registry.jpi.app" = "glab";
        "registry.jpi.app:443" = "glab";
        "ghcr.io" = "gh";
        "docker.pkg.github.com" = "gh";
      };
    };
  };
}
