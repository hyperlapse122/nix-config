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
      settings = {
        # User Settings
        user.name = "Joosung Park";
        user.email = "iam@h82.dev";

        init.defaultBranch = "main";
        pull.rebase = true;

        # Git Credential Manager 사용 설정
        credential.helper = "${pkgs.git-credential-manager}/bin/git-credential-manager";
        credential.credentialStore = "secretservice";
        credential.guiPrompt = "true";
      };
    };

    # Git 인증 도구
    home.packages = with pkgs; [
      git-credential-manager
      libsecret
    ];
  };
}
