/*
  VM check interface:

    import ./tests/boot-layout.nix { inherit pkgs inputs; }

  disko's upstream test helper replaces the production by-id path with a
  disposable QEMU disk. It formats, mounts, unmounts, and boots the resulting
  installation; no host disk is touched.
*/
{ pkgs, inputs }:
let
  lib = pkgs.lib;
  diskoLib = import "${inputs.disko}/lib" {
    inherit lib;
    makeTest = import "${inputs.nixpkgs}/nixos/tests/make-test-python.nix";
    eval-config = import "${inputs.nixpkgs}/nixos/lib/eval-config.nix";
    qemu-common = import "${inputs.nixpkgs}/nixos/lib/qemu-common.nix";
  };
  bootModule = ../modules/nixos/boot.nix;
  productionDisk = import ../hosts/ThinkPad-X1-Carbon-Gen-11/disko.nix;
  testDisk = lib.recursiveUpdate productionDisk {
    disko.devices.disk.main.content.partitions.luks.content.passwordFile = "/tmp/secret.key";
    disko.devices.disk.main.content.partitions.luks.content.content.subvolumes."/swap".swap.swapfile.size =
      "100M";
  };
  testSystem = {
    imports = [
      bootModule
      inputs.lanzaboote.nixosModules.lanzaboote
    ];
    options.my.bootstrap = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    config.my.bootstrap = true;
  };
in
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "boot-layout";
  disko-config = testDisk;
  extraSystemConfig = testSystem;
  enableOCR = true;
  bootCommands = ''
    machine.wait_for_text("[Pp]assphrase for")
    machine.send_chars("secretsecret\n")
  '';
  extraTestScript = ''
    machine.succeed("cryptsetup isLuks /dev/vda2")
    machine.succeed("cryptsetup luksDump /dev/vda2 | grep -q 'Version:.*2'")
    machine.succeed("btrfs subvolume list / | grep -qs 'path root$'")
    machine.succeed("btrfs subvolume list / | grep -qs 'path home$'")
    machine.succeed("btrfs subvolume list / | grep -qs 'path nix$'")
    machine.succeed("btrfs subvolume list / | grep -qs 'path log$'")
    machine.succeed("btrfs subvolume list / | grep -qs 'path swap$'")
    machine.succeed("test -e /swap/swapfile")
  '';
}
