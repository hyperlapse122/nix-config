{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  luksMapperPrefix = "/dev/mapper/luks-";
  luksCrypttabExtraOpts = [
    "tpm2-device=auto"
    "tpm2-measure-pcr=yes"
  ];

  isLuksMapper = device: lib.isString device && lib.hasPrefix luksMapperPrefix device;
  luksNameFromMapper = device: lib.removePrefix "/dev/mapper/" device;
  luksDeviceFromName = name: "/dev/disk/by-uuid/${lib.removePrefix "luks-" name}";

  encryptedMapperDevices =
    (map (fileSystem: fileSystem.device or null) (lib.attrValues config.fileSystems))
    ++ (map (swapDevice: swapDevice.device or null) config.swapDevices);
  encryptedLuksNames = lib.unique (
    map luksNameFromMapper (lib.filter isLuksMapper encryptedMapperDevices)
  );
in
{
  imports = [
    ./hardware-configuration.nix
    ../common
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14
    (inputs.nixos-hardware + "/common/cpu/intel/tiger-lake")
  ];

  # Use latest kernel for Tiger Lake / Iris Xe hardware support.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "mem_sleep_default=s2idle" ];
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.tpm2.enable = true;
  boot.initrd.luks.devices = lib.genAttrs encryptedLuksNames (name: {
    device = luksDeviceFromName name;
    crypttabExtraOpts = luksCrypttabExtraOpts;
  });

  networking.hostName = "h82-t14-gen2"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # nix-vscode-extensions overlay — must be applied to the host's pkgs so allowUnfree propagates.
  # Applying it inside home-manager creates a separate pkgs instance and Copilot/Pylance/etc. silently fail.
  # See home/modules/editors/AGENTS.md and the root AGENTS.md ANTI-PATTERNS section for details.
  nixpkgs.overlays = [ inputs.nix-vscode-extensions.overlays.default ];

  # Enable shared modules (hosts/common/*)
  my.system.users.h82.enable = true;
  my.system.locale.korean.enable = true;
  my.system.networking.networkmanager.enable = true;
  my.system.networking.tailscale.enable = true;
  my.system.audio.pipewire.enable = true;
  my.system.ssh.server.enable = true;
  my.system.desktop.plasma.enable = true;
  my.system.programs.nix-ld.enable = true;
  my.system.programs.nix-index.enable = true;
  my.system.programs._1password = {
    enable = true;
    # Auto-spawn into the system tray at login — lets the browser extension and
    # SSH agent attach to the 1Password daemon immediately.
    autostart = true;
  };
  my.system.virtualisation.docker.enable = true;
  my.system.hardware.logitech.enable = true;
  my.system.boot.systemd-boot.enable = true;
  my.system.boot.sbctl.enable = true;
  my.system.boot.tpm-luks-enroll = {
    enable = true;
    devices = map (name: config.boot.initrd.luks.devices.${name}.device) encryptedLuksNames;
  };

  # Enable aarch64 (arm64) cross-compilation — binfmt_misc + qemu-user runs aarch64-linux binaries on this host.
  # Both `nix build nixpkgs#pkgsCross.aarch64-multiplatform.<pkg>` artifacts and native aarch64 builds
  # (leveraging cache.nixos.org) work. Policy: hosts/common/cross-compile.nix.
  my.system.cross-compile.aarch64.enable = true;

  home-manager.users.h82 = {
    my.desktop.plasma.autoLock.enable = true;
    my.desktop.plasma.screenOff.enable = true;
  };

  my.system.laptop-input.enable = true;
  my.system.networking.firewall.enable = true;

  # Korean input (fcitx5) is managed by a home-manager module: home/modules/i18n/fcitx5.nix

  # ThinkPad T14 Gen 2 Intel hardware notes:
  # - Keep the BIOS suspend mode on Windows/Linux (S0ix); Linux S3 can make the touchpad lag after resume.
  # - Turbo Boost is BIOS-controlled. `/sys/devices/system/cpu/intel_pstate/no_turbo` should read `0`.
  # - Quectel WWAN may need a manual FCC unlock before ModemManager can use it.
  hardware.enableRedistributableFirmware = true;
  services.fwupd.enable = true;
  hardware.bluetooth = {
    enable = true;
    settings = {
      General = {
        ControllerMode = "dual";
        Experimental = true;
        KernelExperimental = true;
      };
    };
  };
  services.pipewire.wireplumber.configPackages = [
    (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/10-bluez-le-audio.conf" ''
      monitor.bluez.properties = {
        bluez5.roles = [ a2dp_sink a2dp_source bap_sink bap_source hfp_hf hfp_ag ]
        bluez5.hfphsp-backend = "native"
      }
    '')
  ];
  services.fprintd.enable = true;
  security.pam.services.login.fprintAuth = false;
  security.pam.services.sddm.fprintAuth = false;
  security.pam.services.kde.fprintAuth = false;
  hardware.firmware = [ pkgs.sof-firmware ];

  # ThinkPad T14 Gen 2 Intel has no exact nixos-hardware module; apply the
  # Tiger Lake GPU/thermal quirks used by nearby Gen 2 Intel ThinkPad modules.
  hardware.intelgpu.driver = lib.mkDefault "xe";
  services.throttled.enable = lib.mkDefault false;

  # state version — never change arbitrarily (the NixOS release this host was first installed on)
  system.stateVersion = "26.05";
}
