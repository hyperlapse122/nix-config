/*
  Check interface:

    import ./tests/podman-prune.nix { inherit pkgs; }

  Boots a node with the NixOS Podman module and lingering user managers for
  h82 and a second account. As h82 it loads two offline images, leaves one
  dangling, stops a container, and creates a named volume, then starts
  podman-prune.service in h82's user manager. Asserts the stopped container
  and the dangling image are gone while the tagged image and the named volume
  remain, and that the second account's user manager skips the unit.

  Every Podman and systemctl --user command runs through runuser with the
  user manager's XDG_RUNTIME_DIR, never su -, so the seeded storage and the
  service share one run root.
*/
{ pkgs }:
let
  root = pkgs.buildEnv {
    name = "prune-image-root";
    paths = [ pkgs.busybox ];
    pathsToLink = [ "/bin" ];
  };

  # Distinct Cmd values give the images distinct IDs, so untagging one leaves
  # it dangling instead of removing a second tag from a shared image.
  keptImage = pkgs.dockerTools.buildImage {
    name = "prune-kept";
    tag = "latest";
    copyToRoot = root;
    config.Cmd = [ "/bin/true" ];
  };
  danglingImage = pkgs.dockerTools.buildImage {
    name = "prune-dangling";
    tag = "latest";
    copyToRoot = root;
    config.Cmd = [ "/bin/sh" ];
  };
in
pkgs.testers.nixosTest {
  name = "podman-prune";
  nodes.machine =
    { ... }:
    {
      imports = [
        ../modules/nixos/services/podman.nix
        ../modules/shared/host.nix
      ];
      users.users.h82 = {
        isNormalUser = true;
        uid = 1000;
        linger = true;
      };
      users.users.other = {
        isNormalUser = true;
        uid = 1001;
        linger = true;
      };
      my.podman.enable = true;
      virtualisation.memorySize = 1536;
    };
  testScript = ''
    def user(command, name="h82", uid="1000"):
        return "runuser -u " + name + " -- env XDG_RUNTIME_DIR=/run/user/" + uid + " DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/" + uid + "/bus " + command

    def other(command):
        return user(command, name="other", uid="1001")

    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("user@1000.service")
    machine.wait_for_unit("user@1001.service")

    # Stop the timer so a scheduled run cannot prune the seeded storage before
    # the preconditions are checked; the service is started explicitly below.
    assert "podman-prune.timer" in machine.succeed(user("systemctl --user list-timers --all"))
    machine.succeed(user("systemctl --user stop podman-prune.timer"))

    machine.succeed(user("podman load -i ${keptImage}"))
    machine.succeed(user("podman load -i ${danglingImage}"))
    machine.succeed(user("podman untag localhost/prune-dangling:latest"))
    machine.succeed(user("podman run --network none --name stopped localhost/prune-kept:latest"))
    machine.succeed(user("podman volume create keep-vol"))

    assert "stopped" in machine.succeed(user("podman ps -a --format '{{.Names}}'")).split()
    assert len(machine.succeed(user("podman images --filter dangling=true --quiet")).split()) == 1

    # A unit whose condition fails also reports Result=success, so the
    # condition result proves the prune actually ran.
    machine.succeed(user("systemctl --user start podman-prune.service"))
    assert machine.succeed(user("systemctl --user show -P ConditionResult podman-prune.service")).strip() == "yes"
    assert machine.succeed(user("systemctl --user show -P Result podman-prune.service")).strip() == "success"

    assert "stopped" not in machine.succeed(user("podman ps -a --format '{{.Names}}'")).split()
    assert machine.succeed(user("podman images --filter dangling=true --quiet")).split() == []
    assert "localhost/prune-kept:latest" in machine.succeed(user("podman images --format '{{.Repository}}:{{.Tag}}'")).split()
    assert "keep-vol" in machine.succeed(user("podman volume ls --format '{{.Name}}'")).split()

    machine.succeed(other("systemctl --user start podman-prune.service"))
    assert machine.succeed(other("systemctl --user show -P ConditionResult podman-prune.service")).strip() == "no"
  '';
}
