{ config, lib, pkgs, ... }:
let
  cfg = config.my.git;
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

        # Git Credential Manager 사용 설정
        credential = {
          helper = "${pkgs.git-credential-manager}/bin/git-credential-manager";
          credentialStore = "secretservice";
          guiPrompt = "true";
          gitLabAuthModes = "browser";

          # JPI GitLab 인스턴스 OAuth 설정 (git-credential-manager GitLab provider)
          "https://git.jpi.app" = {
            gitLabDevClientId = "e7247d5a19cd0fa15c1754dfaae47606bcd27d9cd3dbd1b966993be0b683983b";
            gitLabDevClientSecret = "gloas-5992d1284ff2c9b33668eef4271cf6a6765756f1b4bcd413e0d9f55071a72d41";
            provider = "gitlab";
          };

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
