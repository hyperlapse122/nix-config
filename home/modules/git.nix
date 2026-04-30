{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.git;

  # CLI-tool-based credential helpers (used per host).
  # Initialize the parent helper to empty string before adding the CLI helper, so that both don't run.
  ghCredentialHelper = [
    ""
    "!${lib.getExe pkgs.gh} auth git-credential"
  ];
  glabCredentialHelper = [
    ""
    "!${lib.getExe pkgs.glab} auth git-credential"
  ];
in
{
  options.my.git = {
    enable = lib.mkEnableOption "Git configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;

      # Git LFS — auto-configures the clean/smudge/process filter and includes the git-lfs package.
      lfs.enable = true;

      settings = {
        # User Settings
        user.name = "Joosung Park";
        user.email = "iam@h82.dev";
        user.signingkey = "A7F1956CD1A035A139BC7ABFCC740A29852C0E95";

        init.defaultBranch = "main";
        pull.rebase = true;

        # Line-ending policy — disable Windows CRLF auto-conversion.
        core.autocrlf = false;

        # Auto-sign every commit/tag with GPG.
        commit.gpgsign = true;
        tag.gpgSign = true;

        # Push behavior — verify submodules + auto-set upstream on first push.
        push.recurseSubmodules = "check";
        push.autoSetupRemote = true;

        credential = {
          # Default credential helper — Git Credential Manager (fallback for Azure DevOps, etc.).
          helper = "${pkgs.git-credential-manager}/bin/git-credential-manager";
          credentialStore = "secretservice";
          guiPrompt = "true";

          # GitHub hosts — use the gh CLI as the credential helper.
          # First-time use: `gh auth login` (gist.github.com shares the same authentication).
          "https://github.com".helper = ghCredentialHelper;
          "https://gist.github.com".helper = ghCredentialHelper;

          # GitLab hosts — use the glab CLI as the credential helper.
          # First-time use (OAuth/web login — `glab auth git-credential` auto-refreshes the token):
          #
          # gitlab.com (SaaS, default):
          # ```sh
          # glab auth login --hostname gitlab.com --web
          # ```
          #
          # git.jpi.app (in-house self-hosted) — glab's default OAuth client isn't registered on this instance,
          # so the custom OAuth application's client_id must be injected before login.
          # `--container-registry-domains` is what the docker credential helper (home/modules/dev/docker.nix)
          # uses to map the registry.jpi.app host onto git.jpi.app authentication:
          # ```sh
          # glab config set client_id c6c350c323dbd7dbd4091b2f3e56a1d6ef31e7104ae6deddfc5d950c7d11d69f \
          #   --global --host git.jpi.app
          # glab auth login --hostname git.jpi.app --web \
          #   --container-registry-domains registry.jpi.app,registry.jpi.app:443 \
          #   -a git.jpi.app -p https
          # ```
          "https://gitlab.com".helper = glabCredentialHelper;
          "https://git.jpi.app".helper = glabCredentialHelper;

          # Azure DevOps — separate credentials per repo on the same host.
          "https://dev.azure.com" = {
            useHttpPath = true;
          };
        };
      };
    };

    # Git authentication tools + GitHub/GitLab CLIs
    home.packages = with pkgs; [
      git-credential-manager
      libsecret
      git-trim
      gh
      glab
    ];
  };
}
