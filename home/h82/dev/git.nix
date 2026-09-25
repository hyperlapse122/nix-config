{ pkgs, ... }:
{
  home.packages = [ pkgs.git-trim ];

  programs.git = {
    enable = true;
    signing = {
      key = "621512777E6933FEB4458FDC4945855D4F283F05";
      signByDefault = true;
    };
    settings = {
      user.name = "Joosung Park";
      user.email = "iam@h82.dev";
      core.autocrlf = false;
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      push.recurseSubmodules = "check";
      tag.gpgSign = true;
      # Upstream defaults to merged:origin, which also deletes merged branches
      # on the remote.
      trim.delete = "merged-local";
      gpg.program = "${pkgs.gnupg}/bin/gpg";

      "credential.https://gist.github.com" = {
        helper = [
          ""
          "!${pkgs.gh}/bin/gh auth git-credential"
        ];
      };
      "credential.https://github.com" = {
        helper = [
          ""
          "!${pkgs.gh}/bin/gh auth git-credential"
        ];
      };
      "credential.https://gitlab.com" = {
        helper = [
          ""
          "!${pkgs.glab}/bin/glab auth git-credential"
        ];
      };
      "credential.https://git.jpi.app" = {
        helper = [
          ""
          "!${pkgs.glab}/bin/glab auth git-credential"
        ];
      };
    };
  };
}
