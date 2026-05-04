{
  inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../common
  ];

  # Hostname — must match the nixosConfigurations key in flake.nix and the directory name.
  networking.hostName = "jpi-vmware";

  # Bootloader (BIOS/Legacy) — VMware guest disk layout. Policy module: hosts/common/boot/grub.nix.
  # `device` is host hardware (VMware virtual disk) so it lives here, but useOSProber etc. policy is hard-coded inside the module.
  my.system.boot.grub = {
    enable = true;
    device = "/dev/sda";
  };

  # VMware guest support (this host only)
  virtualisation.vmware.guest.enable = true;
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "vmware" ];

  # nix-vscode-extensions overlay — must be applied to the host's pkgs so allowUnfree propagates.
  # Applying it inside home-manager creates a separate pkgs instance and Copilot/Pylance/etc. silently fail.
  # See home/modules/editors/AGENTS.md and the root AGENTS.md ANTI-PATTERNS section for details.
  nixpkgs.overlays = [ inputs.nix-vscode-extensions.overlays.default ];

  # Enable shared modules (hosts/common/*)
  my.system.users.h82.enable = true;
  my.system.locale.korean.enable = true;
  my.system.keyboard.kr106.enable = true;
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

  # Enable aarch64 (arm64) cross-compilation — binfmt_misc + qemu-user runs aarch64-linux binaries on this host.
  # Both `nix build nixpkgs#pkgsCross.aarch64-multiplatform.<pkg>` artifacts and native aarch64 builds
  # (leveraging cache.nixos.org) work. Policy: hosts/common/cross-compile.nix.
  my.system.cross-compile.aarch64.enable = true;

  # Per-host home-manager overrides.
  # `home-manager.users.h82` is already defined in flake.nix as `import ./home/h82.nix`.
  # Assigning another attrset to the same key triggers automatic merging by the NixOS module
  # system (home-manager's `users` option is `attrsOf (submoduleWith ...)`, so each user entry
  # is a submodule whose multiple definitions merge like imports). The pattern is therefore:
  # keep the home/h82.nix configuration intact and layer host-specific overrides on top.
  home-manager.users.h82 = {
    # Idle lock / display auto-off — both disabled because this is a VMware guest desktop.
    # Idle lock (kscreenlockerrc Autolock) and DPMS (powerdevilrc turnOffDisplay) are pointless
    # and only annoying inside a virtual session, so we explicitly turn them off.
    # NOTE: Lock-on-resume from suspend (LockOnResume) and display dimming are NOT touched —
    #       both keep their default (enabled) values. See home/modules/desktop/plasma.nix for option semantics.
    my.desktop.plasma.autoLock.enable = false;
    my.desktop.plasma.screenOff.enable = false;
  };

  # Laptop input (keyd + libinput palm rejection) — disabled because this is a VMware guest.
  # The host's keyboard/touchpad is abstracted by the hypervisor, so keyd mappings are meaningless,
  # and libinput palm rejection has no physical touchpad to apply to.
  # We pin `false` explicitly to document that this host is intentionally off, rather than relying on the default.
  my.system.laptop-input.enable = false;

  # Firewall — disabled because this is a VMware guest (override the shared module's default of true on this host only).
  # The guest sits behind VMware Workstation's default NAT network, so external inbound traffic never reaches it
  # directly, and the host OS firewall already provides primary isolation. Adding another iptables/nftables layer
  # inside the guest only increases the chance of conflicting with Docker's own NAT rules
  # (my.system.virtualisation.docker), with almost no protective benefit.
  my.system.networking.firewall.enable = false;

  # Korean input (fcitx5) is managed by a home-manager module: home/modules/i18n/fcitx5.nix

  # state version — never change arbitrarily (the NixOS release this host was first installed on)
  system.stateVersion = "25.11";
}
