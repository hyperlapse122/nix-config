{
  pkgs,
  routingTable ? {
    "ghcr.io" = {
      username = "hyperlapse122";
      secret = "/run/secrets/cli-auth/github_token";
    };
    "registry.gitlab.com" = {
      username = "hyperlapse";
      secret = "/run/secrets/cli-auth/gitlab_token";
    };
    "registry.jpi.app" = {
      username = "hyperlapse";
      secret = "/run/secrets/cli-auth/jpi_token";
    };
    "docker.io" = {
      username = "hyperlapse122";
      secret = "/run/secrets/cli-auth/docker_token";
    };
  },
}:

let
  credentialMap = pkgs.writeText "docker-credential-map.json" (builtins.toJSON routingTable);
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "docker-credential-sops";
  version = "1";
  dontUnpack = true;
  nativeBuildInputs = [ pkgs.python3 ];
  installPhase = ''
    install -Dm755 ${../scripts/docker-credential-sops} $out/bin/docker-credential-sops
    substituteInPlace $out/bin/docker-credential-sops \
      --replace-fail '@CREDENTIAL_MAP@' '${credentialMap}'
    patchShebangs $out/bin/docker-credential-sops
  '';
  meta.mainProgram = "docker-credential-sops";
}
