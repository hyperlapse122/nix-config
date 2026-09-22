/*
  Check interface:

    import ./tests/podman-containers.nix { inherit pkgs self; }

  Asserts that rootless Podman, disabled rootful socket, helper package,
  environment variables, registries search drop-in, and auth.json activation logic
  materialize correctly on both production and bootstrap ThinkPad configurations.
*/
{ pkgs, self }:
let
  host = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11;
  bootstrapHost = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap;

  checkHost =
    hostName: hostCfg:
    let
      packages = hostCfg.config.environment.systemPackages;
      podmanPkg = pkgs.lib.lists.findFirst (p: (p.pname or "") == "podman") null packages;
      dockerCompatPkg =
        pkgs.lib.lists.findFirst (p: pkgs.lib.strings.hasPrefix "podman-docker-compat" p.name) null packages;
      helperPkg =
        pkgs.lib.lists.findFirst (p: (p.pname or "") == "docker-credential-sops") null packages;

      absentPodman = pkgs.lib.optionalString (podmanPkg == null) ''
        echo "missing podman in environment.systemPackages on ${hostName}" >&2
        exit 1
      '';
      presentPodman = pkgs.lib.optionalString (podmanPkg != null) ''
        if [ ! -x ${podmanPkg}/bin/podman ]; then
          echo "podman package ships no bin/podman executable on ${hostName}" >&2
          exit 1
        fi
      '';

      absentDockerCompat = pkgs.lib.optionalString (dockerCompatPkg == null) ''
        echo "missing podman-docker-compat in environment.systemPackages on ${hostName}" >&2
        exit 1
      '';
      presentDockerCompat = pkgs.lib.optionalString (dockerCompatPkg != null) ''
        if [ ! -x ${dockerCompatPkg}/bin/docker ]; then
          echo "podman-docker-compat package ships no bin/docker compat shim on ${hostName}" >&2
          exit 1
        fi
      '';

      absentHelper = pkgs.lib.optionalString (helperPkg == null) ''
        echo "missing docker-credential-sops in environment.systemPackages on ${hostName}" >&2
        exit 1
      '';
      presentHelper = pkgs.lib.optionalString (helperPkg != null) ''
        if [ ! -x ${helperPkg}/bin/docker-credential-sops ]; then
          echo "docker-credential-sops package ships no bin/docker-credential-sops executable on ${hostName}" >&2
          exit 1
        fi
      '';

      rootfulWantedBy = hostCfg.config.systemd.sockets.podman.wantedBy;

      hm = hostCfg.config.home-manager.users.h82;
      sessionAuth = hm.home.sessionVariables.REGISTRY_AUTH_FILE or "";
      sessionDocker = hm.home.sessionVariables.DOCKER_HOST or "";
      userSessionAuth = hm.systemd.user.sessionVariables.REGISTRY_AUTH_FILE or "";
      userSessionDocker = hm.systemd.user.sessionVariables.DOCKER_HOST or "";

      activationScript = hm.home.activation.containersAuth.data or "";
      registriesConf =
        hm.xdg.configFile."containers/registries.conf.d/10-unqualified-search.conf".text or "";
    in
    ''
      # 1. Verify systemPackages contains podman, podman-docker-compat, and docker-credential-sops
      ${absentPodman}
      ${presentPodman}
      ${absentDockerCompat}
      ${presentDockerCompat}
      ${absentHelper}
      ${presentHelper}

      # 2. Verify rootful podman socket wantedBy is empty
      if [ "${builtins.toJSON rootfulWantedBy}" != "[]" ]; then
        echo "systemd.sockets.podman.wantedBy is not empty on ${hostName}: '${builtins.toJSON rootfulWantedBy}'" >&2
        exit 1
      fi

      # 3. Verify REGISTRY_AUTH_FILE and DOCKER_HOST session variables
      if [ '${sessionAuth}' != "/home/h82/.config/containers/auth.json" ]; then
        echo "home.sessionVariables.REGISTRY_AUTH_FILE is incorrect on ${hostName}: '${sessionAuth}'" >&2
        exit 1
      fi
      if [ '${sessionDocker}' != "unix://\''${XDG_RUNTIME_DIR}/podman/podman.sock" ]; then
        echo "home.sessionVariables.DOCKER_HOST is incorrect on ${hostName}: '${sessionDocker}'" >&2
        exit 1
      fi
      if [ '${userSessionAuth}' != "/home/h82/.config/containers/auth.json" ]; then
        echo "systemd.user.sessionVariables.REGISTRY_AUTH_FILE is incorrect on ${hostName}: '${userSessionAuth}'" >&2
        exit 1
      fi
      if [ '${userSessionDocker}' != "unix://\''${XDG_RUNTIME_DIR}/podman/podman.sock" ]; then
        echo "systemd.user.sessionVariables.DOCKER_HOST is incorrect on ${hostName}: '${userSessionDocker}'" >&2
        exit 1
      fi

      # 4. Verify home.activation.containersAuth has credHelpers mappings and no embedded tokens
      if echo '${activationScript}' | grep -q '"docker.io":"sops"'; then
        :
      else
        echo "home.activation.containersAuth missing docker.io helper mapping on ${hostName}" >&2
        exit 1
      fi

      if echo '${activationScript}' | grep -q '"ghcr.io":"sops"'; then
        :
      else
        echo "home.activation.containersAuth missing ghcr.io helper mapping on ${hostName}" >&2
        exit 1
      fi

      if echo '${activationScript}' | grep -q '"registry.gitlab.com":"sops"'; then
        :
      else
        echo "home.activation.containersAuth missing registry.gitlab.com helper mapping on ${hostName}" >&2
        exit 1
      fi

      if echo '${activationScript}' | grep -q '"registry.jpi.app":"sops"'; then
        :
      else
        echo "home.activation.containersAuth missing registry.jpi.app helper mapping on ${hostName}" >&2
        exit 1
      fi

      if echo '${activationScript}' | grep -q -E '(auths|token|password)'; then
        echo "home.activation.containersAuth contains embedded tokens on ${hostName}" >&2
        exit 1
      fi

      # 5. Verify registries search drop-in sets unqualified-search-registries
      if echo '${registriesConf}' | grep -q 'unqualified-search-registries = \["docker.io"\]'; then
        :
      else
        echo "registries.conf drop-in missing unqualified-search-registries on ${hostName}: '${registriesConf}'" >&2
        exit 1
      fi
    '';
in
pkgs.runCommand "podman-containers-tests"
  {
    nativeBuildInputs = [
      pkgs.gnugrep
    ];
  }
  ''
    set -x

    ${checkHost "ThinkPad-X1-Carbon-Gen-11" host}
    ${checkHost "ThinkPad-X1-Carbon-Gen-11-bootstrap" bootstrapHost}

    touch $out
  ''
