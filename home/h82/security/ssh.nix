{ ... }:
{
  home.file.".ssh/config".text = ''
    Host *
      IdentityAgent ~/.1password/agent.sock
  '';

  home.file.".config/1Password/ssh/agent.toml".source = ../../../config/1password/agent.toml;
}
