{ pkgs, inputs }:
let
  changed = pkgs.writeText "omp-changed-config.json" (
    builtins.toJSON {
      memory.backend = "off";
      autolearn.enabled = false;
      disabledProviders = [ "omp-managed" ];
      startup = {
        checkUpdate = false;
        quiet = true;
      };
      marketplace.autoUpdate = "off";
    }
  );
in
pkgs.testers.nixosTest {
  name = "omp-activation";
  nodes.machine = { lib, ... }: {
    imports = [
      inputs.home-manager.nixosModules.home-manager
      ../modules/shared/host.nix
      ../modules/nixos/system/omp.nix
    ];
    my.user = {
      name = "tester";
      home = "/home/tester";
    };
    users.users.tester.isNormalUser = true;
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users.tester = {
        imports = [
          ../modules/shared/host.nix
          ../home/h82/agents/omp.nix
        ];
        home.stateVersion = "26.05";
      };
    };
    system.switch.enable = true;
    boot.loader.grub.enable = lib.mkForce false;
    specialisation.changed.configuration.home-manager.users.tester.my.omp.documents."config.yml" =
      lib.mkForce changed;
    environment.systemPackages = [ pkgs.python3 ];
    virtualisation.memorySize = 2048;
  };
  testScript = ''
    import json
    import shlex

    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("home-manager-tester.service")
    config = "/home/tester/.omp/agent/config.yml"
    state = "/home/tester/.omp/agent/agent.db"
    switch = "/run/current-system/bin/switch-to-configuration switch"

    def seed(path, content):
        machine.succeed("runuser -u tester -- python3 -c " + shlex.quote(
            "from pathlib import Path; Path(" + repr(path) + ").write_text(" + repr(content) + ")"))

    def verify(quiet=False):
        value = json.loads(machine.succeed("cat " + config))
        expected = {"memory": {"backend": "off"}, "startup": {"checkUpdate": False},
                    "marketplace": {"autoUpdate": "off"}, "autolearn": {"enabled": False},
                    "disabledProviders": ["omp-managed"]}
        if quiet:
            expected["startup"]["quiet"] = True
        else:
            expected["modelRoles"] = {"default": "synthetic/hf:zai-org/GLM-5.3", "web": "web/synthetic"}
            expected["defaultThinkingLevel"] = "max"
            expected["skills"] = {"customDirectories": []}
            expected["contextFiles"] = {"extra": ["OMP.md"]}
            expected["task"] = {"structured": True}
        assert value == expected, value
        assert machine.succeed("stat -c '%a:%U' " + config).strip() == "600:tester"
        assert machine.succeed("cat " + state) == "FAKE_STATE"

    seed(state, "FAKE_STATE")
    seed(config, '{"memory":{"backend":"local"},"newGlobalKey":true}')
    before = machine.succeed("systemctl show -P ExecMainStartTimestampMonotonic home-manager-tester")
    machine.succeed(switch)
    verify()
    after = machine.succeed("systemctl show -P ExecMainStartTimestampMonotonic home-manager-tester")
    assert before == after, "unchanged Home Manager generation unexpectedly restarted"

    changed_switch = "/run/current-system/specialisation/changed/bin/switch-to-configuration switch"
    seed(config, '{"memory":{"backend":"local"},"newGlobalKey":true}')
    machine.succeed(changed_switch)
    verify(quiet=True)
    seed(config, '{"memory":{"backend":"local"},"anotherNewKey":false}')
    machine.succeed(switch)
    verify(quiet=True)

    seed(config, "invalid: [FAKE_SECRET")
    machine.fail(switch)
    assert machine.succeed("cat " + config) == "invalid: [FAKE_SECRET"
    assert machine.succeed("cat " + state) == "FAKE_STATE"
  '';
}
