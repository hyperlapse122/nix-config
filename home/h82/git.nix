{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    signing = {
      key = "A7F1956CD1A035A139BC7ABFCC740A29852C0E95";
      signByDefault = true;
    };
    settings = {
      user.name = "Joosung Park";
      user.email = "iam@h82.dev";
      user.signingkey = "A7F1956CD1A035A139BC7ABFCC740A29852C0E95";
      core.autocrlf = false;
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      push.recurseSubmodules = "check";
      tag.gpgSign = true;
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
