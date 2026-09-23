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

  dedupScriptSrc = ../scripts/tailscale-dedup-device;

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
      boot.loader.grub.enable = pkgs.lib.mkForce false;
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

      # --- Structural checks on the *materialized* units, not just the
      # declared config -- a systemd.services.<name>.enable = false sibling
      # would leave the declared After/Wants/WantedBy values unchanged while
      # installing no unit at all (see AGENTS.md's linked solution:
      # nix-check-reads-option-value-not-materialized-output.md). `systemctl
      # cat` fails outright if the unit was never installed, so this is a
      # check on what actually landed on the running system.
      # (U2, U3, U4 test scenarios)

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

      dedup_unit = thinkpad.succeed("systemctl cat tailscale-dedup-device.service")
      assert "Before=tailscaled-autoconnect.service" in dedup_unit, dedup_unit
      assert "WantedBy=multi-user.target" in dedup_unit, dedup_unit
      assert thinkpad.succeed("systemctl is-enabled tailscale-dedup-device.service").strip() == "enabled"
      assert msdesktop.succeed("systemctl is-enabled tailscale-dedup-device.service").strip() == "enabled"

      thinkpad.fail("systemctl cat tailscale-advertise-routes.service")
      route_unit = msdesktop.succeed("systemctl cat tailscale-advertise-routes.service")
      assert "After=tailscaled-autoconnect.service" in route_unit, route_unit
      assert msdesktop.succeed("systemctl is-enabled tailscale-advertise-routes.service").strip() == "enabled"

      # ThinkPad (advertiseRoutes=false) must not even render a routes secret
      # template -- not just an empty one.
      assert not ${if nodes.thinkpad.sops.templates ? "tailscale-routes.env" then "True" else "False"}, \
          "ThinkPad must not have a tailscale-routes.env template"
      assert ${if nodes.msdesktop.sops.templates ? "tailscale-routes.env" then "True" else "False"}, \
          "MS-7D91 must have a tailscale-routes.env template"

      # Route-advertisement never touches the API, so its materialized unit
      # must not reference the API token's env file.
      assert ${builtins.toJSON nodes.msdesktop.sops.templates."tailscale-api.env".path} not in route_unit
      assert ${builtins.toJSON nodes.msdesktop.sops.templates."tailscale-routes.env".path} in route_unit

      # --- Runtime: TAILSCALE_ROUTES rendering (U4 test scenario) ---

      msdesktop_routes_env = msdesktop.succeed("cat ${
        nodes.msdesktop.sops.templates."tailscale-routes.env".path
      }")
      assert "TAILSCALE_ROUTES=192.168.10.0/24,192.168.1.0/24,203.0.113.99/32" in msdesktop_routes_env, msdesktop_routes_env

      # --- Runtime: dedup script against the mock API (U3 test scenario, AE1) ---
      #
      # Invokes the real scripts/tailscale-dedup-device directly -- the same
      # file the systemd unit's ExecStart wraps -- against the real
      # /var/lib/tailscale state-file path and the mock API.

      state_file = "/var/lib/tailscale/tailscaled.state"

      run_dedup = (
          "set -a; . ${nodes.msdesktop.sops.templates."tailscale-api.env".path}; set +a; "
          + "SELF_HOSTNAME=${nodes.msdesktop.networking.hostName} "
          + "bash ${dedupScriptSrc}"
      )

      # Scenario A: no tailscaled state yet (fresh install) and a device
      # already registered under this hostname -- it must be deleted.
      msdesktop.succeed(f"rm -f {state_file}")
      mockapi.succeed(
          "mkdir -p /var/lib/tailscale-mock-api && "
          + "printf '%s' '{\"devices\":["
          + "{\"id\":\"stale-device-id\",\"hostname\":\"test-msdesktop\"},"
          + "{\"id\":\"other-host-id\",\"hostname\":\"other-host\"}"
          + "]}' > /var/lib/tailscale-mock-api/devices.json"
      )
      mockapi.succeed("rm -f /var/lib/tailscale-mock-api/deletes.log && touch /var/lib/tailscale-mock-api/deletes.log")
      msdesktop.succeed(run_dedup)
      deletes = mockapi.succeed("cat /var/lib/tailscale-mock-api/deletes.log").split()
      assert deletes == ["stale-device-id"], deletes

      # Scenario B: tailscaled state already exists (ordinary reboot, or a
      # key-expiry reauth of this same instance) -- must not query the API
      # or delete anything, even though a same-hostname device is listed.
      msdesktop.succeed(f"mkdir -p $(dirname {state_file}) && touch {state_file}")
      mockapi.succeed("rm -f /var/lib/tailscale-mock-api/deletes.log && touch /var/lib/tailscale-mock-api/deletes.log")
      msdesktop.succeed(run_dedup)
      deletes = mockapi.succeed("cat /var/lib/tailscale-mock-api/deletes.log").split()
      assert deletes == [], deletes
      msdesktop.succeed(f"rm -f {state_file}")

      # --- Store-leak check (U6 test scenario) ---

      for machine in [thinkpad, msdesktop]:
          leaked = machine.succeed(
              "nix-store -qR /run/current-system | xargs grep -rlE "
              + "'FAKE_test_auth_key|FAKE_test_api_token' 2>/dev/null || true"
          )
          assert leaked.strip() == "", "fixture secret leaked into the built system closure: " + leaked
    '';
}
