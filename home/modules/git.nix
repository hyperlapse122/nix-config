{ config, lib, pkgs, ... }:
let
  cfg = config.my.git;

  # CLI tool 기반 credential helper (각자 호스트에서 사용)
  # 빈 문자열로 상위 helper 초기화 후 CLI 지정 (둘 다 실행되는 것 방지)
  ghCredentialHelper = [
    ""
    "!${lib.getExe pkgs.gh} auth git-credential"
  ];
  glabCredentialHelper = [
    ""
    "!${lib.getExe pkgs.glab} auth git-credential"
  ];
in {
  options.my.git = {
    enable = lib.mkEnableOption "Git configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;

      # Git LFS — clean/smudge/process filter 자동 설정 + git-lfs 패키지 포함
      lfs.enable = true;

      settings = {
        # User Settings
        user.name = "Joosung Park";
        user.email = "iam@h82.dev";
        user.signingkey = "A7F1956CD1A035A139BC7ABFCC740A29852C0E95";

        init.defaultBranch = "main";
        pull.rebase = true;

        # Line ending 정책 — Windows CRLF 자동 변환 비활성화
        core.autocrlf = false;

        # 모든 commit/tag 자동 GPG 서명
        commit.gpgsign = true;
        tag.gpgSign = true;

        # Push 동작 — submodule 검증 + 첫 push 시 upstream 자동 설정
        push.recurseSubmodules = "check";
        push.autoSetupRemote = true;

        credential = {
          # 기본 credential helper — Git Credential Manager (Azure DevOps 등 fallback)
          helper = "${pkgs.git-credential-manager}/bin/git-credential-manager";
          credentialStore = "secretservice";
          guiPrompt = "true";

          # GitHub 호스트 — gh CLI을 credential helper로 사용
          # 첫 사용 시: `gh auth login` (gist.github.com 동일 인증 공유)
          "https://github.com".helper = ghCredentialHelper;
          "https://gist.github.com".helper = ghCredentialHelper;

          # GitLab 호스트 — glab CLI을 credential helper로 사용
          # 첫 사용 시: `glab auth login --hostname <host>`
          "https://gitlab.com".helper = glabCredentialHelper;
          "https://git.jpi.app".helper = glabCredentialHelper;

          # Azure DevOps — 같은 호스트의 다른 repo 별 자격증명 분리
          "https://dev.azure.com" = {
            useHttpPath = true;
          };
        };
      };
    };

    # Git 인증 도구 + GitHub/GitLab CLI
    home.packages = with pkgs; [
      git-credential-manager
      libsecret
      gh
      glab
    ];
  };
}
