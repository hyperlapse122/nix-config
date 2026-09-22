{ pkgs, inputs }:
let
  fixtures =
    pkgs.runCommand "fake-auth-secrets"
      {
        nativeBuildInputs = [
          pkgs.age
          pkgs.sops
        ];
      }
      ''
        mkdir -p $out
        age-keygen -o $out/key.txt
        recipient=$(age-keygen -y $out/key.txt)
        printf 'github_token: FAKE_ghcr_token\ngitlab_token: FAKE_gitlab_token\njpi_token: FAKE_jpi_token\ndocker_token: FAKE_docker_token\n' > plain.yaml
        sops --encrypt --age "$recipient" --input-type yaml --output-type yaml plain.yaml > $out/tokens.yaml
      '';
  authJsonFile = pkgs.writeText "test-auth.json" (
    builtins.toJSON {
      credHelpers = {
        "ghcr.io" = "sops";
        "registry.gitlab.com" = "sops";
        "registry.jpi.app" = "sops";
        "docker.io" = "sops";
      };
    }
  );
in
pkgs.testers.nixosTest {
  name = "podman-registry-auth";
  nodes.missing =
    { ... }:
    {
      imports = [
        inputs.sops-nix.nixosModules.sops
        ../modules/nixos/secrets.nix
        ../modules/nixos/podman.nix
      ];
      system.switch.enable = true;
      boot.loader.grub.enable = pkgs.lib.mkForce false;
      users.users.h82 = {
        isNormalUser = true;
        uid = 1000;
      };
      my.podman.enable = true;
      my.cliAuth = {
        enable = false;
        sopsFile = null;
      };
      environment.systemPackages = [
        pkgs.podman
      ];
      virtualisation.memorySize = 1536;
    };
  nodes.machine =
    { ... }:
    {
      imports = [
        inputs.sops-nix.nixosModules.sops
        ../modules/nixos/secrets.nix
        ../modules/nixos/podman.nix
      ];
      system.switch.enable = true;
      boot.loader.grub.enable = pkgs.lib.mkForce false;
      users.users.h82 = {
        isNormalUser = true;
        uid = 1000;
      };
      my.podman.enable = true;
      my.cliAuth = {
        enable = true;
        sopsFile = "${fixtures}/tokens.yaml";
      };
      sops.secrets."cli-auth/docker_token" = {
        key = "docker_token";
        owner = "h82";
        mode = "0400";
      };
      system.activationScripts.fixture = ''
        install -d -m 0700 /var/lib/sops-nix
        if [ ! -e /var/lib/sops-nix/fixture-initialized ]; then
          install -m 0600 ${fixtures}/key.txt /var/lib/sops-nix/key.txt
          touch /var/lib/sops-nix/fixture-initialized
        fi
      '';
      environment.systemPackages = [
        pkgs.podman
        pkgs.python3
      ];
      virtualisation.memorySize = 1536;
    };
  testScript = ''
    import json

    missing.start()
    missing.wait_for_unit("multi-user.target")
    machine.start()
    machine.wait_for_unit("multi-user.target")

    registries = {
        "ghcr.io": ("hyperlapse122", "FAKE_ghcr_token"),
        "registry.gitlab.com": ("hyperlapse", "FAKE_gitlab_token"),
        "registry.jpi.app": ("hyperlapse", "FAKE_jpi_token"),
        "docker.io": ("hyperlapse122", "FAKE_docker_token"),
    }

    for reg, (expected_user, expected_token) in registries.items():
        out = machine.succeed(f"printf '{reg}' | su - h82 -c 'docker-credential-sops get'")
        data = json.loads(out)
        assert data["ServerURL"] == reg, f"Expected ServerURL {reg}, got {data.get('ServerURL')}"
        assert data["Username"] == expected_user, f"Expected Username {expected_user}, got {data.get('Username')}"
        assert data["Secret"] == expected_token, f"Expected Secret {expected_token}, got {data.get('Secret')}"

    out = machine.fail("printf 'quay.io' | su - h82 -c 'docker-credential-sops get'")
    assert "credentials not found in native keychain" in out

    for reg in registries:
        out = missing.fail(f"printf '{reg}' | su - h82 -c 'docker-credential-sops get'")
        assert "credentials not found in native keychain" in out

    machine.succeed("install -d -m 0700 /home/h82/.config/containers && cp ${authJsonFile} /home/h82/.config/containers/auth.json && chmod 0600 /home/h82/.config/containers/auth.json && chown -R h82:users /home/h82/.config")
    missing.succeed("install -d -m 0700 /home/h82/.config/containers && cp ${authJsonFile} /home/h82/.config/containers/auth.json && chmod 0600 /home/h82/.config/containers/auth.json && chown -R h82:users /home/h82/.config")

    login_out = machine.succeed("su - h82 -c 'REGISTRY_AUTH_FILE=/home/h82/.config/containers/auth.json podman login --get-login ghcr.io'")
    assert "hyperlapse122" in login_out

    missing.fail("su - h82 -c 'REGISTRY_AUTH_FILE=/home/h82/.config/containers/auth.json podman login --get-login ghcr.io'")

    fake_tokens = ["FAKE_ghcr_token", "FAKE_gitlab_token", "FAKE_jpi_token", "FAKE_docker_token"]
    for token in fake_tokens:
        machine.fail(f"journalctl --no-pager | grep '{token}'")
        missing.fail(f"journalctl --no-pager | grep '{token}'")
  '';
}
