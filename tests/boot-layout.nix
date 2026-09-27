/*
  VM check interface:

    import ./tests/boot-layout.nix { inherit pkgs inputs; }

  disko's upstream test helper replaces the production by-id path with a
  disposable QEMU disk. It formats, mounts, unmounts, and boots the resulting
  installation; no host disk is touched.

  The VM runs once, on the first host directory under hosts/. Every host's
  layout differs from it only in the disk device path and sizes, and a second
  VM run would double a slow test. Instead, every host's hosts/<host>/disko.nix
  is checked at evaluation time for the invariants modules/nixos/system/boot.nix
  and the VM script rely on:
  - disk `main` carries a `luks` partition, whose partlabel
    `disk-main-luks` boot.nix unlocks, holding a LUKS2 container named
    `cryptroot`.
  - a vfat ESP is mounted at `/boot`.
  - the btrfs filesystem inside the container has the subvolumes root, home,
    nix, log, and swap at `/`, `/home`, `/nix`, `/var/log`, and `/swap`, and
    the swap subvolume carries a swapfile.
  Every broken invariant on every host is listed in one evaluation error.
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
  bootModule = ../modules/nixos/system/boot.nix;

  hostNames = lib.attrNames (
    lib.filterAttrs (_: kind: kind == "directory") (builtins.readDir ../hosts)
  );
  diskOf =
    hostName:
    let
      path = ../hosts + "/${hostName}/disko.nix";
    in
    if builtins.pathExists path then import path else null;

  expectedSubvolumes = {
    "/root" = "/";
    "/home" = "/home";
    "/nix" = "/nix";
    "/log" = "/var/log";
    "/swap" = "/swap";
  };

  layoutProblems =
    hostName:
    let
      disk = diskOf hostName;
      partitions = lib.attrByPath [ "disko" "devices" "disk" "main" "content" "partitions" ] { } disk;
      esps = lib.filter (
        partition:
        (partition.content.type or null) == "filesystem"
        && (partition.content.format or null) == "vfat"
        && (partition.content.mountpoint or null) == "/boot"
      ) (lib.attrValues partitions);
      luks = partitions.luks.content or { };
      formatArgs = luks.extraFormatArgs or [ ];
      isLuks2 = lib.any (
        i: lib.elemAt formatArgs i == "--type" && lib.elemAt formatArgs (i + 1) == "luks2"
      ) (lib.range 0 (lib.length formatArgs - 2));
      btrfs = luks.content or { };
      subvolumes = btrfs.subvolumes or { };
      label = "hosts/${hostName}/disko.nix";
    in
    if disk == null then
      [ "hosts/${hostName} has no disko.nix" ]
    else
      lib.optional (partitions == { }) "${label}: disk `main` declares no partitions"
      ++ lib.optional (esps == [ ]) "${label}: no vfat ESP is mounted at /boot"
      ++
        lib.optional ((luks.type or null) != "luks")
          "${label}: partition `luks` on disk `main` is not a LUKS container, so boot.nix's disk-main-luks partlabel unlocks nothing"
      ++ lib.optional (
        (luks.name or null) != "cryptroot"
      ) "${label}: the LUKS container is not named cryptroot"
      ++ lib.optional (!isLuks2) "${label}: the LUKS container is not formatted as LUKS2"
      ++ lib.optional ((btrfs.type or null) != "btrfs") "${label}: the LUKS container does not hold btrfs"
      ++ lib.concatLists (
        lib.mapAttrsToList (
          subvolume: mountpoint:
          lib.optional (
            (subvolumes.${subvolume}.mountpoint or null) != mountpoint
          ) "${label}: btrfs subvolume ${subvolume} is not mounted at ${mountpoint}"
        ) expectedSubvolumes
      )
      ++ lib.optional (
        (subvolumes."/swap".swap.swapfile or null) == null
      ) "${label}: the /swap subvolume carries no swapfile";

  problems = lib.concatMap layoutProblems hostNames;

  firstDisk =
    if hostNames == [ ] then
      throw "boot-layout: no host directory under hosts/"
    else if problems != [ ] then
      throw "boot-layout: host disk layouts break the boot invariants:\n  ${lib.concatStringsSep "\n  " problems}"
    else
      diskOf (lib.head hostNames);

  testDisk = lib.recursiveUpdate firstDisk {
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
