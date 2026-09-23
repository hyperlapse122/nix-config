{ pkgs, inputs }:
let
  fixtures =
    pkgs.runCommand "fake-tailscale-secrets"
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
        cat > plain.yaml <<'EOF'
        tailscale:
          auth_key: FAKE_test_auth_key
          api_token: FAKE_test_api_token
          routes:
            lan_10: 192.168.10.0/24
            lan_1: 192.168.1.0/24
            wp_jpi_co_kr: 203.0.113.99/32
        EOF
        sops --encrypt --age "$recipient" --input-type yaml --output-type yaml plain.yaml > $out/tailscale.yaml
      '';

  fakeTailscale = pkgs.writeShellScriptBin "tailscale" ''
    if [ "$1" = "status" ]; then
      echo '{"Self":{"ID":"self-device-id"}}'
      exit 0
    fi
    echo "fake-tailscale: unsupported invocation: $*" >&2
    exit 1
  '';

  mkTestHost =
    hostName: advertiseRoutes:
    { ... }:
    {
      imports = [
        inputs.sops-nix.nixosModules.sops
        ../modules/nixos/system/secrets.nix
        ../modules/nixos/services/tailscale.nix
      ];
      boot.loader.grub.enable = pkgs.lib.mkForce false;
      fileSystems."/" = {
        device = "/dev/null";
        fsType = "ext4";
      };
      networking.hostName = hostName;
      environment.systemPackages = [
        pkgs.jq
        pkgs.curl
      ];
      my.tailscale = {
        enable = true;
        inherit advertiseRoutes;
        sopsFile = "${fixtures}/tailscale.yaml";
        apiBase = "http://mockapi:8927";
      };
      # Deliberately public fake key. Production never embeds a real key in the store.
      system.activationScripts.fixture = ''
        install -d -m 0700 /var/lib/sops-nix
        if [ ! -e /var/lib/sops-nix/fixture-initialized ]; then
          install -m 0600 ${fixtures}/key.txt /var/lib/sops-nix/key.txt
          touch /var/lib/sops-nix/fixture-initialized
        fi
      '';
    };
in
pkgs.testers.nixosTest {
  name = "tailscale-provisioning";

  nodes.mockapi =
    { ... }:
    {
      environment.systemPackages = [ pkgs.python3 ];
      systemd.services.tailscale-mock-api = {
        description = "Mock Tailscale API for tests/tailscale-provisioning.nix";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.python3}/bin/python3 ${./tailscale-mock-api.py} 8927";
          Restart = "always";
        };
      };
      networking.firewall.allowedTCPPorts = [ 8927 ];
    };

  nodes.thinkpad = mkTestHost "test-thinkpad" false;
  nodes.msdesktop = mkTestHost "test-msdesktop" true;

  testScript =
    { nodes, ... }:
    ''
      start_all()
      mockapi.wait_for_unit("tailscale-mock-api.service")
      mockapi.wait_for_open_port(8927)
      thinkpad.wait_for_unit("multi-user.target")
      msdesktop.wait_for_unit("multi-user.target")

      # --- Structural checks, asserted directly from evaluated Nix config
      # (U2, U3, U4 test scenarios) ---

      assert ${builtins.toJSON nodes.thinkpad.services.tailscale.useRoutingFeatures} == "none", \
          "ThinkPad must not enable routing features"
      assert ${builtins.toJSON nodes.msdesktop.services.tailscale.useRoutingFeatures} == "server", \
          "MS-7D91 must enable server routing features"

      thinkpad_up_flags = set(${builtins.toJSON nodes.thinkpad.services.tailscale.extraUpFlags})
      msdesktop_up_flags = set(${builtins.toJSON nodes.msdesktop.services.tailscale.extraUpFlags})
      assert thinkpad_up_flags == {"--ssh", "--accept-routes"}, thinkpad_up_flags
      assert msdesktop_up_flags == {"--ssh", "--accept-routes"}, msdesktop_up_flags

      assert 41641 in ${builtins.toJSON nodes.thinkpad.networking.firewall.allowedUDPPorts}
      assert 41641 in ${builtins.toJSON nodes.msdesktop.networking.firewall.allowedUDPPorts}

      thinkpad_units = set(${builtins.toJSON (builtins.attrNames nodes.thinkpad.systemd.services)})
      msdesktop_units = set(${builtins.toJSON (builtins.attrNames nodes.msdesktop.systemd.services)})
      assert "tailscale-dedup-device" in thinkpad_units
      assert "tailscale-dedup-device" in msdesktop_units
      assert "tailscale-advertise-routes" not in thinkpad_units, \
          "ThinkPad (advertiseRoutes=false) must not have a route-advertisement unit"
      assert "tailscale-advertise-routes" in msdesktop_units

      dedup_after = set(${builtins.toJSON nodes.msdesktop.systemd.services.tailscale-dedup-device.after})
      dedup_wants = set(${builtins.toJSON nodes.msdesktop.systemd.services.tailscale-dedup-device.wants})
      dedup_wanted_by = set(${builtins.toJSON nodes.msdesktop.systemd.services.tailscale-dedup-device.wantedBy})
      assert "tailscaled-autoconnect.service" in dedup_after
      assert "tailscaled-autoconnect.service" in dedup_wants
      assert "multi-user.target" in dedup_wanted_by, \
          "dedup unit needs wantedBy/wants pull-in, not just after-ordering"

      route_after = set(${builtins.toJSON nodes.msdesktop.systemd.services.tailscale-advertise-routes.after})
      route_wanted_by = set(${builtins.toJSON nodes.msdesktop.systemd.services.tailscale-advertise-routes.wantedBy})
      assert "tailscaled-autoconnect.service" in route_after
      assert "multi-user.target" in route_wanted_by

      dedup_env_file = ${builtins.toJSON nodes.msdesktop.systemd.services.tailscale-dedup-device.serviceConfig.EnvironmentFile}
      assert dedup_env_file == ${builtins.toJSON nodes.msdesktop.sops.templates."tailscale.env".path}

      # --- Runtime: TAILSCALE_ROUTES rendering (U4 test scenario) ---

      msdesktop_env = msdesktop.succeed("cat ${nodes.msdesktop.sops.templates."tailscale.env".path}")
      assert "TAILSCALE_ROUTES=192.168.10.0/24,192.168.1.0/24,203.0.113.99/32" in msdesktop_env, msdesktop_env

      thinkpad_env = thinkpad.succeed("cat ${nodes.thinkpad.sops.templates."tailscale.env".path}")
      assert "TAILSCALE_ROUTES" not in thinkpad_env, thinkpad_env

      # --- Runtime: dedup script against the mock API (U3 test scenario, AE1) ---

      run_dedup = (
          "set -a; . ${nodes.msdesktop.sops.templates."tailscale.env".path}; set +a; "
          + "PATH=${fakeTailscale}/bin:$PATH "
          + "${nodes.msdesktop.my.tailscale.dedupScriptPath}"
      )

      # Scenario A: a stale device shares this hostname under a different ID.
      mockapi.succeed(
          "mkdir -p /var/lib/tailscale-mock-api && "
          + "printf '%s' '{\"devices\":["
          + "{\"id\":\"self-device-id\",\"hostname\":\"test-msdesktop\"},"
          + "{\"id\":\"stale-device-id\",\"hostname\":\"test-msdesktop\"},"
          + "{\"id\":\"other-host-id\",\"hostname\":\"other-host\"}"
          + "]}' > /var/lib/tailscale-mock-api/devices.json"
      )
      mockapi.succeed("rm -f /var/lib/tailscale-mock-api/deletes.log && touch /var/lib/tailscale-mock-api/deletes.log")
      msdesktop.succeed(run_dedup)
      deletes = mockapi.succeed("cat /var/lib/tailscale-mock-api/deletes.log").split()
      assert deletes == ["stale-device-id"], deletes

      # Scenario B: no other device shares this hostname (ordinary rebuild /
      # key-expiry reauth) -- nothing should be deleted.
      mockapi.succeed(
          "printf '%s' '{\"devices\":[{\"id\":\"self-device-id\",\"hostname\":\"test-msdesktop\"}]}' "
          + "> /var/lib/tailscale-mock-api/devices.json"
      )
      mockapi.succeed("rm -f /var/lib/tailscale-mock-api/deletes.log && touch /var/lib/tailscale-mock-api/deletes.log")
      msdesktop.succeed(run_dedup)
      deletes = mockapi.succeed("cat /var/lib/tailscale-mock-api/deletes.log").split()
      assert deletes == [], deletes

      # --- Store-leak check (U6 test scenario) ---

      for machine in [thinkpad, msdesktop]:
          leaked = machine.succeed(
              "nix-store -qR /run/current-system | xargs grep -rlE "
              + "'FAKE_test_auth_key|FAKE_test_api_token' 2>/dev/null || true"
          )
          assert leaked.strip() == "", "fixture secret leaked into the built system closure: " + leaked
    '';
}
